#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Kubernetes metadata generation library
#
# Functions:
#   validate_combined_sub_path - Validate combined sub-path format for output directory nesting
#   generate_manifest_header  - Output apiVersion, kind, metadata.name (and optionally namespace)
#   merge_key_value_pairs     - Merge two comma-separated key=value lists (second overrides first)
#   generate_yaml_map         - Output YAML map block with configurable indentation
#   generate_metadata_map     - Convenience wrapper for metadata-level maps (2-space indent)
#   generate_metadata         - Build and output labels or annotations with standard kaptain values

# Validate combined sub-path format
# Usage: validate_combined_sub_path <path>
#
# Validates that a combined sub-path (used for output directory nesting) follows rules:
#   - Only lowercase letters, digits, hyphens, and slashes allowed
#   - Must not start or end with a slash
#   - Empty path is valid (returns 0)
#
# Exit codes:
#   0 - Valid (or empty)
#   5 - Invalid characters
#   6 - Leading or trailing slash
#
validate_combined_sub_path() {
  local path="$1"

  # Empty path is valid
  if [[ -z "${path}" ]]; then
    return 0
  fi

  if [[ ! "${path}" =~ ^[a-z0-9/-]+$ ]]; then
    echo "${LOG_ERROR_PREFIX:-}Combined sub-path must contain only lowercase letters, digits, hyphens, and slashes, got: ${path}${LOG_ERROR_SUFFIX:-}" >&2
    exit 5
  fi

  if [[ "${path}" == /* || "${path}" == */ ]]; then
    echo "${LOG_ERROR_PREFIX:-}Combined sub-path must not start or end with a slash, got: ${path}${LOG_ERROR_SUFFIX:-}" >&2
    exit 6
  fi
}

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

# Build and output labels or annotations with standard kaptain values
# Usage: generate_metadata <indent> <labels|annotations> [default_container]
#
# Reads from caller's scope:
#   project_name_token  - Token for project name (e.g., ${ProjectName})
#   version_token       - Token for version (e.g., ${Version})
#   build_timestamp     - ISO 8601 timestamp (annotations only)
#   script_name         - Generator script name (annotations only)
#   global_labels       - Additional labels from global config (labels only)
#   specific_labels     - Additional labels from resource config (labels only)
#   global_annotations  - Additional annotations from global config (annotations only)
#   specific_annotations - Additional annotations from resource config (annotations only)
#
# Arguments:
#   indent            - Number of leading spaces
#   type              - "labels" or "annotations"
#   default_container - Optional container name for kubectl.kubernetes.io/default-container
#
generate_metadata() {
  if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Error: generate_metadata requires 2-3 arguments, got $#" >&2
    echo "Usage: generate_metadata <indent> <labels|annotations> [default_container]" >&2
    return 1
  fi

  local indent="$1"
  local type="$2"
  local default_container="${3:-}"

  local builtin global specific merged

  case "$type" in
    labels)
      builtin="app=${project_name_token},app.kubernetes.io/name=${project_name_token},app.kubernetes.io/version=${version_token},app.kubernetes.io/managed-by=kaptain"
      global="${global_labels:-}"
      specific="${specific_labels:-}"
      ;;
    annotations)
      builtin="kaptain/project-name=${project_name_token},kaptain/version=${version_token},kaptain/build-timestamp=\"${build_timestamp}\",kaptain/generated-by=\"Generated by Kaptain ${script_name}\""
      if [[ -n "$default_container" ]]; then
        builtin="${builtin},kubectl.kubernetes.io/default-container=${default_container}"
      fi
      global="${global_annotations:-}"
      specific="${specific_annotations:-}"
      ;;
    *)
      echo "Error: generate_metadata type must be 'labels' or 'annotations', got: $type" >&2
      return 1
      ;;
  esac

  merged=$(merge_key_value_pairs "$builtin" "$global")
  merged=$(merge_key_value_pairs "$merged" "$specific")
  generate_yaml_map "$indent" "$type" "$merged"
}

