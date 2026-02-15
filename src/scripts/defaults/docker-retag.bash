#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Docker source image configuration
#
# Defaults are applied to long-form variables (DOCKER_SOURCE_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

DOCKER_SOURCE_REGISTRY="${DOCKER_SOURCE_REGISTRY:-}"
DOCKER_SOURCE_NAMESPACE="${DOCKER_SOURCE_NAMESPACE:-}"
DOCKER_SOURCE_IMAGE_NAME="${DOCKER_SOURCE_IMAGE_NAME:-}"
DOCKER_SOURCE_TAG="${DOCKER_SOURCE_TAG:-}"

# =============================================================================
# Convenience short names (for single-purpose scripts only)
# =============================================================================

SOURCE_REGISTRY="${DOCKER_SOURCE_REGISTRY}"
INPUT_SOURCE_NAMESPACE="${DOCKER_SOURCE_NAMESPACE}"
INPUT_SOURCE_IMAGE_NAME="${DOCKER_SOURCE_IMAGE_NAME}"
SOURCE_TAG="${DOCKER_SOURCE_TAG}"
