#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# detect-build-context - Auto-detect pre-yaml build context vars
#
# Sets git context, build mode/platform, branch config, and registry/namespace
# from git + filesystem inspection. All variables can be overridden via
# environment before sourcing. No side effects beyond env exports.
#
# Requires log_error to be available (sourced from lib/log.bash or stubbed).
#

# =============================================================================
# Git Context Auto-Detection
# =============================================================================

# Remote name detection:
#   1. REMOTE_NAME set via environment - use it
#   2. "origin" exists - use it (most common)
#   3. Only one remote - use it
#   4. Multiple remotes, none called "origin" - fail
if [[ -z "${REMOTE_NAME:-}" ]]; then
  all_remotes=$(git remote 2>/dev/null || true)
  if [[ -z "${all_remotes}" ]]; then
    remote_count=0
  else
    remote_count=$(echo "${all_remotes}" | grep -c .)
  fi
  if [[ "${remote_count}" -eq 0 ]]; then
    log_error "No git remotes configured"
    exit 1
  elif echo "${all_remotes}" | grep -q '^origin$'; then
    REMOTE_NAME="origin"
  elif [[ "${remote_count}" -eq 1 ]]; then
    REMOTE_NAME="${all_remotes}"
  else
    log_error "Multiple remotes found but none called 'origin':"
    # shellcheck disable=SC2001  # Need sed to prepend to each line; bash parameter expansion can't do this
    echo "${all_remotes}" | sed 's/^/  /' >&2
    log_error "Set REMOTE_NAME to specify which remote to use"
    exit 1
  fi
fi

GIT_REMOTE_URL=$(git config --get "remote.${REMOTE_NAME}.url" 2>/dev/null || echo "")

# Current branch
export CURRENT_BRANCH="${CURRENT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")}"

# Upstream branch detection (most specific to least):
#   1. HEAD symbolic ref for the detected remote
#   2. Only one remote branch - must be the default
#   3. <remote>/main or <remote>/master if either exists
#   4. Fallback: <remote>/main
# Each of DEFAULT_BRANCH, TARGET_BRANCH, RELEASE_BRANCH can be
# independently overridden via environment, defaulting to UPSTREAM_BRANCH.
if [[ -z "${UPSTREAM_BRANCH:-}" ]]; then
  UPSTREAM_BRANCH=$(git symbolic-ref "refs/remotes/${REMOTE_NAME}/HEAD" 2>/dev/null | sed 's@^refs/remotes/@@' || true)
  if [[ -z "${UPSTREAM_BRANCH}" ]]; then
    remote_branches=$(git branch -r 2>/dev/null | grep "^  ${REMOTE_NAME}/" | grep -v ' -> ' | sed 's/^[[:space:]]*//' || true)
    if [[ -z "${remote_branches}" ]]; then
      branch_count=0
    else
      branch_count=$(echo "${remote_branches}" | grep -c .)
    fi
    if [[ "${branch_count}" -eq 1 ]]; then
      UPSTREAM_BRANCH="${remote_branches}"
    elif echo "${remote_branches}" | grep -q "^${REMOTE_NAME}/main$"; then
      UPSTREAM_BRANCH="${REMOTE_NAME}/main"
    elif echo "${remote_branches}" | grep -q "^${REMOTE_NAME}/master$"; then
      UPSTREAM_BRANCH="${REMOTE_NAME}/master"
    else
      UPSTREAM_BRANCH="${REMOTE_NAME}/main"
    fi
  fi
fi
export DEFAULT_BRANCH="${DEFAULT_BRANCH:-${UPSTREAM_BRANCH}}"
export TARGET_BRANCH="${TARGET_BRANCH:-${UPSTREAM_BRANCH}}"
export RELEASE_BRANCH="${RELEASE_BRANCH:-${UPSTREAM_BRANCH}}"

# Repository name from remote URL (works for SSH and HTTPS, with or without .git suffix)
export REPOSITORY_NAME="${REPOSITORY_NAME:-$(echo "${GIT_REMOTE_URL}" | sed 's|.*/||' | sed 's|\.git$||')}"

# Repository owner from remote URL (path segment before repo name)
export REPOSITORY_OWNER="${REPOSITORY_OWNER:-$(echo "${GIT_REMOTE_URL}" | sed -E 's|.*[:/]([^/]+)/[^/]+$|\1|')}"


# =============================================================================
# Build Context
# =============================================================================

export BUILD_MODE="${BUILD_MODE:-local}"
export BUILD_PLATFORM="${BUILD_PLATFORM:-local}"
export BUILD_PLATFORM_LOG_PROVIDER="${BUILD_PLATFORM_LOG_PROVIDER:-stdout}"

export DOCKER_REGISTRY_LOGINS="{}"
export SECRET_METHOD='env'

# =============================================================================
# Branch Configuration
# =============================================================================

export MERGE_CANDIDATE_CREATOR="${MERGE_CANDIDATE_CREATOR:-$(git config user.name 2>/dev/null || whoami)}"


# =============================================================================
# Registry and Namespace Auto-Detection
# =============================================================================

# Auto-detect registry from CI provider config files in the repo
if [[ -z "${DOCKER_TARGET_REGISTRY:-}" ]]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  # shellcheck disable=SC2012
  if ls "${REPO_ROOT}"/.github/workflows/*.y*ml >/dev/null 2>&1; then
    DOCKER_TARGET_REGISTRY="ghcr.io"
  elif [[ -f "${REPO_ROOT}/.gitlab-ci.yml" ]]; then
    DOCKER_TARGET_REGISTRY="registry.gitlab.com"
  else
    DOCKER_TARGET_REGISTRY="localhost"
  fi
fi
export DOCKER_TARGET_REGISTRY

# Namespace is everything between domain and repo name in the git URL, lowercased
if [[ -z "${DOCKER_TARGET_NAMESPACE:-}" ]] && [[ -n "${GIT_REMOTE_URL}" ]]; then
  # Extract the path from the URL (strip domain and repo name)
  # SSH:   git@github.com:org/repo.git      -> org
  # HTTPS: https://github.com/org/repo      -> org
  # HTTPS: https://gitlab.com/g/sub/repo    -> g/sub
  _url_path=""
  if [[ "${GIT_REMOTE_URL}" == *"://"* ]]; then
    # HTTPS: strip scheme + domain, then strip repo name
    _url_path=$(echo "${GIT_REMOTE_URL}" | sed -E 's|https?://[^/]+/||' | sed 's|/[^/]*$||' | sed 's|\.git$||')
  else
    # SSH: strip user@host:, then strip repo name
    _url_path=$(echo "${GIT_REMOTE_URL}" | sed -E 's|[^:]+:||' | sed 's|/[^/]*$||' | sed 's|\.git$||')
  fi
  DOCKER_TARGET_NAMESPACE=$(echo "${_url_path}" | tr '[:upper:]' '[:lower:]')
  unset _url_path
else
  DOCKER_TARGET_NAMESPACE="${BUILD_MODE}"
fi
export DOCKER_TARGET_NAMESPACE
