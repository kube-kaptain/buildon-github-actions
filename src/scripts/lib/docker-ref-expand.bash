# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# docker-ref-expand.bash - Parse and expand OCI image references
#
# Handles three reference forms:
#   short:     name:version                              (requires DOCKER_TARGET_REGISTRY/NAMESPACE)
#   prefixed:  prefix/name:version                       (requires DOCKER_TARGET_REGISTRY/NAMESPACE)
#   full:      domain/[namespace/]prefix/name:version    (used as-is after validation)
#
# Callers source this file and invoke `docker_ref_expand <reference>`. On
# success, results are written to these globals (plain vars, not an array, for
# bash 3.2 portability):
#
#   DOCKER_REF_NAME_PART    - the name portion (everything before the final :)
#   DOCKER_REF_VERSION_PART - the version portion (after the final :)
#   DOCKER_REF_FULL_NAME    - fully qualified image name (no tag)
#   DOCKER_REF_FORM         - detected form: short, prefixed, full
#
# Exit/return: 0 on success, non-zero with log_error on failure. The function
# uses `return` (not exit) so callers can decide how to handle errors.
#
# Requires: log.bash sourced by the caller.

# Extract prefix from the artifact name (first segment before first hyphen)
# e.g. quality-strict -> quality, java-web-service -> java
docker_ref_extract_prefix() {
  local name="${1}"
  local base_name="${name##*/}"
  echo "${base_name%%-*}"
}

# Validate that the prefix path segment matches the name's derived prefix
docker_ref_validate_prefix() {
  local prefix_segment="${1}"
  local name="${2}"
  local expected_prefix
  expected_prefix=$(docker_ref_extract_prefix "${name}")
  if [[ "${prefix_segment}" != "${expected_prefix}" ]]; then
    log_error "Prefix mismatch: path segment '${prefix_segment}' does not match name prefix '${expected_prefix}' derived from '${name}'"
    return 1
  fi
}

# Parse a reference and populate DOCKER_REF_* globals.
docker_ref_expand() {
  local reference="${1}"

  DOCKER_REF_NAME_PART=""
  DOCKER_REF_VERSION_PART=""
  DOCKER_REF_FULL_NAME=""
  DOCKER_REF_FORM=""

  if [[ "${reference}" != *":"* ]]; then
    log_error "Invalid reference: missing version (no colon found): ${reference}"
    return 1
  fi
  local version_part="${reference##*:}"
  local name_part="${reference%:*}"

  if [[ -z "${version_part}" ]]; then
    log_error "Invalid reference: empty version: ${reference}"
    return 1
  fi
  if [[ -z "${name_part}" ]]; then
    log_error "Invalid reference: empty name: ${reference}"
    return 1
  fi

  # Detect reference form:
  #   Full:     dot in the first segment (domain present)
  #   Prefixed: contains / but no dot in first segment
  #   Short:    no /
  local first_segment="${name_part%%/*}"
  local form
  if [[ "${first_segment}" == *"."* ]]; then
    form="full"
  elif [[ "${name_part}" == *"/"* ]]; then
    form="prefixed"
  else
    form="short"
  fi

  local full_name prefix prefix_segment artifact_name parent_path
  case "${form}" in
    short)
      # name:version -> registry/namespace/prefix/name
      if [[ -z "${DOCKER_TARGET_REGISTRY:-}" ]]; then
        log_error "DOCKER_TARGET_REGISTRY is required for short-form reference: ${reference}"
        return 1
      fi
      if [[ -z "${DOCKER_TARGET_NAMESPACE:-}" ]]; then
        log_error "DOCKER_TARGET_NAMESPACE is required for short-form reference: ${reference}"
        return 1
      fi
      prefix=$(docker_ref_extract_prefix "${name_part}")
      full_name="${DOCKER_TARGET_REGISTRY}/${DOCKER_TARGET_NAMESPACE}/${prefix}/${name_part}"
      ;;
    prefixed)
      # prefix/name:version -> registry/namespace/prefix/name
      if [[ -z "${DOCKER_TARGET_REGISTRY:-}" ]]; then
        log_error "DOCKER_TARGET_REGISTRY is required for prefixed-form reference: ${reference}"
        return 1
      fi
      if [[ -z "${DOCKER_TARGET_NAMESPACE:-}" ]]; then
        log_error "DOCKER_TARGET_NAMESPACE is required for prefixed-form reference: ${reference}"
        return 1
      fi
      prefix_segment="${name_part%%/*}"
      artifact_name="${name_part#*/}"
      docker_ref_validate_prefix "${prefix_segment}" "${artifact_name}" || return 1
      full_name="${DOCKER_TARGET_REGISTRY}/${DOCKER_TARGET_NAMESPACE}/${name_part}"
      ;;
    full)
      # domain/[namespace/]prefix/name:version -> validate prefix, use as-is
      parent_path="${name_part%/*}"
      prefix_segment="${parent_path##*/}"
      artifact_name="${name_part##*/}"
      docker_ref_validate_prefix "${prefix_segment}" "${artifact_name}" || return 1
      full_name="${name_part}"
      ;;
  esac

  DOCKER_REF_NAME_PART="${name_part}"
  DOCKER_REF_VERSION_PART="${version_part}"
  DOCKER_REF_FULL_NAME="${full_name}"
  DOCKER_REF_FORM="${form}"
}
