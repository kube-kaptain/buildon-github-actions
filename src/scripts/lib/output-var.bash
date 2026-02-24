#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# output-var - Output variable helper for CI systems
#
# Provides output_var() which echoes name=value to stdout,
# writes to GITHUB_OUTPUT if available, and exports for
# downstream scripts in the same shell context.
#

output_var() {
  local name="${1}"
  local value="${2}"

  echo "${name}=${value}"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "${name}=${value}" >> "${GITHUB_OUTPUT}"
  fi

  export "${name}"="${value}"
}
