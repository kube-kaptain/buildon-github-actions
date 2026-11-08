#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# docker-digest-verify - Verify an image tag still resolves to a pinned digest
#
# Provides:
#   split_reference_digest <ref>                             - Print ref without digest, then digest
#   reference_has_tag <ref>                                  - True if ref carries a tag
#   is_valid_digest <digest>                                 - True for sha256:<64 hex>
#   verify_digest_matches_tag <tagged-ref> <digest> <platform> - Fail unless the pin matches the tag
#   build_host_platform                                      - Print linux/<arch> of this host, empty if unknown
#   verify_dockerfile_from_digests <dockerfile> <platform>   - Verify every FROM tag@digest line
#
# Docker and podman (4.9 and 5.x checked) both pull a tag@digest reference by
# the digest and silently ignore the tag, so neither says when the tag has moved
# away from the pin. This pulls by tag and checks that the pinned digest
# identifies the same image for the platform pulled: either the tag's index
# digest, or that platform's own manifest digest.
#
# How the check is made depends on what each image store records:
#   podman            - RepoDigests of the tag holds the index and platform digests
#   docker containerd - .Id is the index digest, --platform .Id the platform digest
#   docker classic    - pull the pin and compare .Id (config digest), then untag
#                       the pin, as the store keeps only one image per repo digest
#
# Requires: IMAGE_BUILD_COMMAND, log.bash sourced
#
# shellcheck disable=SC2154 # IMAGE_BUILD_COMMAND set by callers before sourcing

# Split "name:tag@sha256:hex" style references. Prints the part before @ and
# the digest on separate lines; the digest line is empty when there is none.
split_reference_digest() {
  local reference="${1}"
  if [[ "${reference}" == *@* ]]; then
    printf '%s\n%s\n' "${reference%%@*}" "${reference#*@}"
  else
    printf '%s\n\n' "${reference}"
  fi
}

# True when the reference (without digest) carries a tag: a colon after the
# last slash, so a registry port is not mistaken for one.
reference_has_tag() {
  local name="${1##*/}"
  [[ "${name}" == *:* ]]
}

is_valid_digest() {
  [[ "${1}" =~ ^sha256:[0-9a-f]{64}$ ]]
}

# Which image store the runtime uses: podman, containerd or classic
image_store_kind() {
  if [[ "${IMAGE_BUILD_COMMAND}" == "podman" ]]; then
    echo "podman"
  elif ${IMAGE_BUILD_COMMAND} info --format '{{.DriverStatus}}' 2>/dev/null | grep -q 'io.containerd.snapshotter'; then
    echo "containerd"
  else
    echo "classic"
  fi
}

# verify_digest_matches_tag <tagged-ref> <digest> <platform>
# Returns 0 when the pin matches what the tag resolves to for the platform,
# 1 (with an error logged) when it does not or the check cannot be made.
verify_digest_matches_tag() {
  local tagged_ref="${1}"
  local digest="${2}"
  local platform="${3}"
  local repo="${tagged_ref%:*}"
  local store matched="false"

  log "Verifying ${tagged_ref} is ${digest} for ${platform}"
  if ! ${IMAGE_BUILD_COMMAND} pull --platform "${platform}" "${tagged_ref}"; then
    log_error "Failed to pull ${tagged_ref} (platform: ${platform}) to verify digest ${digest}"
    return 1
  fi

  store=$(image_store_kind)
  case "${store}" in
    podman)
      if ${IMAGE_BUILD_COMMAND} image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "${tagged_ref}" \
          | grep -q "@${digest}$"; then
        matched="true"
      fi
      ;;
    containerd)
      local index_id platform_id
      index_id=$(${IMAGE_BUILD_COMMAND} image inspect --format '{{.Id}}' "${tagged_ref}")
      platform_id=$(${IMAGE_BUILD_COMMAND} image inspect --platform "${platform}" --format '{{.Id}}' "${tagged_ref}")
      if [[ "${digest}" == "${index_id}" || "${digest}" == "${platform_id}" ]]; then
        matched="true"
      fi
      ;;
    classic)
      local tag_id pin_id
      tag_id=$(${IMAGE_BUILD_COMMAND} image inspect --format '{{.Id}}' "${tagged_ref}")
      if ${IMAGE_BUILD_COMMAND} pull --platform "${platform}" "${repo}@${digest}"; then
        pin_id=$(${IMAGE_BUILD_COMMAND} image inspect --format '{{.Id}}' "${repo}@${digest}")
        ${IMAGE_BUILD_COMMAND} rmi "${repo}@${digest}" > /dev/null || true
        # Both must be known: two failed inspects would otherwise compare equal
        if [[ -n "${tag_id}" && "${pin_id}" == "${tag_id}" ]]; then
          matched="true"
        fi
      fi
      ;;
  esac

  if [[ "${matched}" != "true" ]]; then
    log_error "Digest mismatch for ${platform}: ${tagged_ref} does not resolve to ${digest} (${store} image store)"
    log_error "The tag has moved or the digest is wrong - update the pin, or the tag, so they agree"
    return 1
  fi
  log "Digest verified for ${platform}: ${tagged_ref} is ${digest}"
}

