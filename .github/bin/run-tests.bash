#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# run-tests.bash - Run all tests for buildon-github-actions
#
# Uses BATS (Bash Automated Testing System) either locally or via Docker
#
set -euo pipefail

# This script runs the FULL test suite (~10 minutes). For specific tests, use local bats.
if [[ $# -gt 0 ]]; then
  echo "ERROR: This script runs the full suite and takes 10 minutes."
  echo "Please run the suite you want with local bats instead:"
  echo "  bats $*"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT/src/test"

# Sanitize environment to prevent CI workflow inputs from bleeding into tests
# Keep only essential system variables, unset everything else
while IFS='=' read -r name _; do
  case "$name" in
    PATH|HOME|TMPDIR|TERM|USER|LANG|LC_*|SHELL) ;;
    *) unset "$name" ;;
  esac
done < <(env)

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
  log_info "Running tests with Docker (bats/bats:1.13.0)"
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
    "$PROJECT_ROOT/src/scripts/generators/*"
    "$PROJECT_ROOT/src/scripts/plugins/*/*"
    "$PROJECT_ROOT/src/scripts/util/*"
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

# Check sourced files are NOT executable (they should only be sourced, not run directly)
check_sourced_not_executable() {
  log_info "Checking sourced files are not executable"
  local sourced_files=()
  local globs=(
    "$PROJECT_ROOT/src/scripts/lib/*"
    "$PROJECT_ROOT/src/scripts/defaults/*"
  )

  for glob in "${globs[@]}"; do
    for file in $glob; do
      [[ -f "$file" ]] && sourced_files+=("$file")
    done
  done

  local wrongly_executable=()
  local scanned=0

  for script in "${sourced_files[@]}"; do
    scanned=$((scanned + 1))
    if [[ -x "$script" ]]; then
      wrongly_executable+=("$script")
    fi
  done

  log_info "Scanned $scanned sourced files"

  if [[ ${#wrongly_executable[@]} -gt 0 ]]; then
    log_error "${#wrongly_executable[@]} sourced file(s) should NOT be executable (they are sourced, not run directly):"
    for f in "${wrongly_executable[@]}"; do
      log_error "  - ${f#$PROJECT_ROOT/}"
    done
    log_error "Fix with: chmod -x <file>"
    exit 1
  fi

  log_info "All sourced files correctly not executable"
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
    "${PROJECT_ROOT}/src/scripts/generators/*"
    "${PROJECT_ROOT}/src/scripts/plugins/*/*"
    "${PROJECT_ROOT}/src/scripts/lib/*"
    "${PROJECT_ROOT}/src/scripts/util/*"
    "${PROJECT_ROOT}/src/scripts/defaults/*"
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
      koalaman/shellcheck:v0.10.0 \
      "${enables[@]}" "${scripts[@]/#${PROJECT_ROOT}//workspace}"
  else
    log_warn "shellcheck not available, skipping"
    return 0
  fi

  log_info "shellcheck passed"
}

# Check for Bash 4+ features (scripts must be Bash 3.2 compatible for macOS)
check_bash_portability() {
  log_info "Checking for Bash 4+ features (must be 3.2 compatible)"
  local scripts=()

  while IFS= read -r file; do
    # Skip markdown files - they're documentation, not scripts
    [[ "${file}" == *.md ]] && continue
    scripts+=("${file}")
  done < <(find "${PROJECT_ROOT}/src/scripts" -type f)

  local failed=()

  # Patterns that indicate Bash 4+ features
  # - declare -A: associative arrays
  # - mapfile/readarray: array reading builtin
  # - ${var,,} ${var^^}: case modification
  # - |&: pipe stderr shorthand
  # - coproc: coprocesses
  # - shopt -s globstar: recursive glob
  # - &>>: append stdout+stderr (distinct from &>/dev/null which is 3.2 compatible)
  local bash4_pattern='declare[[:space:]]+-A|mapfile|readarray|\$\{[^}]+,,\}|\$\{[^}]+\^\^\}|\|&|^[[:space:]]*coproc[[:space:]]|shopt[[:space:]]+-s[[:space:]]+globstar|&>>'

  for script in "${scripts[@]}"; do
    if grep -qE "${bash4_pattern}" "${script}" 2>/dev/null; then
      # Get matching lines for error output
      local matches
      matches=$(grep -nE "${bash4_pattern}" "${script}" 2>/dev/null || true)
      if [[ -n "${matches}" ]]; then
        failed+=("${script}")
        log_error "Bash 4+ feature in ${script#${PROJECT_ROOT}/}:"
        echo "${matches}" | while IFS= read -r line; do
          log_error "  ${line}"
        done
      fi
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log_error "${#failed[@]} script(s) use Bash 4+ features (must be 3.2 compatible for macOS)"
    exit 1
  fi

  log_info "All scripts are Bash 3.2 compatible"
}

# Check example files reference the expected next version tag
check_example_versions() {
  log_info "Checking example version references"

  # Find highest existing tag (this repo uses simple x.y.z tags)
  local highest
  highest=$(git -C "${PROJECT_ROOT}" tag --list '[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)

  if [[ -z "${highest}" ]]; then
    log_warn "No version tags found, skipping example version check"
    return 0
  fi

  # Parse and increment patch
  local major minor patch
  IFS='.' read -r major minor patch <<< "${highest}"
  local expected="${major}.${minor}.$((patch + 1))"

  log_info "Highest tag: ${highest}, expected in examples: @${expected}"

  # Find all version references in examples that don't match
  local mismatched=()
  for file in "${PROJECT_ROOT}"/examples/*.yaml; do
    [[ -f "${file}" ]] || continue
    local bad_lines
    bad_lines=$(grep -n '@[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' "${file}" | grep -v "@${expected}" || true)
    if [[ -n "${bad_lines}" ]]; then
      mismatched+=("${file#${PROJECT_ROOT}/}")
      echo "${bad_lines}" | while IFS= read -r line; do
        log_error "  ${file#${PROJECT_ROOT}/}:${line}"
      done
    fi
  done

  if [[ ${#mismatched[@]} -gt 0 ]]; then
    log_error "${#mismatched[@]} example file(s) have wrong version (expected @${expected})"
    exit 1
  fi

  log_info "All examples reference @${expected}"
}

main() {
  log_info "Starting test suite"
  log_info "Project root: ${PROJECT_ROOT}"

  # Clear and recreate target/test directory for test artifacts
  rm -rf "${PROJECT_ROOT}/target/test"
  mkdir -p "${PROJECT_ROOT}/target/test"
  log_info "Cleared target/test/ for test artifacts"

  # Check scripts are executable
  check_executables

  # Check sourced files are NOT executable
  check_sourced_not_executable

  # Check for Bash 4+ features
  check_bash_portability

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

  # Check generated files are up to date (last-ish, so real tests run first)
  check_generated_files

  # Check examples reference the next version (last - useful to get a full run before this fails)
  check_example_versions

  log_info "All tests passed!"
}

main "$@"
