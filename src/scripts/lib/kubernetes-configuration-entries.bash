#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Kubernetes configuration entries library
#
# Functions for validating and working with configuration entry directories
# (files that become data/stringData entries in ConfigMap/Secret resources)
#
# Functions:
#   validate_configuration_entries_directory - Check directory exists and has files
#   generate_configuration_entries           - Output YAML data entries from files

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
