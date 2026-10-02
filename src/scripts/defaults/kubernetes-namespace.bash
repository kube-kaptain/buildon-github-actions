#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-namespace.bash - Default values for Kubernetes Namespace generation
#
# Source this file to get consistent defaults for Namespace-related variables.
#
# Defaults are applied to long-form variables (KUBERNETES_NAMESPACE_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Naming and paths (KUBERNETES_NAMESPACE_NAME has no default: it is required)
KUBERNETES_NAMESPACE_NAME="${KUBERNETES_NAMESPACE_NAME:-}"
KUBERNETES_NAMESPACE_COMBINED_SUB_PATH="${KUBERNETES_NAMESPACE_COMBINED_SUB_PATH:-}"

# Additional labels/annotations
KUBERNETES_NAMESPACE_ADDITIONAL_LABELS="${KUBERNETES_NAMESPACE_ADDITIONAL_LABELS:-}"
KUBERNETES_NAMESPACE_ADDITIONAL_ANNOTATIONS="${KUBERNETES_NAMESPACE_ADDITIONAL_ANNOTATIONS:-}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Naming and paths
COMBINED_SUB_PATH="${KUBERNETES_NAMESPACE_COMBINED_SUB_PATH}"

# Additional labels/annotations
SPECIFIC_LABELS="${KUBERNETES_NAMESPACE_ADDITIONAL_LABELS}"
SPECIFIC_ANNOTATIONS="${KUBERNETES_NAMESPACE_ADDITIONAL_ANNOTATIONS}"
