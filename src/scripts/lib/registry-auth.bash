#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# registry-auth.bash - Authenticate pull requests to an OCI registry's API.
#
# Shared by everything that talks to a registry over HTTP: the docker artifact
# provider (tags/list) and util/registry-tag-digest (manifest digests).
#
# Requires: log.bash sourced, curl, jq, base64.

# Usage: registry_api_host <registry>
# Prints the host serving <registry>'s API: its own name, except Docker Hub,
# whose API is not served from docker.io.
registry_api_host() {
  if [[ "${1}" == "docker.io" ]]; then
    echo "registry-1.docker.io"
  else
    echo "${1}"
  fi
}

# Usage: registry_auth_header <registry> <image-path>
# Sets REGISTRY_AUTH_HEADER to a complete "Authorization: ..." header (empty
# for none) and REGISTRY_AUTH_METHOD to stored-credentials, credential-helper,
# bearer-with-creds, bearer-anonymous or no-auth (empty when undetermined).
registry_auth_header() {
  local registry="${1}" image_path="${2}"
  local basic_user_pass="" auth_method="" auth_header=""
  local config_file stored_auth decoded cred_helper helper_bin cred_json
  local cred_user cred_secret www_auth realm service scope token_url
  local token_response new_auth_method token encoded

  # docker login stores Docker Hub credentials under the legacy index URL
  # (podman uses the name)
  local api_host cred_key="${registry}"
  api_host=$(registry_api_host "${registry}")
  [[ "${registry}" == "docker.io" ]] && cred_key="https://index.docker.io/v1/"

  # Collect raw user:pass from docker/podman config files. We don't build
  # an Authorization header yet - the WWW-Authenticate probe below decides
  # the actual scheme. Modern OCI registries reject Basic against tags/list
  # and require a Bearer token from the realm endpoint, even when we have
  # working credentials.
  basic_user_pass=""
  auth_method=""
  for config_file in \
    "${DOCKER_CONFIG:-${HOME}/.docker}/config.json" \
    "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/auth.json"; do
    if [[ ! -f "${config_file}" ]]; then
      log "Config file not found, skipping: ${config_file}"
      continue
    fi
    log "Checking docker config: ${config_file}"

    # Direct base64-encoded credentials in .auths.<reg>.auth
    stored_auth=$(jq -r ".auths[\"${registry}\"].auth // .auths[\"${cred_key}\"].auth // empty" "${config_file}" 2>/dev/null || true)
    if [[ -n "${stored_auth}" ]]; then
      log "Found stored credentials for ${registry}"
      decoded=$(printf '%s' "${stored_auth}" | base64 -d 2>/dev/null || true)
      if [[ -n "${decoded}" && "${decoded}" == *:* ]]; then
        basic_user_pass="${decoded}"
        auth_method="stored-credentials"
        break
      fi
      log_warning "Stored credentials for ${registry} did not decode as user:pass"
    else
      log "No stored credentials for ${registry}"
    fi

    # Per-registry credential helper (credHelpers), then default credsStore
    cred_helper=$(jq -r ".credHelpers[\"${registry}\"] // .credHelpers[\"${cred_key}\"] // empty" "${config_file}" 2>/dev/null || true)
    if [[ -n "${cred_helper}" ]]; then
      log "Found credential helper for ${registry}: ${cred_helper}"
    else
      log "No credential helper for ${registry}"
      cred_helper=$(jq -r '.credsStore // empty' "${config_file}" 2>/dev/null || true)
      if [[ -n "${cred_helper}" ]]; then
        log "Found default credential store: ${cred_helper}"
      else
        log "No default credential store configured"
      fi
    fi
    if [[ -n "${cred_helper}" ]]; then
      helper_bin="docker-credential-${cred_helper}"
      if command -v "${helper_bin}" &>/dev/null; then
        log "Requesting credentials from ${helper_bin}..."
        cred_json=$(echo "${cred_key}" | "${helper_bin}" get 2>/dev/null || true)
        if [[ -n "${cred_json}" ]]; then
          cred_user=$(echo "${cred_json}" | jq -r '.Username // empty' 2>/dev/null || true)
          cred_secret=$(echo "${cred_json}" | jq -r '.Secret // empty' 2>/dev/null || true)
          if [[ -n "${cred_user}" && -n "${cred_secret}" ]]; then
            log "Credentials obtained for ${registry}"
            basic_user_pass="${cred_user}:${cred_secret}"
            auth_method="credential-helper"
            break
          fi
        fi
        log "Credential helper returned no credentials"
      else
        log_warning "${helper_bin} not found on PATH"
      fi
    fi
  done

  # Probe /v2/ for WWW-Authenticate. Drives auth choice for tags/list
  # regardless of whether creds were found - Bearer-required registries
  # don't accept Basic against tags/list, so creds need to be exchanged
  # at the realm endpoint first.
  auth_header=""
  log "Probing ${registry}/v2/ for authentication challenge..."
  www_auth=$(curl -sS -o /dev/null -D - "https://${api_host}/v2/" 2>/dev/null \
    | grep -i '^www-authenticate' || true)

  if [[ -z "${www_auth}" ]]; then
    log "Registry ${registry} returned no auth challenge - using no auth"
    [[ -z "${auth_method}" ]] && auth_method="no-auth"
  elif [[ "${www_auth}" == *[Bb]earer* ]]; then
    realm=$(echo "${www_auth}" | sed -n 's/.*realm="\([^"]*\)".*/\1/p')
    service=$(echo "${www_auth}" | sed -n 's/.*service="\([^"]*\)".*/\1/p')
    # Always this image's own pull scope: the /v2/ challenge is not about
    # any repository, and ghcr.io puts a placeholder scope in it
    # (repository:user/image:pull) that its token endpoint then refuses.
    scope="repository:${image_path}:pull"

    if [[ -z "${realm}" ]]; then
      log_warning "Bearer challenge from ${registry} had no realm; cannot exchange for token"
    else
      token_url="${realm}?scope=${scope}"
      [[ -n "${service}" ]] && token_url="${token_url}&service=${service}"

      if [[ -n "${basic_user_pass}" ]]; then
        log "Exchanging stored credentials for Bearer token at ${realm}..."
        token_response=$(curl -sS -u "${basic_user_pass}" "${token_url}" 2>/dev/null || true)
        new_auth_method="bearer-with-creds"
      else
        log "Requesting anonymous Bearer token from ${realm}..."
        token_response=$(curl -sS "${token_url}" 2>/dev/null || true)
        new_auth_method="bearer-anonymous"
      fi
      # Registries return either "token" or "access_token" per the spec
      token=$(echo "${token_response}" | jq -r '.token // .access_token // empty' 2>/dev/null || true)
      if [[ -n "${token}" ]]; then
        log "Bearer token obtained (${new_auth_method})"
        auth_header="Authorization: Bearer ${token}"
        auth_method="${new_auth_method}"
      else
        log_warning "Token endpoint at ${realm} returned no token"
      fi
    fi
  elif [[ "${www_auth}" == *[Bb]asic* ]]; then
    if [[ -n "${basic_user_pass}" ]]; then
      log "Using Basic auth for ${registry}"
      encoded=$(printf '%s' "${basic_user_pass}" | base64 | tr -d '\n')
      auth_header="Authorization: Basic ${encoded}"
    else
      log_warning "Registry ${registry} requires Basic auth but no credentials configured"
    fi
  else
    log_warning "Unrecognised auth challenge from ${registry}: ${www_auth}"
  fi

  # shellcheck disable=SC2034  # Read by callers
  REGISTRY_AUTH_HEADER="${auth_header}"
  # shellcheck disable=SC2034  # Read by callers
  REGISTRY_AUTH_METHOD="${auth_method}"
}
