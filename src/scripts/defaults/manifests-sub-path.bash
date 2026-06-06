#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# manifests-sub-path.bash - Default for source and output manifests directories
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts
# shellcheck disable=SC2154  # OUTPUT_SUB_PATH set by caller (output-sub-path.bash)
if [[ -z "${OUTPUT_SUB_PATH:-}" ]]; then
  log_error "OUTPUT_SUB_PATH is not set. Please source src/scripts/defaults/output-sub-path.bash prior to sourcing this script."
  exit 1
fi

MANIFESTS_SUB_PATH="${MANIFESTS_SUB_PATH:-src/kubernetes}"
DEFAULTS_SUB_PATH="${DEFAULTS_SUB_PATH:-src/defaults}"
ALLOW_LOCAL_DEFAULTS_OVERRIDE="${ALLOW_LOCAL_DEFAULTS_OVERRIDE:-false}"
ALLOW_LOCAL_MANIFESTS_OVERRIDE="${ALLOW_LOCAL_MANIFESTS_OVERRIDE:-false}"
MANIFESTS_COMBINED_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/combined"
MANIFESTS_CONFIG_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/config"
MANIFESTS_SUBSTITUTED_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/substituted"
MANIFESTS_ZIP_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/zip"
MANIFESTS_DEFAULTS_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/defaults"
MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/additional-defaults"
MANIFESTS_ADDITIONAL_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/additional-manifests"
