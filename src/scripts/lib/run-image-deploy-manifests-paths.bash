#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# run-image-deploy-manifests-paths.bash - Layout of the deploy-manifests
# block's directories.
#
# Exports and overrides nothing, so scripts running against the real output
# dir can source it. Pinning lives in run-image-deploy-manifests-context.bash.
#
# Pipeline output is a sibling of the input tree; nested, its combined/ and
# substituted/ dirs would land where package-prepare scans for sources.
#
# Requires: defaults/output-sub-path.bash sourced first.
# shellcheck disable=SC2034  # consumed by sourcing scripts
# shellcheck disable=SC2154  # OUTPUT_SUB_PATH provided by the defaults file

if [[ -z "${OUTPUT_SUB_PATH:-}" ]]; then
  log_error "OUTPUT_SUB_PATH is not set. Source defaults/output-sub-path.bash before run-image-deploy-manifests-paths.bash."
  # shellcheck disable=SC2317 # dual-mode: works whether sourced or executed
  return 1 2>/dev/null || exit 1
fi

RUN_IMAGE_DEPLOY_MANIFESTS_BASE="${OUTPUT_SUB_PATH}/run-image-deploy-manifests"
RUN_IMAGE_DEPLOY_MANIFESTS_INPUT="${RUN_IMAGE_DEPLOY_MANIFESTS_BASE}/manifests"
RUN_IMAGE_DEPLOY_MANIFESTS_DEFAULTS="${RUN_IMAGE_DEPLOY_MANIFESTS_BASE}/defaults"
RUN_IMAGE_DEPLOY_MANIFESTS_PIPELINE="${RUN_IMAGE_DEPLOY_MANIFESTS_BASE}/pipeline"

# The finished set. The aggregate reads it from the real output dir, so it
# cannot derive this from OUTPUT_SUB_PATH.
RUN_IMAGE_DEPLOY_MANIFESTS_SUBSTITUTED="${RUN_IMAGE_DEPLOY_MANIFESTS_PIPELINE}/manifests/substituted"
RUN_IMAGE_DEPLOY_MANIFESTS_CONTRACT="${RUN_IMAGE_DEPLOY_MANIFESTS_PIPELINE}/manifests/contract"
