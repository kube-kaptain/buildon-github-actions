#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)

# assemble-workflows.bash - Generate workflow files from templates
#
# Reads templates from src/workflow-templates/ and replaces INJECT markers
# with content from src/steps-common/, writing results to .github/workflows/
#
# Chunks are written with 0-based indentation and the generator applies
# the correct indentation based on the INJECT marker's position.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEMPLATES_DIR="$REPO_ROOT/src/workflow-templates"
STEPS_DIR="$REPO_ROOT/src/steps-common"
OUTPUT_DIR="$REPO_ROOT/.github/workflows"

# Indent all lines of input by given prefix
indent_chunk() {
  local indent="$1"
  local first=true
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$first" == true ]]; then
      # First line: just output without extra indent (marker position provides it)
      echo "$line"
      first=false
    else
      # Subsequent lines: add indent prefix if line is non-empty
      if [[ -n "$line" ]]; then
        echo "${indent}${line}"
      else
        echo ""
      fi
    fi
  done
}

# Process a single template file
process_template() {
  local template="$1"
  local basename
  basename=$(basename "$template")
  local output="$OUTPUT_DIR/$basename"

  echo "Processing: $basename"

  local workflow_name="${basename%.yaml}"
  local result=""

  # Process line by line to handle INJECT markers with proper indentation
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([[:space:]]*)#\ INJECT:\ ([a-zA-Z0-9_-]+)$ ]]; then
      local indent="${BASH_REMATCH[1]}"
      local chunk_name="${BASH_REMATCH[2]}"
      local chunk_file="$STEPS_DIR/${chunk_name}.yaml"

      if [[ ! -f "$chunk_file" ]]; then
        echo "  ERROR: Chunk not found: $chunk_file" >&2
        exit 1
      fi

      # Read chunk, replace placeholders, and apply indentation
      local chunk
      chunk=$(cat "$chunk_file")
      chunk="${chunk//\$\{WORKFLOW_NAME\}/$workflow_name}"

      # Apply indentation to chunk (first line gets indent, others get indent prepended)
      local indented_chunk
      indented_chunk=$(echo "$chunk" | indent_chunk "$indent")

      result+="${indent}${indented_chunk}"
      echo "  Injected: $chunk_name (indent: ${#indent} spaces)"
    else
      result+="$line"
    fi
    result+=$'\n'
  done < "$template"

  # Write output (remove trailing newline duplication)
  printf '%s' "$result" > "$output"
  echo "  Written: $output"
}

main() {
  echo "Assembling workflows..."
  echo "  Templates: $TEMPLATES_DIR"
  echo "  Steps: $STEPS_DIR"
  echo "  Output: $OUTPUT_DIR"
  echo

  # Ensure output directory exists
  mkdir -p "$OUTPUT_DIR"

  # Process all templates
  local count=0
  for template in "$TEMPLATES_DIR"/*.yaml; do
    if [[ -f "$template" ]]; then
      process_template "$template"
      ((count++))
      echo
    fi
  done

  echo "Done. Processed $count template(s)."
}

main "$@"
