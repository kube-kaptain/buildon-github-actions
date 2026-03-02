#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# hook-runner.bash - Common logic for running user-provided hook scripts
#
# This library is sourced by the hook entry point scripts. Each hook script
# passes its own long-form variable value as $1 (e.g., the value of
# HOOK_PRE_DOCKER_PREPARE_SCRIPT_SUB_PATH).
#
# Inputs (positional):
#   $1 - Path to user's hook script (relative to repo root)
#
# Behavior:
#   - If $1 is empty, exits 0 (skip, no hook configured)
#   - If script doesn't exist, exits 2 with error
#   - If script isn't executable, exits 3 with error
#   - Otherwise, exec's the script (replaces this process)
#
# All other environment variables pass through to the user's script unchanged.
#

script_path="${1:-}"

if [[ -z "${script_path}" ]]; then
  log "No hook script configured, skipping"
  exit 0
fi

if [[ ! -f "${script_path}" ]]; then
  log_error "Hook script not found: ${script_path}"
  exit 2
fi

if [[ ! -x "${script_path}" ]]; then
  log_error "Hook script not executable: ${script_path} (run: chmod +x ${script_path})"
  exit 3
fi

log "Running hook: ${script_path}"
exec "${script_path}"
