#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Docker build target defaults
#
# Defaults are applied to long-form variables (DOCKER_TARGET_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Docker registry logins
DOCKER_REGISTRY_LOGINS="${DOCKER_REGISTRY_LOGINS:-}"

# Docker target config
DOCKER_TARGET_REGISTRY="${DOCKER_TARGET_REGISTRY:-}"
DOCKER_TARGET_BASE_PATH="${DOCKER_TARGET_BASE_PATH:-}"

# Docker push targets
DOCKER_PUSH_TARGETS="${DOCKER_PUSH_TARGETS:-}"

# =============================================================================
# Convenience short names (for single-purpose scripts only)
# =============================================================================

TARGET_REGISTRY="${DOCKER_TARGET_REGISTRY}"
INPUT_TARGET_BASE_PATH="${DOCKER_TARGET_BASE_PATH}"
