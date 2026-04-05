#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# layer-merge.bash - Layer merge operations for KaptainPM
#
# Sourced by scripts that need layer processing: strip payload, deep merge,
# interpolation step recording, and layer type validation.
#
# Requires: yq

# Strip the layer-payload top-level field from a KaptainPM.yaml file.
# layer-payload is image packaging metadata, not build configuration.
#
# Usage: layer_strip_payload <input-file> <output-file>
layer_strip_payload() {
  local input="${1}"
  local output="${2}"
  yq eval 'del(.["layer-payload"])' "${input}" > "${output}"
}

# Deep merge two YAML files: overlay on top of base.
# Scalars: overlay wins. Maps: recursive merge. Lists: overlay replaces entirely.
#
# Usage: layer_deep_merge <base-file> <overlay-file> <output-file>
layer_deep_merge() {
  local base="${1}"
  local overlay="${2}"
  local output="${3}"
  yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "${base}" "${overlay}" > "${output}"
}

# Record an interpolation step as a numbered file for debugging and auditing.
# Files are named NN-label.yaml (zero-padded step number).
#
# Usage: layer_record_step <step-number> <label> <source-file> <interpolation-dir>
layer_record_step() {
  local step="${1}"
  local label="${2}"
  local source_file="${3}"
  local interpolation_dir="${4}"
  local padded
  padded=$(printf "%02d" "${step}")
  mkdir -p "${interpolation_dir}"
  cp "${source_file}" "${interpolation_dir}/${padded}-${label}.yaml"
}

# Validate that a layer is either a config layer or a composite layer, never both.
# A layer with spec.layers cannot have any other spec.* content.
# kind and apiVersion alongside spec.layers are fine.
#
# Usage: layer_validate_type <layer-file>
# Returns 0 if valid, 1 with error on stderr if invalid.
layer_validate_type() {
  local layer_file="${1}"

  local has_layers
  has_layers=$(yq eval '.spec.layers // "" | length' "${layer_file}")

  if [[ "${has_layers}" == "0" ]]; then
    # No spec.layers — config layer, always valid
    return 0
  fi

  # Has spec.layers — check for other spec.* content
  local spec_keys
  spec_keys=$(yq eval '.spec | keys | .[]' "${layer_file}" 2>/dev/null)

  local other_keys=""
  while IFS= read -r key; do
    [[ -z "${key}" ]] && continue
    if [[ "${key}" != "layers" ]]; then
      other_keys="${other_keys} ${key}"
    fi
  done <<< "${spec_keys}"

  if [[ -n "${other_keys}" ]]; then
    log_error "Invalid layer: has spec.layers (composite) but also has other spec content:${other_keys}"
    return 1
  fi

  return 0
}
