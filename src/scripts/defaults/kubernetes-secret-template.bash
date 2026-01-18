#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-secret-template.bash - Default values for Kubernetes Secret template generation
#
# Source this file to get consistent defaults for Secret template-related variables.
#
# Defaults are applied to long-form variables (KUBERNETES_SECRET_TEMPLATE_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Naming and paths
KUBERNETES_SECRET_TEMPLATE_NAME_SUFFIX="${KUBERNETES_SECRET_TEMPLATE_NAME_SUFFIX:-}"
KUBERNETES_SECRET_TEMPLATE_COMBINED_SUB_PATH="${KUBERNETES_SECRET_TEMPLATE_COMBINED_SUB_PATH:-}"
KUBERNETES_SECRET_TEMPLATE_SUB_PATH="${KUBERNETES_SECRET_TEMPLATE_SUB_PATH:-src/secret.template}"

# Checksum injection
KUBERNETES_SECRET_TEMPLATE_NAME_CHECKSUM_INJECTION="${KUBERNETES_SECRET_TEMPLATE_NAME_CHECKSUM_INJECTION:-true}"

# Additional labels/annotations
KUBERNETES_SECRET_TEMPLATE_ADDITIONAL_LABELS="${KUBERNETES_SECRET_TEMPLATE_ADDITIONAL_LABELS:-}"
KUBERNETES_SECRET_TEMPLATE_ADDITIONAL_ANNOTATIONS="${KUBERNETES_SECRET_TEMPLATE_ADDITIONAL_ANNOTATIONS:-}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Naming and paths
NAME_SUFFIX="${KUBERNETES_SECRET_TEMPLATE_NAME_SUFFIX}"
COMBINED_SUB_PATH="${KUBERNETES_SECRET_TEMPLATE_COMBINED_SUB_PATH}"
BASE_SUB_PATH="${KUBERNETES_SECRET_TEMPLATE_SUB_PATH}"

# Checksum injection
NAME_CHECKSUM_INJECTION="${KUBERNETES_SECRET_TEMPLATE_NAME_CHECKSUM_INJECTION}"

# Additional labels/annotations
SPECIFIC_LABELS="${KUBERNETES_SECRET_TEMPLATE_ADDITIONAL_LABELS}"
SPECIFIC_ANNOTATIONS="${KUBERNETES_SECRET_TEMPLATE_ADDITIONAL_ANNOTATIONS}"
