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

# Source log lib: detect-build-context calls log_error on its failure paths
# (detached HEAD, multiple remotes) - without this those paths die with
# "command not found" (127) instead of the intended message. log.bash needs
# the provider at source time; detect-build-context applies the same default
# later for everything else.
export BUILD_PLATFORM_LOG_PROVIDER="${BUILD_PLATFORM_LOG_PROVIDER:-stdout}"
# shellcheck disable=SC1091  # Path resolves at runtime via LIB_DIR
source "${LIB_DIR}/log.bash"

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


# Detect pre-yaml build context (git, build mode, registry, namespace)
# shellcheck source=src/scripts/lib/detect-build-context.bash
source "${LIB_DIR}/detect-build-context.bash"


# =============================================================================
# Summary
# =============================================================================

# Branch vars are default-guarded: the KAPTAIN_LOCAL_RELEASE path
# deliberately leaves them unset (file policy applies at load).
echo "=== Build Context ==="
echo "Build mode:      ${BUILD_MODE}"
echo "Build platform:  ${BUILD_PLATFORM}"
echo "Log provider:    ${BUILD_PLATFORM_LOG_PROVIDER}"
echo "Remote:          ${REMOTE_NAME}"
echo "Current branch:  ${CURRENT_BRANCH}"
echo "Target branch:   ${TARGET_BRANCH:-}"
echo "Release branch:  ${RELEASE_BRANCH:-}"
echo "Default branch:  ${DEFAULT_BRANCH:-}"
echo "Repository:      ${REPOSITORY_OWNER}/${REPOSITORY_NAME}"
echo "Registry:        ${DOCKER_TARGET_REGISTRY}"
echo "Namespace:       ${DOCKER_TARGET_NAMESPACE}"
