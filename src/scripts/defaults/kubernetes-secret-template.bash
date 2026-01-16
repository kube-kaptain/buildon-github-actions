#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-secret-template.bash - Default values for Kubernetes Secret template generation
#
# Source this file to get consistent defaults for Secret template-related variables.
#
# Variables are set with defaults only if not already set, so callers can
# override by setting values before sourcing this file.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Naming and paths
NAME_SUFFIX="${KUBERNETES_SECRET_TEMPLATE_NAME_SUFFIX:-}"
COMBINED_SUB_PATH="${KUBERNETES_SECRET_TEMPLATE_COMBINED_SUB_PATH:-}"
BASE_SUB_PATH="${KUBERNETES_SECRET_TEMPLATE_SUB_PATH:-src/secret.template}"

# Checksum injection
NAME_CHECKSUM_INJECTION="${KUBERNETES_SECRET_TEMPLATE_NAME_CHECKSUM_INJECTION:-true}"
