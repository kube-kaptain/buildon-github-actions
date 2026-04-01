#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# spec-build.bash - Defaults for spec build and validation
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

SPEC_BUILD_DEFAULTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC_JSON_SCHEMA_URL="${SPEC_JSON_SCHEMA_URL:-${SPEC_BUILD_DEFAULTS_DIR}/../../schemas/json-schema-draft-2020-12.json}"
SPEC_PACKAGING_BASE_IMAGE="${SPEC_PACKAGING_BASE_IMAGE:-scratch}"
