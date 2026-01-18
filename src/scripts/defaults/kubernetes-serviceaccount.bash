#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-serviceaccount.bash - Default values for Kubernetes ServiceAccount generation
#
# Source this file to get consistent defaults for ServiceAccount-related variables.
#
# Defaults are applied to long-form variables (KUBERNETES_SERVICEACCOUNT_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Naming and paths
KUBERNETES_SERVICEACCOUNT_NAME_SUFFIX="${KUBERNETES_SERVICEACCOUNT_NAME_SUFFIX:-}"
KUBERNETES_SERVICEACCOUNT_COMBINED_SUB_PATH="${KUBERNETES_SERVICEACCOUNT_COMBINED_SUB_PATH:-}"

# Additional labels/annotations
KUBERNETES_SERVICEACCOUNT_ADDITIONAL_LABELS="${KUBERNETES_SERVICEACCOUNT_ADDITIONAL_LABELS:-}"
KUBERNETES_SERVICEACCOUNT_ADDITIONAL_ANNOTATIONS="${KUBERNETES_SERVICEACCOUNT_ADDITIONAL_ANNOTATIONS:-}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Naming and paths
NAME_SUFFIX="${KUBERNETES_SERVICEACCOUNT_NAME_SUFFIX}"
COMBINED_SUB_PATH="${KUBERNETES_SERVICEACCOUNT_COMBINED_SUB_PATH}"

# Additional labels/annotations
SPECIFIC_LABELS="${KUBERNETES_SERVICEACCOUNT_ADDITIONAL_LABELS}"
SPECIFIC_ANNOTATIONS="${KUBERNETES_SERVICEACCOUNT_ADDITIONAL_ANNOTATIONS}"
