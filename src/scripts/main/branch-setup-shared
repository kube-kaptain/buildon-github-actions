#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# branch-setup-shared - Common branch configuration and release branch detection
#
# Sourced by scripts that need release branch handling.
#

# Logging configuration (CI-agnostic)
LOG_ERROR_PREFIX="${LOG_ERROR_PREFIX:-}"
LOG_ERROR_SUFFIX="${LOG_ERROR_SUFFIX:-}"
LOG_WARNING_PREFIX="${LOG_WARNING_PREFIX:-}"
LOG_WARNING_SUFFIX="${LOG_WARNING_SUFFIX:-}"

# Current branch (required by all consumers)
CURRENT_BRANCH="${CURRENT_BRANCH:?Is required}"

# Branch configuration (no defaults - warn and apply if not set)
RELEASE_BRANCH="${RELEASE_BRANCH:-}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-}"
ADDITIONAL_RELEASE_BRANCHES="${ADDITIONAL_RELEASE_BRANCHES:-}"

# Apply default for RELEASE_BRANCH if not set
if [[ -z "${RELEASE_BRANCH}" ]]; then
  RELEASE_BRANCH="main"
  echo "${LOG_WARNING_PREFIX}RELEASE_BRANCH was not set! Using main...${LOG_WARNING_SUFFIX}" >&2
  echo "${LOG_WARNING_PREFIX}Setting RELEASE_BRANCH to: ${RELEASE_BRANCH}${LOG_WARNING_SUFFIX}" >&2
  echo >&2
fi

# Apply default for DEFAULT_BRANCH if not set
if [[ -z "${DEFAULT_BRANCH}" ]]; then
  DEFAULT_BRANCH="main"
  echo "${LOG_WARNING_PREFIX}DEFAULT_BRANCH was not set! Using main...${LOG_WARNING_SUFFIX}" >&2
  echo "${LOG_WARNING_PREFIX}Setting DEFAULT_BRANCH to: ${DEFAULT_BRANCH}${LOG_WARNING_SUFFIX}" >&2
  echo >&2
fi

# Check if current branch is a release branch
is_release_branch() {
  local current_branch="${1}"

  # Check if it's THE release branch
  if [[ "${current_branch}" == "${RELEASE_BRANCH}" ]]; then
    return 0
  fi

  # Check if it matches any of the ADDITIONAL release branches
  if [[ -n "${ADDITIONAL_RELEASE_BRANCHES}" ]]; then
    IFS=',' read -ra branches <<< "${ADDITIONAL_RELEASE_BRANCHES}"
    for branch in "${branches[@]}"; do
      if [[ "${current_branch}" == "${branch}" ]]; then
        return 0
      fi
    done
  fi

  return 1
}
