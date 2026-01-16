#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-serviceaccount.bash - Default values for Kubernetes ServiceAccount generation
#
# Source this file to get consistent defaults for ServiceAccount-related variables.
#
# Variables are set with defaults only if not already set, so callers can
# override by setting values before sourcing this file.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Naming and paths
NAME_SUFFIX="${KUBERNETES_SERVICEACCOUNT_NAME_SUFFIX:-}"
COMBINED_SUB_PATH="${KUBERNETES_SERVICEACCOUNT_COMBINED_SUB_PATH:-}"
