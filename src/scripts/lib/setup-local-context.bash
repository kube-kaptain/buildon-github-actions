#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# setup-local-context - Shared setup for reference scripts
#
# Provides auto-detection of git context, build mode, registry/namespace,
# and variable flow infrastructure for running builds locally.
#
# All variables can be overridden via environment before sourcing.
#

# Resolve script locations (used by sourcing scripts, overridable for testing)
SCRIPTS_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${LIB_DIR:-${SCRIPTS_BASE_DIR}/lib}"
# shellcheck disable=SC2034
SCRIPTS_DIR="${SCRIPTS_DIR:-${SCRIPTS_BASE_DIR}/main}"
# shellcheck disable=SC2034
GENERATORS_DIR="${GENERATORS_DIR:-${SCRIPTS_BASE_DIR}/generators}"
# shellcheck disable=SC2034
UTIL_DIR="${UTIL_DIR:-${SCRIPTS_BASE_DIR}/util}"

# Source output-var lib so exports flow between steps in the same shell
# shellcheck disable=SC1091  # Path resolves at runtime via LIB_DIR
source "${LIB_DIR}/output-var.bash"

# Source output-sub-path default for run_step output file location
# shellcheck disable=SC1091  # Path resolves at runtime via SCRIPTS_BASE_DIR
source "${SCRIPTS_BASE_DIR}/defaults/output-sub-path.bash"

# Clean output directory from previous runs
# shellcheck disable=SC2154  # OUTPUT_SUB_PATH set by output-sub-path.bash above
rm -rf "${OUTPUT_SUB_PATH}"


# =============================================================================
# Reference Script Step Runner
# =============================================================================

# Prettify a hyphenated name to title case
prettify_name() {
  echo "${1}" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}'
}

# Print a 5-line centred banner
print_banner() {
  local title="${1}"
  local blank_lines_before="${2:-2}"

  local i
  for (( i=0; i<blank_lines_before; i++ )); do
    echo ""
  done

  local inner_width=74
  local text_len=${#title}
  local pad_left=$(( (inner_width - text_len) / 2 ))
  local pad_right=$(( inner_width - text_len - pad_left ))

  echo "################################################################################"
  printf "###%74s###\n" ""
  printf "###%*s%s%*s###\n" "${pad_left}" "" "${title}" "${pad_right}" ""
  printf "###%74s###\n" ""
  echo "################################################################################"
  echo ""
}

# Print a build step banner
print_step_banner() {
  print_banner "$(prettify_name "${1}")"
}

# Derive build name from calling reference script
REFERENCE_SCRIPT_NAME=$(basename "${BASH_SOURCE[1]}")
REFERENCE_SCRIPT_PRETTY=$(prettify_name "${REFERENCE_SCRIPT_NAME}")

# Print build started banner (called automatically by setup)
print_build_started() {
  print_banner "${REFERENCE_SCRIPT_PRETTY} Build Started" 1
}

# Print build complete banner (called at end of reference script)
print_build_complete() {
  print_banner "${REFERENCE_SCRIPT_PRETTY} build complete!"
}

# Run a build step: print banner, execute script, import output variables
run_step() {
  local step_name="${1}"

  print_step_banner "${step_name}"

  local step_file="${OUTPUT_SUB_PATH}/reference-script-output/${step_name}"
  mkdir -p "$(dirname "${step_file}")"
  : > "${step_file}"

  REFERENCE_SCRIPT_OUTPUT="${step_file}" "${SCRIPTS_DIR}/${step_name}"

  if [[ -s "${step_file}" ]]; then
    while IFS= read -r line; do
      export "${line%%=*}"="${line#*=}"
    done < "${step_file}"
  fi
}

# Run a generator step: same as run_step but from GENERATORS_DIR
run_generator() {
  local step_name="${1}"

  print_step_banner "${step_name}"

  local step_file="${OUTPUT_SUB_PATH}/reference-script-output/${step_name}"
  mkdir -p "$(dirname "${step_file}")"
  : > "${step_file}"

  REFERENCE_SCRIPT_OUTPUT="${step_file}" "${GENERATORS_DIR}/${step_name}"

  if [[ -s "${step_file}" ]]; then
    while IFS= read -r line; do
      export "${line%%=*}"="${line#*=}"
    done < "${step_file}"
  fi
}


print_build_started


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
  remote_count=$(echo "${all_remotes}" | grep -c . 2>/dev/null || echo "0")
  if [[ "${remote_count}" -eq 0 ]]; then
    echo "ERROR: No git remotes configured" >&2
    exit 1
  elif echo "${all_remotes}" | grep -q '^origin$'; then
    REMOTE_NAME="origin"
  elif [[ "${remote_count}" -eq 1 ]]; then
    REMOTE_NAME="${all_remotes}"
  else
    echo "ERROR: Multiple remotes found but none called 'origin':" >&2
    # shellcheck disable=SC2001  # Need sed to prepend to each line; bash parameter expansion can't do this
    echo "${all_remotes}" | sed 's/^/  /' >&2
    echo "Set REMOTE_NAME to specify which remote to use" >&2
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
    branch_count=$(echo "${remote_branches}" | grep -c . 2>/dev/null || echo "0")
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

export CONFIG="{}"
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


# =============================================================================
# Summary
# =============================================================================

echo "=== Build Context ==="
echo "Build mode:      ${BUILD_MODE}"
echo "Build platform:  ${BUILD_PLATFORM}"
echo "Log provider:    ${BUILD_PLATFORM_LOG_PROVIDER}"
echo "Remote:          ${REMOTE_NAME}"
echo "Current branch:  ${CURRENT_BRANCH}"
echo "Target branch:   ${TARGET_BRANCH}"
echo "Release branch:  ${RELEASE_BRANCH}"
echo "Default branch:  ${DEFAULT_BRANCH}"
echo "Repository:      ${REPOSITORY_OWNER}/${REPOSITORY_NAME}"
echo "Registry:        ${DOCKER_TARGET_REGISTRY}"
echo "Namespace:       ${DOCKER_TARGET_NAMESPACE}"
