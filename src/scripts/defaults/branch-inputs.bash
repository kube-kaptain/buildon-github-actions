#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# branch-inputs.bash - Default values for branch configuration
#
# Captures original input values (for warning detection) and applies defaults.
# Source this before branch-setup-shared.bash which uses these values.
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

DEFAULT_BRANCH_INPUT="${DEFAULT_BRANCH:-}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
RELEASE_BRANCH_INPUT="${RELEASE_BRANCH:-}"
RELEASE_BRANCH="${RELEASE_BRANCH:-main}"
CURRENT_BRANCH="${CURRENT_BRANCH:-}"
ADDITIONAL_RELEASE_BRANCHES="${ADDITIONAL_RELEASE_BRANCHES:-}"
