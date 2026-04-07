#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# validate-layer-payload.bash - Validate a KaptainPM layer's layer-payload
# declarations against a filesystem root that represents the image contents.
#
# The same validation runs at build time (filesystem root = substituted docker
# context directory) and at consumption time (filesystem root = directory the
# layer image was extracted into). In both cases, paths declared in the
# manifest's layer-payload entries must correspond to real files under the
# given filesystem root.
#
# Currently enforces:
#   - every layer-payload entry has a non-empty source
#   - every source exists as a file under <fs-root>${source}
#   - every layer-payload entry has a non-empty destination
#   - destinations are relative (no leading '/')
#   - destinations contain no '..' path component (leading './' is allowed)
#
# Requires: yq, a log/log_error pair already sourced by the caller.

# Validate the layer-payload declarations in a KaptainPM manifest against a
# filesystem root.
#
# Usage: validate_layer_payload <yaml-manifest-file> <fs-root-dir>
#
# Returns:
#   0 on success
#   non-zero if any entry fails validation (caller decides how to react)
validate_layer_payload() {
  local yaml_file="${1}"
  local fs_root="${2}"

  local payload_count
  payload_count=$(yq eval '.["layer-payload"] // [] | length' "${yaml_file}")
  if [[ "${payload_count}" -eq 0 ]]; then
    return 0
  fi

  log "Validating ${payload_count} layer-payload entry/entries..."

  local i source_path check_path dest_path
  for ((i = 0; i < payload_count; i++)); do
    source_path=$(yq eval ".[\"layer-payload\"][${i}].source" "${yaml_file}")
    if [[ -z "${source_path}" || "${source_path}" == "null" ]]; then
      log_error "layer-payload[${i}] has no source path"
      return 1
    fi
    # Strip leading / for filesystem check (sources are image-absolute, and
    # ${fs_root} is the in-memory/on-disk image root for this caller).
    check_path="${fs_root}/${source_path#/}"
    if [[ ! -f "${check_path}" ]]; then
      log_error "layer-payload[${i}] source not found under ${fs_root}: ${source_path}"
      return 1
    fi

    # Destination path must be relative to consumer's repo root and contain
    # no parent-traversal, so a layer cannot write outside the repo at
    # install time.
    dest_path=$(yq eval ".[\"layer-payload\"][${i}].destination" "${yaml_file}")
    if [[ -z "${dest_path}" || "${dest_path}" == "null" ]]; then
      log_error "layer-payload[${i}] has no destination path"
      return 1
    fi
    # Reject absolute paths.
    if [[ "${dest_path}" == '/'* ]]; then
      log_error "layer-payload[${i}] destination must be relative (no leading '/'): ${dest_path}"
      return 1
    fi
    # Reject any '..' component. Matches bare '..', leading '../x', middle
    # 'x/../y', and trailing 'x/..'. Leading './' is allowed and untouched.
    if [[ "${dest_path}" =~ (^|/)'..'($|/) ]]; then
      log_error "layer-payload[${i}] destination contains parent-traversal '..': ${dest_path}"
      return 1
    fi

    log "  payload ok: ${source_path} -> ${dest_path}"
  done
}
