#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-workload-deployment.bash - Default values for Kubernetes Deployment workloads
#
# Source this file to get consistent defaults for Deployment-specific variables.
# Source kubernetes-workload.bash separately for common workload defaults.
#
# Variables are set with defaults only if not already set, so callers can
# override by setting values before sourcing this file.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Scaling
# Replicas: empty → token, "NO" → omit for HPA, other → pass through (numeric or custom token)
REPLICAS="${KUBERNETES_DEPLOYMENT_REPLICAS:-}"
REVISION_HISTORY_LIMIT="${KUBERNETES_DEPLOYMENT_REVISION_HISTORY_LIMIT:-10}"
