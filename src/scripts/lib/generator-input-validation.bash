#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Generator input validation library
#
# Functions:
#   validate_enum               - Validate value is one of allowed options
#   validate_boolean            - Validate value is 'true' or 'false'
#   validate_combined_sub_path  - Validate combined sub-path format for output directory nesting
#   validate_common_inputs      - Validate inputs common to all generators
#   validate_workload_inputs    - Validate inputs specific to workload generators (deployment, statefulset, etc.)
#
# Assumes:
#   - token-format.bash is sourced (for validate_token_styles)
#   - LOG_ERROR_PREFIX and LOG_ERROR_SUFFIX are set (can be empty)

# Validate value is one of allowed options
# Usage: validate_enum <var_name> <value> <option1> <option2> ...
#
# Exit codes:
#   0 - Valid
#   4 - Invalid value
#
validate_enum() {
  local var_name="$1"
  local value="$2"
  shift 2
  local options=("$@")

  for opt in "${options[@]}"; do
    if [[ "${value}" == "${opt}" ]]; then
      return 0
    fi
  done

  # Build quoted options list for error message
  local quoted_opts=""
  local last_idx=$((${#options[@]} - 1))
  for i in "${!options[@]}"; do
    if [[ ${i} -eq 0 ]]; then
      quoted_opts="'${options[i]}'"
    elif [[ ${i} -eq ${last_idx} ]]; then
      quoted_opts="${quoted_opts}, or '${options[i]}'"
    else
      quoted_opts="${quoted_opts}, '${options[i]}'"
    fi
  done

  echo "${LOG_ERROR_PREFIX:-}${var_name} must be ${quoted_opts}, got: ${value}${LOG_ERROR_SUFFIX:-}" >&2
  exit 4
}

# Validate value is 'true' or 'false'
# Usage: validate_boolean <var_name> <value>
#
# Exit codes:
#   0 - Valid
#   4 - Invalid value
#
validate_boolean() {
  local var_name="$1"
  local value="$2"

  if [[ "${value}" != "true" && "${value}" != "false" ]]; then
    echo "${LOG_ERROR_PREFIX:-}${var_name} must be 'true' or 'false', got: ${value}${LOG_ERROR_SUFFIX:-}" >&2
    exit 4
  fi
}

# Validate combined sub-path format
# Usage: validate_combined_sub_path <path>
#
# Validates that a combined sub-path (used for output directory nesting) follows rules:
#   - Only lowercase letters, digits, hyphens, and slashes allowed
#   - Must not start or end with a slash
#   - Empty path is valid (returns 0)
#
# Exit codes:
#   0 - Valid (or empty)
#   5 - Invalid characters
#   6 - Leading or trailing slash
#
validate_combined_sub_path() {
  local path="$1"

  # Empty path is valid
  if [[ -z "${path}" ]]; then
    return 0
  fi

  if [[ ! "${path}" =~ ^[a-z0-9/-]+$ ]]; then
    echo "${LOG_ERROR_PREFIX:-}Combined sub-path must contain only lowercase letters, digits, hyphens, and slashes, got: ${path}${LOG_ERROR_SUFFIX:-}" >&2
    exit 5
  fi

  if [[ "${path}" == /* || "${path}" == */ ]]; then
    echo "${LOG_ERROR_PREFIX:-}Combined sub-path must not start or end with a slash, got: ${path}${LOG_ERROR_SUFFIX:-}" >&2
    exit 6
  fi
}

# Validate inputs common to all generators
# Usage: validate_common_inputs
#
# Reads from caller's scope:
#   PROJECT_NAME     - Required project identifier
#   COMBINED_SUB_PATH - Optional sub-path for output nesting
#
# Assumes validate_token_styles is available (from token-format.bash)
#
# Exit codes:
#   1 - PROJECT_NAME missing
#   Other - From validate_token_styles or validate_combined_sub_path
#
validate_common_inputs() {
  if [[ -z "${PROJECT_NAME:-}" ]]; then
    echo "${LOG_ERROR_PREFIX:-}PROJECT_NAME is required${LOG_ERROR_SUFFIX:-}" >&2
    exit 1
  fi

  validate_token_styles
  validate_combined_sub_path "${COMBINED_SUB_PATH:-}"
}

# Validate inputs specific to workload generators (deployment, statefulset, etc.)
# Usage: validate_workload_inputs
#
# Reads from caller's scope:
#   SECCOMP_PROFILE         - Security profile setting
#   READONLY_ROOT_FILESYSTEM - Boolean for filesystem access
#   IMAGE_REFERENCE_STYLE   - How to build image references
#   AFFINITY_STRATEGY       - Pod placement strategy name
#   DNS_POLICY              - Optional DNS policy
#
# Sets in caller's scope:
#   affinity_plugin         - Path to validated affinity strategy plugin
#
# Exit codes:
#   4 - Invalid value for any input
#   5 - Affinity strategy plugin not found
#
# shellcheck disable=SC2154 # SECCOMP_PROFILE, READONLY_ROOT_FILESYSTEM, IMAGE_REFERENCE_STYLE, AFFINITY_STRATEGY set by caller
validate_workload_inputs() {
  validate_enum "KUBERNETES_WORKLOAD_SECCOMP_PROFILE" "${SECCOMP_PROFILE}" \
    DISABLED RuntimeDefault Localhost Unconfined

  validate_boolean "KUBERNETES_WORKLOAD_READONLY_ROOT_FILESYSTEM" "${READONLY_ROOT_FILESYSTEM}"

  validate_enum "KUBERNETES_WORKLOAD_IMAGE_REFERENCE_STYLE" "${IMAGE_REFERENCE_STYLE}" \
    combined separate project-name-prefixed-combined project-name-prefixed-separate

  # Validate DNS policy if set
  if [[ -n "${DNS_POLICY:-}" ]]; then
    validate_enum "KUBERNETES_WORKLOAD_DNS_POLICY" "${DNS_POLICY}" \
      ClusterFirst ClusterFirstWithHostNet Default None
  fi

  # Validate affinity strategy plugin exists (sets affinity_plugin for caller)
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  affinity_plugin="${lib_dir}/../plugins/pod-placement-strategy/${AFFINITY_STRATEGY}"
  if [[ ! -x "${affinity_plugin}" ]]; then
    echo "${LOG_ERROR_PREFIX:-}Unknown affinity strategy '${AFFINITY_STRATEGY}' - plugin not found at ${affinity_plugin}${LOG_ERROR_SUFFIX:-}" >&2
    exit 5
  fi
}
