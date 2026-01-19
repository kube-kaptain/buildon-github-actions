#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-pod-placement.bash - Library functions for pod placement configuration
#
# Handles tolerations, node selectors, and related pod scheduling concerns.
#

# generate_tolerations - Convert JSON tolerations to YAML and output with indentation
#
# Arguments:
#   $1 - indent_count: Number of spaces for indentation
#   $2 - tolerations_json: JSON array of tolerations (empty string = no output)
#
# Example:
#   generate_tolerations 6 '[{"operator":"Exists"}]'
# Output:
#       tolerations:
#       - operator: Exists
#
generate_tolerations() {
  local indent_count="$1"
  local tolerations_json="$2"

  [[ -z "${tolerations_json}" ]] && return 0

  local indent=""
  for ((i = 0; i < indent_count; i++)); do
    indent+=" "
  done

  echo "${indent}tolerations:"
  echo "${tolerations_json}" | yq -P '.' | while IFS= read -r line; do
    echo "${indent}${line}"
  done
}
