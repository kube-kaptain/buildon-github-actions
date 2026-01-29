#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# tag-version-calculation - Shared functions for tag version calculation providers
#
# Sourced by tag version calculation plugins. Provides common version
# extraction, prefix handling, tag lookup, and increment logic.
#
# Requires LOG_ERROR_PREFIX and LOG_ERROR_SUFFIX to be set (may be empty).
#
# shellcheck disable=SC2034 # SOURCE_SUB_PATH, SOURCE_FILE_NAME, VERSION_PATTERN used by callers
# shellcheck disable=SC2154 # TAG_VERSION_PATTERN_TYPE, LOG_ERROR_PREFIX/SUFFIX set by callers

TAG_VERSION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set defaults based on pattern type for source file extraction
# Sets: SOURCE_SUB_PATH, SOURCE_FILE_NAME, VERSION_PATTERN
set_defaults_for_type() {
  case "${TAG_VERSION_PATTERN_TYPE}" in
    dockerfile-env-kubectl)
      SOURCE_SUB_PATH="${TAG_VERSION_SOURCE_SUB_PATH:-${DOCKERFILE_SUB_PATH}}"
      SOURCE_FILE_NAME="${TAG_VERSION_SOURCE_FILE_NAME:-Dockerfile}"
      VERSION_PATTERN="${TAG_VERSION_SOURCE_CUSTOM_PATTERN:-^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$}"
      ;;
    retag-workflow-source-tag)
      SOURCE_SUB_PATH="${TAG_VERSION_SOURCE_SUB_PATH:-.github/workflows}"
      SOURCE_FILE_NAME="${TAG_VERSION_SOURCE_FILE_NAME:-build.yaml}"
      VERSION_PATTERN="${TAG_VERSION_SOURCE_CUSTOM_PATTERN:-^[[:space:]]*docker-source-tag:[[:space:]]*['\"]?([0-9]+\.[0-9]+\.[0-9]+)['\"]?$}"
      ;;
    custom)
      if [[ -z "${TAG_VERSION_SOURCE_SUB_PATH:-}" ]]; then
        echo "${LOG_ERROR_PREFIX}TAG_VERSION_SOURCE_SUB_PATH is required for custom pattern type${LOG_ERROR_SUFFIX}" >&2
        exit 1
      fi
      if [[ -z "${TAG_VERSION_SOURCE_FILE_NAME:-}" ]]; then
        echo "${LOG_ERROR_PREFIX}TAG_VERSION_SOURCE_FILE_NAME is required for custom pattern type${LOG_ERROR_SUFFIX}" >&2
        exit 1
      fi
      if [[ -z "${TAG_VERSION_SOURCE_CUSTOM_PATTERN:-}" ]]; then
        echo "${LOG_ERROR_PREFIX}TAG_VERSION_SOURCE_CUSTOM_PATTERN is required for custom pattern type${LOG_ERROR_SUFFIX}" >&2
        exit 1
      fi
      SOURCE_SUB_PATH="${TAG_VERSION_SOURCE_SUB_PATH}"
      SOURCE_FILE_NAME="${TAG_VERSION_SOURCE_FILE_NAME}"
      VERSION_PATTERN="${TAG_VERSION_SOURCE_CUSTOM_PATTERN}"
      ;;
    *)
      echo "${LOG_ERROR_PREFIX}Unknown TAG_VERSION_PATTERN_TYPE: ${TAG_VERSION_PATTERN_TYPE}${LOG_ERROR_SUFFIX}" >&2
      echo "Valid types: dockerfile-env-kubectl, retag-workflow-source-tag, custom" >&2
      exit 1
      ;;
  esac
}

# Validate that a string looks like a version (digits separated by dots)
validate_version_format() {
  local value="${1}"
  local label="${2:-}"
  if [[ ! "${value}" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    if [[ -n "${label}" ]]; then
      echo "${LOG_ERROR_PREFIX}Captured value '${value}' from ${label} is not a valid version format${LOG_ERROR_SUFFIX}" >&2
    else
      echo "${LOG_ERROR_PREFIX}Captured value '${value}' is not a valid version format${LOG_ERROR_SUFFIX}" >&2
    fi
    echo "Expected: digits separated by dots (e.g., 1, 1.28, 1.28.0)" >&2
    exit 1
  fi
}

# Extract version from a file using a regex pattern
extract_version_from_file() {
  local source_file="${1}"
  local pattern="${2}"
  local label="${3:-}"

  if [[ ! -f "${source_file}" ]]; then
    echo "${LOG_ERROR_PREFIX}Source file not found: ${source_file}${LOG_ERROR_SUFFIX}" >&2
    exit 1
  fi

  local version
  version=$(grep -E "${pattern}" "${source_file}" | head -1 | sed -E "s/${pattern}/\\1/")

  if [[ -z "${version}" ]]; then
    echo "${LOG_ERROR_PREFIX}Could not find version matching pattern in ${source_file} (${label})${LOG_ERROR_SUFFIX}" >&2
    echo "Pattern: ${pattern}" >&2
    exit 1
  fi

  validate_version_format "${version}" "${label}"
  echo "${version}"
}

# Get N-part prefix from version
get_prefix() {
  local version="${1}"
  local num_parts="${2}"

  IFS='.' read -ra parts <<< "${version}"
  local result=""
  for ((i=0; i<num_parts && i<${#parts[@]}; i++)); do
    if [[ ${i} -gt 0 ]]; then
      result+="."
    fi
    result+="${parts[${i}]}"
  done
  echo "${result}"
}

# Count parts in a version string
count_version_parts() {
  local version="${1}"
  local dot_count
  dot_count=$(echo "${version}" | tr -cd '.' | wc -c | tr -d ' ')
  echo $((dot_count + 1))
}

# Find highest tag matching prefix
find_highest_in_series() {
  local prefix="${1}"

  # Get ALL tags in repo matching our prefix with pure numeric versions only
  # The regex ensures: starts with prefix, followed by dot and digits only, no suffixes
  local highest
  highest=$(git tag --list | while read -r tag; do
    if [[ "${tag}" =~ ^${prefix}\.[0-9]+$ ]]; then
      echo "${tag}"
    fi
  done | "${TAG_VERSION_LIB_DIR}/../util/version-sort" | tail -n1)

  echo "${highest}"
}

# Increment last version component
increment_version() {
  local prefix="${1}"
  local previous_version="${2}"

  if [[ -z "${previous_version}" ]]; then
    echo "${prefix}.1"
    return
  fi

  IFS='.' read -ra parts <<< "${previous_version}"
  local last_idx=$((${#parts[@]} - 1))
  parts[last_idx]=$((parts[last_idx] + 1))
  local IFS='.'
  echo "${parts[*]}"
}
