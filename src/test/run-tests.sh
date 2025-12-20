#!/usr/bin/env bash
#
# run-tests.sh - Run all tests for buildon-github-actions
#
# Uses BATS (Bash Automated Testing System) either locally or via Docker
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
  cd "$SCRIPT_DIR"
  bats --tap *.bats
}

# Run tests with Docker
run_docker() {
  log_info "Running tests with Docker (bats/bats:latest)"
  docker run --rm \
    -v "$PROJECT_ROOT:/workspace" \
    -w /workspace/src/test \
    -e "PROJECT_ROOT=/workspace" \
    bats/bats:latest \
    --tap *.bats
}

# Run shellcheck on all scripts
run_shellcheck() {
  log_info "Running shellcheck on scripts"
  local scripts=(
    "$PROJECT_ROOT/src/scripts/versions-and-naming"
    "$PROJECT_ROOT/src/scripts/basic-quality-checks"
  )

  if command -v shellcheck &>/dev/null; then
    shellcheck "${scripts[@]}"
  elif has_docker; then
    docker run --rm \
      -v "$PROJECT_ROOT:/workspace" \
      koalaman/shellcheck:stable \
      "${scripts[@]/#$PROJECT_ROOT//workspace}"
  else
    log_warn "shellcheck not available, skipping"
    return 0
  fi

  log_info "shellcheck passed"
}

main() {
  log_info "Starting test suite"
  log_info "Project root: $PROJECT_ROOT"

  # Run shellcheck first
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

  log_info "All tests passed!"
}

main "$@"
