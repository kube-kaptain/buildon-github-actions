#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# secret-encryption-types.bash: encryption types an encrypted secret value
# file may carry, and the token name the file stands for.
#
# Files are <SECRETS_SUB_PATH>/<Token>.<type>. Token may be nested
# (Vendor/DbPassword) and type may contain dots (sha256.aes256.10k), so the
# type is the supported type the name ends in, not the text after the first dot.
#
# Supported types are those the configured env deploy base image can decrypt
# (its decrypt-<type> providers). That image is the FROM of the env image, so
# pulling it here costs the build nothing extra.
#
# Functions:
#   secret_encryption_types_load  - sets SECRET_ENCRYPTION_TYPES once per process
#   secret_value_token_name       - <rel-path> -> token name; 1 if no type suffix
#   secret_value_file_for_token   - <secrets-dir> <token> -> value file; 1 if none
#
# Requires: log.bash, defaults/environments.bash,
# lib/env-deploy-base-image-compose.bash and IMAGE_BUILD_COMMAND.

SECRET_ENCRYPTION_PROVIDERS_IMAGE_PATH="/kd/bin/plugins/decryption-providers"
SECRET_ENCRYPTION_TYPES=""

secret_encryption_types_load() {
  [[ -n "${SECRET_ENCRYPTION_TYPES}" ]] && return 0

  local image
  image=$(env_deploy_base_image_configured) || return 1
  log "Listing the secret encryption types ${image} can decrypt..."
  local listing
  if ! listing=$("${IMAGE_BUILD_COMMAND:?IMAGE_BUILD_COMMAND is required}" run --rm \
      --entrypoint ls "${image}" "${SECRET_ENCRYPTION_PROVIDERS_IMAGE_PATH}"); then
    log_error "Could not list ${SECRET_ENCRYPTION_PROVIDERS_IMAGE_PATH} in ${image}"
    log_error "The env deploy base image supplies the supported secret encryption types."
    return 1
  fi

  # Longest first, so a type that is a suffix of another cannot match first
  SECRET_ENCRYPTION_TYPES=$(
    printf '%s\n' "${listing}" \
      | sed -n 's/^decrypt-//p' \
      | awk '{ print length($0) "\t" $0 }' \
      | LC_ALL=C sort -k1,1nr -k2,2 \
      | cut -f2
  )
  if [[ -z "${SECRET_ENCRYPTION_TYPES}" ]]; then
    log_error "${image} has no decrypt-<type> providers in ${SECRET_ENCRYPTION_PROVIDERS_IMAGE_PATH}"
    return 1
  fi
}

# Usage: secret_value_token_name <path-relative-to-secrets-dir>
# Example: Vendor/DbPassword.sha256.aes256.10k -> Vendor/DbPassword
secret_value_token_name() {
  local rel="${1}"
  local type
  while IFS= read -r type; do
    [[ -z "${type}" ]] && continue
    if [[ "${rel}" == ?*".${type}" ]]; then
      printf '%s\n' "${rel%".${type}"}"
      return 0
    fi
  done <<< "${SECRET_ENCRYPTION_TYPES}"
  return 1
}

# Usage: secret_value_file_for_token <secrets-dir> <token>
# LC_ALL=C order keeps the result deterministic if a token has several types
# (the aggregate preflight rejects that).
secret_value_file_for_token() {
  local secrets_dir="${1}"
  local token="${2}"
  local type
  while IFS= read -r type; do
    [[ -z "${type}" ]] && continue
    if [[ -f "${secrets_dir}/${token}.${type}" ]]; then
      printf '%s\n' "${secrets_dir}/${token}.${type}"
      return 0
    fi
  done < <(printf '%s\n' "${SECRET_ENCRYPTION_TYPES}" | LC_ALL=C sort)
  return 1
}
