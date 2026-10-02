#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# check-schema-validator-calls.bash - Keep schema validation behind the plugin
#
# validate-tooling picks whichever validator the host has (jv preferred, then
# check-jsonschema, installing one on build servers) and publishes its plugin
# as SCHEMA_VALIDATION_COMMAND. A script that calls a validator directly works
# only where that one tool happens to be installed, which is a host with
# check-jsonschema locally and a failure on a runner that got jv.
#
# Flags a validator used as a command, outside the provider plugins in
# src/scripts/plugins/schema-validation-providers/ and validate-tooling itself:
# at the start of a line, or after !, if, then, do, exec, time, $(, |, &&, ||
# or ;. Comment lines are skipped, and a name in a string or a log message is
# not a command position, so neither is flagged.
#
# Usage: check-schema-validator-calls.bash [<file>...]
#   Defaults to every file under src/scripts, from the repo root.
#
# Exits 1 and prints file:line: text for every hit.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

direct_call='(^|[;&|!(]|\$\(|(^|[[:space:]])(if|then|do|exec|time))[[:space:]]*(check-jsonschema|jv)([[:space:]]|$|\))'

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  while IFS= read -r -d '' file; do
    case "${file}" in
      */plugins/schema-validation-providers/*) continue ;;
      */main/validate-tooling) continue ;;
      *.md) continue ;;
    esac
    files+=("${file}")
  done < <(find "${PROJECT_ROOT}/src/scripts" -type f -print0 | LC_ALL=C sort -z)
fi

findings=$(grep -nHE "${direct_call}" "${files[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)

if [[ -n "${findings}" ]]; then
  count=$(printf '%s\n' "${findings}" | wc -l | tr -d ' ')
  printf '%s\n' "${findings}" | sed "s|^${PROJECT_ROOT}/||" >&2
  echo "ERROR: ${count} direct schema validator call(s) outside the provider plugins" >&2
  echo "Call \"\${SCHEMA_VALIDATION_COMMAND}\" <schema> <file> instead (defaults/schema-validation.bash)." >&2
  exit 1
fi

echo "No direct schema validator calls in ${#files[@]} file(s)"
