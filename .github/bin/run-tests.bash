#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# run-tests.bash - Run all tests for buildon-github-actions
#
# Uses BATS (Bash Automated Testing System) either locally or via Docker
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT/src/test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check if BATS is available
has_bats() {
  command -v bats &>/dev/null
}

# Check if Docker is available
has_docker() {
  command -v docker &>/dev/null
}

# Run tests with local BATS
run_local() {
  log_info "Running tests with local BATS"
  cd "$TEST_DIR"
  bats *.bats
}

# Run tests with Docker
run_docker() {
  log_info "Running tests with Docker (bats/bats:latest)"
  docker run --rm \
    -v "$PROJECT_ROOT:/workspace" \
    -w /workspace/src/test \
    -e "PROJECT_ROOT=/workspace" \
    "bats/bats:1.13.0" \
    --tap *.bats
}

# Check all scripts are executable
check_executables() {
  log_info "Checking scripts are executable"
  local scripts=()
  local globs=(
    "$PROJECT_ROOT/src/scripts/main/*"
    "$PROJECT_ROOT/src/scripts/plugins/*/*"
    "$PROJECT_ROOT/src/test/*.bash"
    "$PROJECT_ROOT/src/test/repo-gen/*.bash"
    "$PROJECT_ROOT/.github/bin/*.bash"
  )

  for glob in "${globs[@]}"; do
    for file in $glob; do
      # Skip markdown files - they're documentation, not scripts
      [[ "$file" == *.md ]] && continue
      [[ -f "$file" ]] && scripts+=("$file")
    done
  done

  local failed=()
  local scanned=0

  for script in "${scripts[@]}"; do
    scanned=$((scanned + 1))
    if [[ ! -x "$script" ]]; then
      failed+=("$script")
    fi
  done

  log_info "Scanned $scanned scripts"

  if [[ ${#failed[@]} -gt 0 ]]; then
    log_error "${#failed[@]} script(s) missing executable permission:"
    for f in "${failed[@]}"; do
      log_error "  - ${f#$PROJECT_ROOT/}"
    done
    exit 1
  fi

  log_info "All scripts executable"
}

# Check generated files are up to date
check_generated_files() {
  log_info "Checking generated files are up to date"

  # Run the assemble script
  "$PROJECT_ROOT/src/bin/assemble-workflows.bash" > /dev/null

  # Check for modified files in generated locations
  local modified_generated
  modified_generated=$(git -C "$PROJECT_ROOT" diff --name-only .github/workflows/ docs/ README.md 2>/dev/null || true)

  if [[ -z "$modified_generated" ]]; then
    log_info "Generated files are up to date"
    return 0
  fi

  # Check for any dirty source files that affect generation (staged or unstaged)
  # Workflow templates, step fragments, and actions all contribute to generated output
  local dirty_sources
  dirty_sources=$(git -C "$PROJECT_ROOT" status --porcelain \
    src/workflow-templates/ \
    src/steps-common/ \
    src/actions/ \
    2>/dev/null | grep -v '^?' || true)

  # If ANY source is dirty, generated file changes are local work in progress
  if [[ -n "$dirty_sources" ]]; then
    log_warn "Uncommitted local changes detected - generated files regenerated OK:"
    echo "$modified_generated" | while IFS= read -r file; do
      [[ -n "$file" ]] && log_warn "  - $file"
    done
    log_info "Generated files OK (stage/commit when ready)"
    return 0
  fi

  # No sources dirty but generated files changed - assemble already ran, just need to commit
  log_error "Generated files were regenerated but source files are already committed."
  log_error "This likely means you committed source changes without regenerating."
  log_error "The files below have been regenerated - stage and commit them:"
  echo "$modified_generated" | while IFS= read -r file; do
    [[ -n "$file" ]] && log_error "  - $file"
  done

  # Show the actual diff so CI logs reveal what's different
  log_error "Diff of generated files:"
  git -C "$PROJECT_ROOT" diff .github/workflows/ docs/ README.md || true
  if [[ "${WARN_ONLY_FRESHNESS:-}" == "true" ]]; then
    log_warn "Continuing despite stale files (WARN_ONLY_FRESHNESS=true)"
  else
    exit 1
  fi
}

# Run shellcheck on all scripts
run_shellcheck() {
  log_info "Running shellcheck on scripts"
  local scripts=()
  local globs=(
    "${PROJECT_ROOT}/src/scripts/main/*"
    "${PROJECT_ROOT}/src/scripts/plugins/*/*"
  )

  # Style checks to enable (in addition to defaults)
  local enables=(
    --external-sources
    --enable=require-variable-braces
    --enable=require-double-brackets
    --enable=avoid-nullary-conditions
    --enable=check-unassigned-uppercase
    --enable=deprecate-which
  )

  for glob in "${globs[@]}"; do
    for file in $glob; do
      # Skip markdown files - they're documentation, not scripts
      [[ "${file}" == *.md ]] && continue
      [[ -f "${file}" ]] && scripts+=("${file}")
    done
  done

  if [[ ${#scripts[@]} -eq 0 ]]; then
    log_warn "No scripts found to check"
    return 0
  fi

  log_info "Checking ${#scripts[@]} scripts"

  if command -v shellcheck &>/dev/null; then
    shellcheck "${enables[@]}" "${scripts[@]}"
  elif has_docker; then
    docker run --rm \
      -v "${PROJECT_ROOT}:/workspace" \
      koalaman/shellcheck:stable \
      "${enables[@]}" "${scripts[@]/#${PROJECT_ROOT}//workspace}"
  else
    log_warn "shellcheck not available, skipping"
    return 0
  fi

  log_info "shellcheck passed"
}

main() {
  log_info "Starting test suite"
  log_info "Project root: ${PROJECT_ROOT}"

  # Check scripts are executable
  check_executables

  # Run shellcheck
  run_shellcheck

  # Run BATS tests
  if has_bats; then
    run_local
  elif has_docker; then
    run_docker
  else
    log_error "Neither BATS nor Docker available. Cannot run tests."
    exit 1
  fi

  # Check generated files are up to date (last, so real tests run first)
  check_generated_files

  log_info "All tests passed!"
}

main "$@"
