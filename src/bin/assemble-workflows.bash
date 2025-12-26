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
DOCS_DIR="$REPO_ROOT/docs"
README="$REPO_ROOT/README.md"

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

lint_workflow_inputs() {
  echo "Linting workflow inputs for consistency..."

  local definitions_file
  definitions_file=$(mktemp)
  trap "rm -f '$definitions_file'" RETURN

  local errors=0

  for workflow in "$TEMPLATES_DIR"/*.yaml; do
    [[ -f "$workflow" ]] || continue
    local wf_basename
    wf_basename=$(basename "$workflow")

    # Get all inputs from this workflow
    local inputs
    inputs=$(yq '.on.workflow_call.inputs | keys | .[]' "$workflow" 2>/dev/null) || continue

    for input in $inputs; do
      local type default description definition
      type=$(yq ".on.workflow_call.inputs[\"$input\"].type // \"unset\"" "$workflow")
      default=$(yq ".on.workflow_call.inputs[\"$input\"].default // \"unset\"" "$workflow")
      description=$(yq ".on.workflow_call.inputs[\"$input\"].description // \"unset\"" "$workflow")
      definition="${type}|${default}|${description}"

      # Check if we've seen this input before
      local existing
      existing=$(grep "^${input}	" "$definitions_file" 2>/dev/null || true)

      if [[ -z "$existing" ]]; then
        # First time seeing this input - record it
        printf '%s\t%s\t%s\n' "$input" "$wf_basename" "$definition" >> "$definitions_file"
      else
        # Compare with previous definition
        local prev_workflow prev_definition
        prev_workflow=$(echo "$existing" | cut -f2)
        prev_definition=$(echo "$existing" | cut -f3-)

        if [[ "$prev_definition" != "$definition" ]]; then
          echo "  ERROR: Input '$input' differs between workflows" >&2
          echo "    First defined in: $prev_workflow" >&2
          echo "    Conflicts in: $wf_basename" >&2
          echo "    Expected: $prev_definition" >&2
          echo "    Got:      $definition" >&2
          errors=$((errors + 1))
        fi
      fi
    done
  done

  if [[ $errors -gt 0 ]]; then
    echo "  FAILED: $errors input inconsistency error(s) found" >&2
    exit 1
  fi

  echo "  OK: All shared inputs are consistent"
}

# Generate all inputs table for README
generate_inputs_table() {
  local inputs_file
  inputs_file=$(mktemp)

  # Collect all unique inputs across templates
  for workflow in "$TEMPLATES_DIR"/*.yaml; do
    [[ -f "$workflow" ]] || continue
    local inputs
    inputs=$(yq '.on.workflow_call.inputs | keys | .[]' "$workflow" 2>/dev/null) || continue

    for input in $inputs; do
      # Skip if already recorded
      grep -q "^${input}	" "$inputs_file" 2>/dev/null && continue

      local type default description required
      type=$(yq ".on.workflow_call.inputs[\"$input\"].type // \"string\"" "$workflow")
      default=$(yq ".on.workflow_call.inputs[\"$input\"].default" "$workflow")
      description=$(yq ".on.workflow_call.inputs[\"$input\"].description // \"\"" "$workflow")
      required=$(yq ".on.workflow_call.inputs[\"$input\"].required // false" "$workflow")

      # Format default value
      if [[ "$required" == "true" ]]; then
        default="*required*"
      elif [[ "$default" == "null" ]] || [[ -z "$default" ]]; then
        default='`""`'
      else
        default="\`$default\`"
      fi

      printf '%s\t%s\t%s\t%s\n' "$input" "$type" "$default" "$description" >> "$inputs_file"
    done
  done

  # Output table
  echo "| Input | Type | Default | Description |"
  echo "|-------|------|---------|-------------|"
  sort "$inputs_file" | while IFS=$'\t' read -r input type default description; do
    echo "| \`$input\` | $type | $default | $description |"
  done

  rm -f "$inputs_file"
}

# Generate secrets table for README
generate_secrets_table() {
  local secrets_file
  secrets_file=$(mktemp)

  # Collect all unique secrets across templates
  for workflow in "$TEMPLATES_DIR"/*.yaml; do
    [[ -f "$workflow" ]] || continue
    local secrets
    secrets=$(yq '.on.workflow_call.secrets | keys | .[]' "$workflow" 2>/dev/null) || continue

    for secret in $secrets; do
      grep -q "^${secret}	" "$secrets_file" 2>/dev/null && continue
      local description
      description=$(yq ".on.workflow_call.secrets[\"$secret\"].description // \"\"" "$workflow")
      printf '%s\t%s\n' "$secret" "$description" >> "$secrets_file"
    done
  done

  echo "| Secret | Description |"
  echo "|--------|-------------|"
  sort "$secrets_file" | while IFS=$'\t' read -r secret description; do
    echo "| \`$secret\` | $description |"
  done

  rm -f "$secrets_file"
}

# Generate workflow doc file
generate_workflow_doc() {
  local workflow="$1"
  local wf_basename
  wf_basename=$(basename "$workflow")
  local wf_name="${wf_basename%.yaml}"
  local doc_file="$DOCS_DIR/${wf_name}.md"

  local description
  description=$(yq '.name // ""' "$workflow")

  {
    echo "# ${wf_name}"
    echo ""
    echo "$description"
    echo ""
    echo "## Inputs"
    echo ""
    echo "| Input | Type | Default | Description |"
    echo "|-------|------|---------|-------------|"

    local inputs
    inputs=$(yq '.on.workflow_call.inputs | keys | .[]' "$workflow" 2>/dev/null) || true
    for input in $inputs; do
      local type default desc required
      type=$(yq ".on.workflow_call.inputs[\"$input\"].type // \"string\"" "$workflow")
      default=$(yq ".on.workflow_call.inputs[\"$input\"].default" "$workflow")
      desc=$(yq ".on.workflow_call.inputs[\"$input\"].description // \"\"" "$workflow")
      required=$(yq ".on.workflow_call.inputs[\"$input\"].required // false" "$workflow")

      if [[ "$required" == "true" ]]; then
        default="*required*"
      elif [[ "$default" == "null" ]] || [[ -z "$default" ]]; then
        default='`""`'
      else
        default="\`$default\`"
      fi
      echo "| \`$input\` | $type | $default | $desc |"
    done

    # Secrets if any
    local secrets
    secrets=$(yq '.on.workflow_call.secrets | keys | .[]' "$workflow" 2>/dev/null) || true
    if [[ -n "$secrets" ]]; then
      echo ""
      echo "## Secrets"
      echo ""
      echo "| Secret | Description |"
      echo "|--------|-------------|"
      for secret in $secrets; do
        local desc
        desc=$(yq ".on.workflow_call.secrets[\"$secret\"].description // \"\"" "$workflow")
        echo "| \`$secret\` | $desc |"
      done
    fi

    # Outputs if any
    local outputs
    outputs=$(yq '.on.workflow_call.outputs | keys | .[]' "$workflow" 2>/dev/null) || true
    if [[ -n "$outputs" ]]; then
      echo ""
      echo "## Outputs"
      echo ""
      echo "| Output | Description |"
      echo "|--------|-------------|"
      for output in $outputs; do
        local desc
        desc=$(yq ".on.workflow_call.outputs[\"$output\"].description // \"\"" "$workflow")
        echo "| \`$output\` | $desc |"
      done
    fi
  } > "$doc_file"

  echo "  Generated: $doc_file"
}

# Generate workflow links table for README
generate_workflow_links_table() {
  echo "| Workflow | Description | Documentation |"
  echo "|----------|-------------|---------------|"

  for workflow in "$TEMPLATES_DIR"/*.yaml; do
    [[ -f "$workflow" ]] || continue
    local wf_basename wf_name description
    wf_basename=$(basename "$workflow")
    wf_name="${wf_basename%.yaml}"
    description=$(yq '.name // ""' "$workflow")
    echo "| \`$wf_basename\` | $description | [docs/${wf_name}.md](docs/${wf_name}.md) |"
  done
}

# Inject content between markers in a file
inject_between_markers() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local content="$4"

  local temp_file
  temp_file=$(mktemp)

  local in_section=false
  local injected=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == *"$start_marker"* ]]; then
      echo "$line" >> "$temp_file"
      echo "$content" >> "$temp_file"
      in_section=true
      injected=true
    elif [[ "$line" == *"$end_marker"* ]]; then
      echo "$line" >> "$temp_file"
      in_section=false
    elif [[ "$in_section" == false ]]; then
      echo "$line" >> "$temp_file"
    fi
  done < "$file"

  if [[ "$injected" == true ]]; then
    mv "$temp_file" "$file"
  else
    rm -f "$temp_file"
    echo "  WARNING: Markers not found: $start_marker" >&2
  fi
}

# Generate all documentation
generate_docs() {
  echo "Generating documentation..."

  # Clean docs directory for predictable results
  if [[ -d "$DOCS_DIR" ]]; then
    rm "$DOCS_DIR"/*
    echo "  Cleaned docs directory"
  fi

  # Create docs directory
  mkdir -p "$DOCS_DIR"

  # Generate individual workflow docs
  for workflow in "$TEMPLATES_DIR"/*.yaml; do
    [[ -f "$workflow" ]] || continue
    generate_workflow_doc "$workflow"
  done

  # Generate and inject inputs table
  local inputs_table
  inputs_table=$(generate_inputs_table)
  inject_between_markers "$README" "<!-- INPUTS-START -->" "<!-- INPUTS-END -->" "$inputs_table"
  echo "  Injected: inputs table"

  # Generate and inject secrets table
  local secrets_table
  secrets_table=$(generate_secrets_table)
  inject_between_markers "$README" "<!-- SECRETS-START -->" "<!-- SECRETS-END -->" "$secrets_table"
  echo "  Injected: secrets table"

  # Generate and inject workflow links table
  local links_table
  links_table=$(generate_workflow_links_table)
  inject_between_markers "$README" "<!-- WORKFLOW-DOCS-START -->" "<!-- WORKFLOW-DOCS-END -->" "$links_table"
  echo "  Injected: workflow links table"
}

main() {
  echo "Assembling workflows..."
  echo "  Templates: $TEMPLATES_DIR"
  echo "  Steps: $STEPS_DIR"
  echo "  Output: $OUTPUT_DIR"
  echo

  # Lint templates for input consistency before assembly
  lint_workflow_inputs
  echo

  # Clean output directory for predictable results
  if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Cleaning output directory..."
    rm "$OUTPUT_DIR"/*
    git checkout "$OUTPUT_DIR/build.yaml"
    echo "  Removed existing files from $OUTPUT_DIR (restored build.yaml)"
    echo
  fi

  # Ensure output directory exists
  mkdir -p "$OUTPUT_DIR"

  # Process all templates
  local count=0
  for template in "$TEMPLATES_DIR"/*.yaml; do
    if [[ -f "$template" ]]; then
      process_template "$template"
      count=$((count + 1))
      echo
    fi
  done

  echo "Processed $count template(s)."
  echo

  # Generate documentation
  generate_docs

  echo
  echo "Done."
}

main "$@"
