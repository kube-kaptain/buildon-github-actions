#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-workload-statefulset.bash - Default values for Kubernetes StatefulSet workloads
#
# Source this file to get consistent defaults for StatefulSet-specific variables.
# Source kubernetes-workload.bash separately for common workload defaults.
#
# Defaults are applied to long-form variables (KUBERNETES_STATEFULSET_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Workload naming but unique per type
KUBERNETES_STATEFULSET_ENV_SUB_PATH="${KUBERNETES_STATEFULSET_ENV_SUB_PATH:-src/statefulset-env}"

# StatefulSet unique settings
# Service name: required for StatefulSet, defaults to project-name-headless token pattern
KUBERNETES_STATEFULSET_SERVICE_NAME="${KUBERNETES_STATEFULSET_SERVICE_NAME:-}"
# Pod management policy: OrderedReady (default) or Parallel
KUBERNETES_STATEFULSET_POD_MANAGEMENT_POLICY="${KUBERNETES_STATEFULSET_POD_MANAGEMENT_POLICY:-OrderedReady}"
# Update strategy: RollingUpdate (default) or OnDelete
KUBERNETES_STATEFULSET_UPDATE_STRATEGY_TYPE="${KUBERNETES_STATEFULSET_UPDATE_STRATEGY_TYPE:-RollingUpdate}"
# Partition for rolling updates (only applies when strategy is RollingUpdate)
KUBERNETES_STATEFULSET_UPDATE_STRATEGY_PARTITION="${KUBERNETES_STATEFULSET_UPDATE_STRATEGY_PARTITION:-}"

# Persistent volume claim template
# Storage class: empty for cluster default, or specific class name
KUBERNETES_STATEFULSET_PVC_STORAGE_CLASS="${KUBERNETES_STATEFULSET_PVC_STORAGE_CLASS:-}"
# Storage size: e.g., 1Gi, 10Gi
KUBERNETES_STATEFULSET_PVC_STORAGE_SIZE="${KUBERNETES_STATEFULSET_PVC_STORAGE_SIZE:-1Gi}"
# Access modes: ReadWriteOnce (default), ReadOnlyMany, ReadWriteMany
KUBERNETES_STATEFULSET_PVC_ACCESS_MODE="${KUBERNETES_STATEFULSET_PVC_ACCESS_MODE:-ReadWriteOnce}"
# Volume name for the PVC template
KUBERNETES_STATEFULSET_PVC_VOLUME_NAME="${KUBERNETES_STATEFULSET_PVC_VOLUME_NAME:-data}"
# Mount path for the persistent volume
KUBERNETES_STATEFULSET_PVC_MOUNT_PATH="${KUBERNETES_STATEFULSET_PVC_MOUNT_PATH:-/data}"
# Enable/disable PVC generation
KUBERNETES_STATEFULSET_PVC_ENABLED="${KUBERNETES_STATEFULSET_PVC_ENABLED:-true}"

# Additional labels/annotations
KUBERNETES_STATEFULSET_ADDITIONAL_LABELS="${KUBERNETES_STATEFULSET_ADDITIONAL_LABELS:-}"
KUBERNETES_STATEFULSET_ADDITIONAL_ANNOTATIONS="${KUBERNETES_STATEFULSET_ADDITIONAL_ANNOTATIONS:-}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Workload naming but unique per type
BASE_ENV_SUB_PATH="${KUBERNETES_STATEFULSET_ENV_SUB_PATH}"

# StatefulSet unique settings
SERVICE_NAME="${KUBERNETES_STATEFULSET_SERVICE_NAME}"
POD_MANAGEMENT_POLICY="${KUBERNETES_STATEFULSET_POD_MANAGEMENT_POLICY}"
UPDATE_STRATEGY_TYPE="${KUBERNETES_STATEFULSET_UPDATE_STRATEGY_TYPE}"
UPDATE_STRATEGY_PARTITION="${KUBERNETES_STATEFULSET_UPDATE_STRATEGY_PARTITION}"

# Persistent volume claim template
PVC_STORAGE_CLASS="${KUBERNETES_STATEFULSET_PVC_STORAGE_CLASS}"
PVC_STORAGE_SIZE="${KUBERNETES_STATEFULSET_PVC_STORAGE_SIZE}"
PVC_ACCESS_MODE="${KUBERNETES_STATEFULSET_PVC_ACCESS_MODE}"
PVC_VOLUME_NAME="${KUBERNETES_STATEFULSET_PVC_VOLUME_NAME}"
PVC_MOUNT_PATH="${KUBERNETES_STATEFULSET_PVC_MOUNT_PATH}"
PVC_ENABLED="${KUBERNETES_STATEFULSET_PVC_ENABLED}"

# Additional labels/annotations
SPECIFIC_LABELS="${KUBERNETES_STATEFULSET_ADDITIONAL_LABELS}"
SPECIFIC_ANNOTATIONS="${KUBERNETES_STATEFULSET_ADDITIONAL_ANNOTATIONS}"
