#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# manifests-sub-path.bash - Default for source and output manifests directories
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts
# shellcheck disable=SC2154  # OUTPUT_SUB_PATH set by caller (output-sub-path.bash)
if [[ -z "${OUTPUT_SUB_PATH:-}" ]]; then
  echo "ERROR: OUTPUT_SUB_PATH is not set. Please source src/scripts/defaults/output-sub-path.bash prior to sourcing this script." >&2
  exit 1
fi

MANIFESTS_SUB_PATH="${MANIFESTS_SUB_PATH:-src/kubernetes}"
MANIFESTS_COMBINED_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/combined"
MANIFESTS_CONFIG_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/config"
MANIFESTS_SUBSTITUTED_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/substituted"
MANIFESTS_ZIP_SUB_PATH="${OUTPUT_SUB_PATH}/manifests/zip"
