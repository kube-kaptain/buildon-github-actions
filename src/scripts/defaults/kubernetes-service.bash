#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-service.bash - Default values for Kubernetes Service generation
#
# Source this file to get consistent defaults for Service-related variables.
#
# Defaults are applied to long-form variables (KUBERNETES_SERVICE_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Service configuration
KUBERNETES_SERVICE_TYPE="${KUBERNETES_SERVICE_TYPE:-ClusterIP}"
KUBERNETES_SERVICE_PORT="${KUBERNETES_SERVICE_PORT:-80}"
KUBERNETES_SERVICE_TARGET_PORT="${KUBERNETES_SERVICE_TARGET_PORT:-${KUBERNETES_WORKLOAD_CONTAINER_PORT:-1024}}"
KUBERNETES_SERVICE_PROTOCOL="${KUBERNETES_SERVICE_PROTOCOL:-TCP}"
KUBERNETES_SERVICE_PORT_NAME="${KUBERNETES_SERVICE_PORT_NAME:-}"
KUBERNETES_SERVICE_NODE_PORT="${KUBERNETES_SERVICE_NODE_PORT:-}"
KUBERNETES_SERVICE_EXTERNAL_NAME="${KUBERNETES_SERVICE_EXTERNAL_NAME:-}"
KUBERNETES_SERVICE_EXTERNAL_TRAFFIC_POLICY="${KUBERNETES_SERVICE_EXTERNAL_TRAFFIC_POLICY:-}"

# Naming and paths
KUBERNETES_SERVICE_NAME_SUFFIX="${KUBERNETES_SERVICE_NAME_SUFFIX:-}"
KUBERNETES_SERVICE_COMBINED_SUB_PATH="${KUBERNETES_SERVICE_COMBINED_SUB_PATH:-}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Service configuration
SERVICE_TYPE="${KUBERNETES_SERVICE_TYPE}"
SERVICE_PORT="${KUBERNETES_SERVICE_PORT}"
TARGET_PORT="${KUBERNETES_SERVICE_TARGET_PORT}"
PROTOCOL="${KUBERNETES_SERVICE_PROTOCOL}"
PORT_NAME="${KUBERNETES_SERVICE_PORT_NAME}"
NODE_PORT="${KUBERNETES_SERVICE_NODE_PORT}"
EXTERNAL_NAME="${KUBERNETES_SERVICE_EXTERNAL_NAME}"
EXTERNAL_TRAFFIC_POLICY="${KUBERNETES_SERVICE_EXTERNAL_TRAFFIC_POLICY}"

# Naming and paths
NAME_SUFFIX="${KUBERNETES_SERVICE_NAME_SUFFIX}"
COMBINED_SUB_PATH="${KUBERNETES_SERVICE_COMBINED_SUB_PATH}"
