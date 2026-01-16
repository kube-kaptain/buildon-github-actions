#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-service.bash - Default values for Kubernetes Service generation
#
# Source this file to get consistent defaults for Service-related variables.
#
# Variables are set with defaults only if not already set, so callers can
# override by setting values before sourcing this file.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Service configuration
SERVICE_TYPE="${KUBERNETES_SERVICE_TYPE:-ClusterIP}"
SERVICE_PORT="${KUBERNETES_SERVICE_PORT:-80}"
TARGET_PORT="${KUBERNETES_SERVICE_TARGET_PORT:-${KUBERNETES_WORKLOAD_CONTAINER_PORT:-1024}}"
PROTOCOL="${KUBERNETES_SERVICE_PROTOCOL:-TCP}"

# Naming and paths
NAME_SUFFIX="${KUBERNETES_SERVICE_NAME_SUFFIX:-}"
COMBINED_SUB_PATH="${KUBERNETES_SERVICE_COMBINED_SUB_PATH:-}"
