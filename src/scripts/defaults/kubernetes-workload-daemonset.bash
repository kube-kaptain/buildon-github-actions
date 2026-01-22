#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-workload-daemonset.bash - Default values for Kubernetes DaemonSet workloads
#
# Source this file to get consistent defaults for DaemonSet-specific variables.
# Source kubernetes-workload.bash separately for common workload defaults.
#
# DaemonSets typically run system-level components (log collectors, monitoring agents,
# network plugins, etc.) that often need root access and host-level privileges.
# Defaults here are more permissive than Deployment/StatefulSet.
#
# Defaults are applied to long-form variables (KUBERNETES_DAEMONSET_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Workload naming but unique per type
KUBERNETES_DAEMONSET_ENV_SUB_PATH="${KUBERNETES_DAEMONSET_ENV_SUB_PATH:-src/daemonset-env}"

# DaemonSet unique settings
# Update strategy: RollingUpdate (default) or OnDelete
KUBERNETES_DAEMONSET_UPDATE_STRATEGY_TYPE="${KUBERNETES_DAEMONSET_UPDATE_STRATEGY_TYPE:-RollingUpdate}"
# Max unavailable during rolling update (number or percentage like "10%")
KUBERNETES_DAEMONSET_MAX_UNAVAILABLE="${KUBERNETES_DAEMONSET_MAX_UNAVAILABLE:-1}"

# Host namespace access (common for system DaemonSets)
KUBERNETES_DAEMONSET_HOST_NETWORK="${KUBERNETES_DAEMONSET_HOST_NETWORK:-false}"
KUBERNETES_DAEMONSET_HOST_PID="${KUBERNETES_DAEMONSET_HOST_PID:-false}"
KUBERNETES_DAEMONSET_HOST_IPC="${KUBERNETES_DAEMONSET_HOST_IPC:-false}"

# Security settings - configurable unlike Deployment/StatefulSet
# Non-root is secure default, can be disabled for system-level DaemonSets
KUBERNETES_DAEMONSET_RUN_AS_NON_ROOT="${KUBERNETES_DAEMONSET_RUN_AS_NON_ROOT:-true}"
# Privileged mode off by default, but easily enabled for drivers/plugins
KUBERNETES_DAEMONSET_PRIVILEGED="${KUBERNETES_DAEMONSET_PRIVILEGED:-false}"

# DNS policy (empty for Kubernetes default, set ClusterFirstWithHostNet if hostNetwork=true)
KUBERNETES_DAEMONSET_DNS_POLICY="${KUBERNETES_DAEMONSET_DNS_POLICY:-}"

# Tolerations for running on special nodes (as JSON array)
KUBERNETES_DAEMONSET_TOLERATIONS="${KUBERNETES_DAEMONSET_TOLERATIONS:-}"

# Node selector labels (comma-separated key=value)
KUBERNETES_DAEMONSET_NODE_SELECTOR="${KUBERNETES_DAEMONSET_NODE_SELECTOR:-}"

# Additional labels/annotations
KUBERNETES_DAEMONSET_ADDITIONAL_LABELS="${KUBERNETES_DAEMONSET_ADDITIONAL_LABELS:-}"
KUBERNETES_DAEMONSET_ADDITIONAL_ANNOTATIONS="${KUBERNETES_DAEMONSET_ADDITIONAL_ANNOTATIONS:-}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Workload naming but unique per type
BASE_ENV_SUB_PATH="${KUBERNETES_DAEMONSET_ENV_SUB_PATH}"

# DaemonSet unique settings
UPDATE_STRATEGY_TYPE="${KUBERNETES_DAEMONSET_UPDATE_STRATEGY_TYPE}"
MAX_UNAVAILABLE="${KUBERNETES_DAEMONSET_MAX_UNAVAILABLE}"

# Host namespace access
HOST_NETWORK="${KUBERNETES_DAEMONSET_HOST_NETWORK}"
HOST_PID="${KUBERNETES_DAEMONSET_HOST_PID}"
HOST_IPC="${KUBERNETES_DAEMONSET_HOST_IPC}"

# Security settings
RUN_AS_NON_ROOT="${KUBERNETES_DAEMONSET_RUN_AS_NON_ROOT}"
PRIVILEGED="${KUBERNETES_DAEMONSET_PRIVILEGED}"

# DNS policy
DNS_POLICY="${KUBERNETES_DAEMONSET_DNS_POLICY}"

# Tolerations
TOLERATIONS="${KUBERNETES_DAEMONSET_TOLERATIONS}"

# Node selector
NODE_SELECTOR="${KUBERNETES_DAEMONSET_NODE_SELECTOR}"

# Additional labels/annotations
SPECIFIC_LABELS="${KUBERNETES_DAEMONSET_ADDITIONAL_LABELS}"
SPECIFIC_ANNOTATIONS="${KUBERNETES_DAEMONSET_ADDITIONAL_ANNOTATIONS}"
