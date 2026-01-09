#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Kubernetes metadata generation library
#
# Functions:
#   generate_manifest_header  - Output apiVersion, kind, metadata.name (and optionally namespace)
#   merge_key_value_pairs     - Merge two comma-separated key=value lists (second overrides first)
#   generate_yaml_map         - Output YAML map block with configurable indentation
#   generate_metadata_map     - Convenience wrapper for metadata-level maps (2-space indent)

# Generate manifest header (apiVersion, kind, metadata.name, optionally namespace)
# Usage: generate_manifest_header <apiVersion> <kind> <name> [namespace]
#   3 args: cluster-scoped resource (no namespace)
#   4 args: namespaced resource
generate_manifest_header() {
  if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo "Error: generate_manifest_header requires 3 or 4 arguments" >&2
    echo "Usage: generate_manifest_header <apiVersion> <kind> <name> [namespace]" >&2
    return 1
  fi

  local api_version="$1"
  local kind="$2"
  local name="$3"

  echo "apiVersion: ${api_version}"
  echo "kind: ${kind}"
  echo "metadata:"
  echo "  name: ${name}"

  if [[ $# -eq 4 ]]; then
    local namespace="$4"
    echo "  namespace: ${namespace}"
  fi
}

# Merge two comma-separated key=value lists (second overrides first)
# Usage: merge_key_value_pairs <base> <override>
# Output: merged comma-separated key=value string
merge_key_value_pairs() {
  local base="$1"
  local override="$2"

  # Handle empty inputs
  if [[ -z "$base" && -z "$override" ]]; then
    echo ""
    return 0
  fi
  if [[ -z "$base" ]]; then
    echo "$override"
    return 0
  fi
  if [[ -z "$override" ]]; then
    echo "$base"
    return 0
  fi

  # Build associative-style merge using arrays (bash 3.2 compatible)
  # Parse base into parallel arrays
  local -a keys=()
  local -a values=()

  local IFS=','
  local pair key value i

  # Parse base pairs
  for pair in $base; do
    key="${pair%%=*}"
    value="${pair#*=}"
    keys+=("$key")
    values+=("$value")
  done

  # Parse override pairs, replacing or adding
  for pair in $override; do
    key="${pair%%=*}"
    value="${pair#*=}"

    # Check if key exists in base
    local found=false
    for i in "${!keys[@]}"; do
      if [[ "${keys[$i]}" == "$key" ]]; then
        values[$i]="$value"
        found=true
        break
      fi
    done

    # Add new key if not found
    if [[ "$found" == "false" ]]; then
      keys+=("$key")
      values+=("$value")
    fi
  done

  # Rebuild output
  local result=""
  for i in "${!keys[@]}"; do
    if [[ -n "$result" ]]; then
      result="${result},"
    fi
    result="${result}${keys[$i]}=${values[$i]}"
  done

  echo "$result"
}

# Generate YAML map block with configurable indentation
# Usage: generate_yaml_map <indent_spaces> <field_name> <key=value,key=value,...>
# indent_spaces: number of leading spaces (e.g., 2 for metadata-level)
# Output: YAML block to stdout
generate_yaml_map() {
  local indent_spaces="$1"
  local field_name="$2"
  local pairs="$3"

  # Empty pairs = no output
  if [[ -z "$pairs" ]]; then
    return 0
  fi

  # Generate leading spaces
  local leading_spaces=""
  local i
  for ((i = 0; i < indent_spaces; i++)); do
    leading_spaces="${leading_spaces} "
  done

  echo "${leading_spaces}${field_name}:"

  local IFS=','
  local pair key value
  local entry_indent="${leading_spaces}  "

  for pair in $pairs; do
    key="${pair%%=*}"
    value="${pair#*=}"
    echo "${entry_indent}${key}: ${value}"
  done
}

# Convenience wrapper for metadata-level maps (2-space indent)
# Usage: generate_metadata_map <field_name> <key=value,key=value,...>
generate_metadata_map() {
  local field_name="$1"
  local pairs="$2"

  generate_yaml_map 2 "$field_name" "$pairs"
}

