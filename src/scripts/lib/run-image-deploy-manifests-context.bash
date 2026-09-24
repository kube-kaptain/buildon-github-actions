#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# run-image-deploy-manifests-context.bash - Pins the stock manifest pipeline
# at the deploy-manifests block's dirs.
#
# Sourced by the kubernetes-run-image-deploy-manifests-* wrappers, so each stage
# stays a visible CI step while the overrides die with its process.
#
# All derived dirs (defaults/manifests-sub-path.bash, contract-generate) hang
# off OUTPUT_SUB_PATH, so swapping that value relocates them together. Only
# load-final-kaptainpm-yaml publishes config vars as step outputs, so the swap
# cannot escape.
#
# Requires: defaults/output-sub-path.bash and defaults/environments.bash
# sourced first.
# shellcheck disable=SC2154 # provided by the defaults files

# Must precede the swap: the layout derives from the real output dir.
# shellcheck source=src/scripts/lib/run-image-deploy-manifests-paths.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-image-deploy-manifests-paths.bash"

export MANIFESTS_SUB_PATH="${RUN_IMAGE_DEPLOY_MANIFESTS_INPUT}"
export DEFAULTS_SUB_PATH="${RUN_IMAGE_DEPLOY_MANIFESTS_DEFAULTS}"
export CONFIG_SUB_PATH="${ENV_ENVIRONMENT_DEPLOY_SOURCE_BASE_PATH}/config"
export OUTPUT_SUB_PATH="${RUN_IMAGE_DEPLOY_MANIFESTS_PIPELINE}"
