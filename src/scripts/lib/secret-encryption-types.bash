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
# The aggregate preflight is the only step that asks the image. It writes the
# supported types to SECRET_ENCRYPTION_TYPES_FILE, then the one type the
# secrets dir uses to SECRET_ENCRYPTION_TYPE_FILE (empty: no values). Later
# steps read those files and fail up front if they are missing.
#
# Functions:
#   secret_encryption_types_write - asks the image, writes SECRET_ENCRYPTION_TYPES_FILE
#   secret_value_token_name       - <rel-path> -> token name; 1 if no type suffix
#   secret_value_file_for_token   - <secrets-dir> <token> -> value file; 1 if none
#
# Requires OUTPUT_SUB_PATH set before sourcing. The writer also needs log.bash,
# defaults/environments.bash, lib/env-deploy-base-image-compose.bash and
# IMAGE_BUILD_COMMAND.

SECRET_ENCRYPTION_PROVIDERS_IMAGE_PATH="/kd/bin/plugins/decryption-providers"
SECRET_ENCRYPTION_TYPES_FILE="${OUTPUT_SUB_PATH:?OUTPUT_SUB_PATH is required}/run-aggregate/secret-encryption-types"
# shellcheck disable=SC2034 # Written by the aggregate step, read by the package step.
SECRET_ENCRYPTION_TYPE_FILE="${OUTPUT_SUB_PATH}/run-aggregate/secret-encryption-type"

secret_encryption_types_write() {
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
  local types
  types=$(
    printf '%s\n' "${listing}" \
      | sed -n 's/^decrypt-//p' \
      | awk '{ print length($0) "\t" $0 }' \
      | LC_ALL=C sort -k1,1nr -k2,2 \
      | cut -f2
  )
  if [[ -z "${types}" ]]; then
    log_error "${image} has no decrypt-<type> providers in ${SECRET_ENCRYPTION_PROVIDERS_IMAGE_PATH}"
    return 1
  fi
  mkdir -p "$(dirname "${SECRET_ENCRYPTION_TYPES_FILE}")"
  printf '%s\n' "${types}" > "${SECRET_ENCRYPTION_TYPES_FILE}"
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
  done < "${SECRET_ENCRYPTION_TYPES_FILE}"
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
  done < <(LC_ALL=C sort "${SECRET_ENCRYPTION_TYPES_FILE}")
  return 1
}
