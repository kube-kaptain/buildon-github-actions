#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# layer-build.bash - Defaults for layer/layerset build and validation
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

LAYER_BUILD_DEFAULTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_SCHEMA_VERSION_FILE="${LAYER_BUILD_DEFAULTS_DIR}/../../schemas/version"
LAYER_PACKAGING_BASE_IMAGE="${LAYER_PACKAGING_BASE_IMAGE:-scratch}"
LAYER_TOKEN_SUBSTITUTION="${LAYER_TOKEN_SUBSTITUTION:-true}"
