#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# pre-tagging.bash - CI wrapper to run tests before tagging
#
# Installs BATS if not available (for CI environments), then runs tests.
# This wrapper exists so run-tests.bash stays clean and portable.
#
# In CI, creates an isolated copy of the repo to allow git operations
# (like git checkout in assemble-workflows.bash) without permission issues.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Install BATS if not available (CI environments like GitHub Actions ubuntu-24.04)
if ! command -v bats &>/dev/null; then
  echo "Installing BATS..."
  sudo apt-get update -qq && sudo apt-get install -y -qq bats
fi

# In CI (detected by GITHUB_ACTIONS), run tests in an isolated copy
# This allows git operations without permission issues
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "CI detected - creating isolated test environment..."

  TEST_CHROOT=$(mktemp -d)
  trap 'rm -rf "$TEST_CHROOT"' EXIT

  # Copy .git directory
  cp -r "$PROJECT_ROOT/.git" "$TEST_CHROOT/"

  # Checkout all files into the isolated copy
  git -C "$TEST_CHROOT" checkout .

  echo "Running tests in isolated environment: $TEST_CHROOT"
  exec "$TEST_CHROOT/.github/bin/run-tests.bash"
else
  exec "$SCRIPT_DIR/run-tests.bash"
fi
