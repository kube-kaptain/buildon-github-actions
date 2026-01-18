#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-poddisruptionbudget.bash - Default values for Kubernetes PodDisruptionBudget generation
#
# Source this file to get consistent defaults for PDB-related variables.
#
# Defaults are applied to long-form variables (KUBERNETES_PODDISRUPTIONBUDGET_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Naming and paths
KUBERNETES_PODDISRUPTIONBUDGET_NAME_SUFFIX="${KUBERNETES_PODDISRUPTIONBUDGET_NAME_SUFFIX:-}"
KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH="${KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH:-}"

# PDB spec settings
# Strategy: which constraint to use (min-available or max-unavailable)
KUBERNETES_PODDISRUPTIONBUDGET_STRATEGY="${KUBERNETES_PODDISRUPTIONBUDGET_STRATEGY:-max-unavailable}"
# Value: integer or percentage for the chosen strategy
KUBERNETES_PODDISRUPTIONBUDGET_VALUE="${KUBERNETES_PODDISRUPTIONBUDGET_VALUE:-1}"

# Additional labels/annotations
KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_LABELS="${KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_LABELS:-}"
KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_ANNOTATIONS="${KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_ANNOTATIONS:-}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Naming and paths
NAME_SUFFIX="${KUBERNETES_PODDISRUPTIONBUDGET_NAME_SUFFIX}"
COMBINED_SUB_PATH="${KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH}"

# PDB spec settings
STRATEGY="${KUBERNETES_PODDISRUPTIONBUDGET_STRATEGY}"
VALUE="${KUBERNETES_PODDISRUPTIONBUDGET_VALUE}"

# Additional labels/annotations
SPECIFIC_LABELS="${KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_LABELS}"
SPECIFIC_ANNOTATIONS="${KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_ANNOTATIONS}"
