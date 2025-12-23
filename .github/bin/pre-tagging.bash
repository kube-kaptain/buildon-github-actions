#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# pre-tagging.bash - CI wrapper to run tests before tagging
#
# Installs BATS if not available (for CI environments), then runs tests.
# This wrapper exists so run-tests.bash stays clean and portable.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install BATS if not available (CI environments like GitHub Actions ubuntu-24.04)
if ! command -v bats &>/dev/null; then
  echo "Installing BATS..."
  sudo apt-get update -qq && sudo apt-get install -y -qq bats
fi

exec "$SCRIPT_DIR/run-tests.bash"
