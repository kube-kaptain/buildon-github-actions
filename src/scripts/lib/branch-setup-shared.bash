#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# branch-setup-shared - Common branch configuration and release branch detection
#
# Sourced by scripts that need release branch handling.
#
# shellcheck disable=SC2154 # RELEASE_BRANCH, DEFAULT_BRANCH set by defaults before sourcing

# Current branch validation
if [[ -z "${CURRENT_BRANCH}" ]]; then
  log_error "CURRENT_BRANCH is required"
  exit 1
fi

# Warn if RELEASE_BRANCH was not provided (defaulted to main)
if [[ -z "${RELEASE_BRANCH_INPUT}" ]]; then
  log_warning "RELEASE_BRANCH was not set! Using main..."
  log_warning "Setting RELEASE_BRANCH to: ${RELEASE_BRANCH}"
  log ""
fi

# Warn if DEFAULT_BRANCH was not provided (defaulted to main)
if [[ -z "${DEFAULT_BRANCH_INPUT}" ]]; then
  log_warning "DEFAULT_BRANCH was not set! Using main..."
  log_warning "Setting DEFAULT_BRANCH to: ${DEFAULT_BRANCH}"
  log ""
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
