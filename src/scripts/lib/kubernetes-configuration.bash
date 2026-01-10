#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Kubernetes configuration library
#
# Functions for building source paths, validating directories, and generating
# configuration entries for ConfigMap/Secret/deployment-env resources.
#
# Functions:
#   build_configuration_source_path      - Build source path with suffix support
#   validate_configuration_entries_directory - Check directory exists and has files
#   generate_configuration_entries       - Output YAML data entries from files

# Build a configuration source path with consistent suffix handling
# Usage: build_configuration_source_path <base_path> <suffix> <static_suffix>
#
# If base_path already ends with static_suffix, strips it first, inserts name suffix,
# then re-adds static_suffix. If not, appends name suffix then static_suffix.
# This ensures consistent behavior whether the base path is default or overridden.
#
# Arguments:
#   base_path     - Base directory path (e.g., "src/secret.template", "custom/path")
#   suffix        - Optional name suffix (e.g., "nginx", "db")
#   static_suffix - Static suffix always at the end (e.g., "", ".template", "-env")
#
# Examples:
#   build_configuration_source_path "src/configmap" "" ""                    → src/configmap
#   build_configuration_source_path "src/configmap" "nginx" ""               → src/configmap-nginx
#   build_configuration_source_path "src/secret.template" "" ".template"     → src/secret.template
#   build_configuration_source_path "src/secret.template" "db" ".template"   → src/secret-db.template
#   build_configuration_source_path "custom/path" "db" ".template"           → custom/path-db.template
#   build_configuration_source_path "custom/path.template" "db" ".template"  → custom/path-db.template
#   build_configuration_source_path "src/deployment-env" "worker" "-env"     → src/deployment-worker-env
#   build_configuration_source_path "custom/path" "worker" "-env"            → custom/path-worker-env
#
build_configuration_source_path() {
  local base_path="$1"
  local suffix="$2"
  local static_suffix="$3"

  local core_path="$base_path"

  # If static_suffix is non-empty and base_path ends with it, strip it
  if [[ -n "${static_suffix}" && "${base_path}" == *"${static_suffix}" ]]; then
    core_path="${base_path%"${static_suffix}"}"
  fi

  # Build the result: core + optional name suffix + static suffix
  if [[ -n "${suffix}" ]]; then
    echo "${core_path}-${suffix}${static_suffix}"
  else
    echo "${core_path}${static_suffix}"
  fi
}

# Validate a configuration entries directory
# Usage: validate_configuration_entries_directory <directory> <resource_type_label>
#
# Behavior:
#   - Directory doesn't exist: prints skip message to stderr, exits 0 (not an error)
#   - Directory exists but empty (excluding dotfiles): prints error, exits 7
#   - Directory valid with files: sets SOURCE_FILE_COUNT, returns 0
#
# Arguments:
#   directory          - Path to the configuration entries directory
#   resource_type_label - Human-readable label for messages (e.g., "ConfigMap", "Secret template")
#
# Outputs:
#   SOURCE_FILE_COUNT  - Number of files found (set on success)
#
# Exit codes:
#   0 - Success (directory valid) or skip (directory not found)
#   7 - Directory exists but contains no files
#
validate_configuration_entries_directory() {
  local directory="$1"
  local resource_type_label="$2"

  # Check if source directory exists
  if [[ ! -d "${directory}" ]]; then
    echo "${resource_type_label} source directory '${directory}' not found, skipping ${resource_type_label} generation" >&2
    exit 0
  fi

  # Check if directory has files (excluding dotfiles)
  SOURCE_FILE_COUNT=$(find "${directory}" -type f -not -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${SOURCE_FILE_COUNT}" -eq 0 ]]; then
    echo "${LOG_ERROR_PREFIX:-}No files found (excluding dotfiles) in ${resource_type_label} source directory '${directory}'${LOG_ERROR_SUFFIX:-}" >&2
    exit 7
  fi
}

# Generate YAML data entries from files in a directory
# Usage: generate_configuration_entries <directory>
#
# Outputs YAML entries suitable for ConfigMap data: or Secret stringData: sections.
# Each file becomes a key-value entry (filename → content as block scalar).
#
# Arguments:
#   directory - Path to the configuration entries directory
#
# Output format (to stdout):
#   filename1: |
#     content line 1
#     content line 2
#   filename2: |
#     content line 1
#
# Notes:
#   - Files are sorted alphabetically for deterministic output
#   - Dotfiles are excluded
#   - Content is indented with 4 spaces (2 for key indent + 2 for block scalar content)
#   - Each line of file content is output, preserving internal structure
#
generate_configuration_entries() {
  local directory="$1"

  while IFS= read -r -d '' filepath; do
    local filename
    filename=$(basename "${filepath}")
    # Use block scalar for content to preserve formatting
    echo "  ${filename}: |"
    # Indent each line of content by 4 spaces
    while IFS= read -r line || [[ -n "${line}" ]]; do
      echo "    ${line}"
    done < "${filepath}"
  done < <(find "${directory}" -type f -not -name '.*' -print0 | sort -z)
}
