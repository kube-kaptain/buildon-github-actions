#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-manifest.bash - Default values shared across all Kubernetes manifest generators
#
# Source this file to get consistent defaults for manifest-related variables.
#
# Defaults are applied to long-form variables (KUBERNETES_GLOBAL_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Additional labels/annotations applied to all manifests
KUBERNETES_GLOBAL_ADDITIONAL_LABELS="${KUBERNETES_GLOBAL_ADDITIONAL_LABELS:-}"
KUBERNETES_GLOBAL_ADDITIONAL_ANNOTATIONS="${KUBERNETES_GLOBAL_ADDITIONAL_ANNOTATIONS:-}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Additional labels/annotations
GLOBAL_LABELS="${KUBERNETES_GLOBAL_ADDITIONAL_LABELS}"
GLOBAL_ANNOTATIONS="${KUBERNETES_GLOBAL_ADDITIONAL_ANNOTATIONS}"
