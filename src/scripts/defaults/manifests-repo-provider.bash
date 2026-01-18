#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Manifests repo provider defaults
#
# Configuration for publishing Kubernetes manifests via different repo providers
# (docker image, GitHub release, etc.)
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables
# =============================================================================

# Repo provider type - determines how manifests are packaged and published
MANIFESTS_REPO_PROVIDER_TYPE="${MANIFESTS_REPO_PROVIDER_TYPE:-docker}"

# Base image for docker-based manifest packaging
MANIFESTS_PACKAGING_BASE_IMAGE="${MANIFESTS_PACKAGING_BASE_IMAGE:-scratch}"

# =============================================================================
# Convenience short names (for single-purpose scripts only)
# =============================================================================

REPO_PROVIDER_TYPE="${MANIFESTS_REPO_PROVIDER_TYPE}"
BASE_IMAGE="${MANIFESTS_PACKAGING_BASE_IMAGE}"