# The platform a FROM --platform=$BUILDPLATFORM stage pulls for
build_host_platform() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "linux/amd64" ;;
    aarch64|arm64) echo "linux/arm64" ;;
    *)             echo "" ;;
  esac
}

# verify_dockerfile_from_digests <dockerfile> <platform>
# Verifies every FROM line that names both a tag and a digest, against the
# platform that FROM pulls for: its own --platform flag when it has one
# ($BUILDPLATFORM is this host, $TARGETPLATFORM the platform being built),
# otherwise the platform being built. Lines whose image or platform is built
# from other variables cannot be checked and get a warning. Returns 1 if any
# check fails, after checking them all.
verify_dockerfile_from_digests() {
  local dockerfile="${1}"
  local platform="${2}"
  local line parsed from_platform check_platform image ref digest failed=0

  # Backslash continuations are joined first so a FROM split across lines is
  # still seen
  while IFS= read -r line || [[ -n "${line}" ]]; do
    # FROM [--flag=value ...] image [AS name], keyword case-insensitive.
    # Prints the --platform value ("-" when absent) and the image.
    parsed=$(echo "${line}" | awk 'toupper($1) == "FROM" {
      p = "-"
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^--platform=/) { p = substr($i, 12); continue }
        if ($i ~ /^--/) continue
        print p, $i
        exit
      }
    }')
    [[ -z "${parsed}" ]] && continue
    from_platform="${parsed%% *}"
    image="${parsed#* }"
    if [[ "${image}" == *'$'* ]]; then
      log_warning "FROM is not a direct image reference, digest not verified: ${line}"
      continue
    fi
    [[ "${image}" == *@* ]] || continue

    { read -r ref; read -r digest; } < <(split_reference_digest "${image}")
    reference_has_tag "${ref}" || continue
    if ! is_valid_digest "${digest}"; then
      log_error "Invalid digest '${digest}' in FROM line: ${line}"
      failed=1
      continue
    fi

    # shellcheck disable=SC2016 # Literal: the Dockerfile's own variable names
    case "${from_platform}" in
      -|'$TARGETPLATFORM'|'${TARGETPLATFORM}') check_platform="${platform}" ;;
      '$BUILDPLATFORM'|'${BUILDPLATFORM}')     check_platform=$(build_host_platform) ;;
      *'$'*)                                   check_platform="" ;;
      *)                                       check_platform="${from_platform}" ;;
    esac
    if [[ -z "${check_platform}" ]]; then
      log_warning "FROM platform cannot be resolved, digest not verified: ${line}"
      continue
    fi
    verify_digest_matches_tag "${ref}" "${digest}" "${check_platform}" || failed=1
  done < <(awk '{ if (sub(/\\$/, "")) { joined = joined $0 " "; next } print joined $0; joined = "" }
    END { if (joined != "") print joined }' "${dockerfile}")

  return "${failed}"
}
