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
# shellcheck disable=SC2154 # BUILD_PLATFORM_LOG_PROVIDER set by platform.bash before sourcing

LOG_PROVIDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../plugins/log-providers" && pwd)"
LOG_PROVIDER_FILE="${LOG_PROVIDER_DIR}/log-provider-${BUILD_PLATFORM_LOG_PROVIDER}"

if [[ ! -f "${LOG_PROVIDER_FILE}" ]]; then
  echo "Unknown log provider: ${BUILD_PLATFORM_LOG_PROVIDER} (no file ${LOG_PROVIDER_FILE})" >&2
  exit 1
fi

# shellcheck source=src/scripts/plugins/log-providers/log-provider-stdout
source "${LOG_PROVIDER_FILE}"
