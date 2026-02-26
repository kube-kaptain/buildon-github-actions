#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# log.bash - Build logging functions
#
# Sources the appropriate log provider based on BUILD_PLATFORM_LOG_PROVIDER
# and provides log, log_error, log_warning functions to calling scripts.
#
# Providers: github-actions, azure-devops, stdout (default)
#

BUILD_PLATFORM_LOG_PROVIDER="${BUILD_PLATFORM_LOG_PROVIDER:-stdout}"

_LOG_PROVIDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../plugins/log-providers" && pwd)"
_LOG_PROVIDER_FILE="${_LOG_PROVIDER_DIR}/log-provider-${BUILD_PLATFORM_LOG_PROVIDER}"

if [[ ! -f "${_LOG_PROVIDER_FILE}" ]]; then
  echo "Unknown log provider: ${BUILD_PLATFORM_LOG_PROVIDER} (no file ${_LOG_PROVIDER_FILE})" >&2
  exit 1
fi

# shellcheck source=src/scripts/plugins/log-providers/log-provider-stdout
source "${_LOG_PROVIDER_FILE}"
