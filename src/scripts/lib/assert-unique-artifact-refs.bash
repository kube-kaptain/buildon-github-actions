#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# assert-unique-artifact-refs.bash - Reject duplicate artifact refs in a
# YAML list before any fetch/extract work runs.
#
# Sourced by callers that read a list of OCI artifact references out of a
# spec field (spec.layers, spec.contents, future spec.templates,
# environment-build inputs, ...) and need to fail fast if the same artifact
# appears more than once.
#
# "Same artifact" reduces each entry to a comparable identity by stripping:
#   - leading 'provider|' prefix (always)
#   - trailing ':tag' (always; the tag pattern excludes '/' so it does not
#     eat host:port qualifiers like 'localhost:5000/foo')
#   - registry/namespace/path qualification (only in 'name' mode)
#
# Two modes:
#   name - last URL segment only. Use when downstream collisions are keyed
#          on the bundle/project's metadata.name regardless of where it
#          came from (product spec.contents, environment build, etc.).
#   path - keep registry/namespace/path. Use when the system intentionally
#          tolerates same-name artifacts at different qualification levels
#          (current layer-validate behaviour). Acknowledges the gap that
#          'name:1.0' vs 'group/name:1.0' are not collapsed without running
#          each ref through registry/namespace inference.
#
# Required tools: yq, sed, sort, uniq
#
# Required functions in scope: log_error (from log.bash)

# assert_unique_artifact_refs <yaml-file> <yq-expression> <context-label> <mode>
#
# Reads <yq-expression> from <yaml-file> (e.g. '.spec.layers[]'), reduces
# each entry to its identity per <mode> ('name' or 'path'), and returns 1
# with a diagnostic listing the duplicates if any reduced identity appears
# more than once. Returns 0 on no duplicates or empty list.
assert_unique_artifact_refs() {
  if [[ $# -ne 4 ]]; then
    log_error "assert_unique_artifact_refs requires exactly 4 arguments, got $#"
    return 1
  fi
  local yaml_file="$1"
  local yq_expression="$2"
  local context_label="$3"
  local mode="$4"

  if [[ ! -f "${yaml_file}" ]]; then
    log_error "assert_unique_artifact_refs: file not found: ${yaml_file}"
    return 1
  fi

  local sed_program
  case "${mode}" in
    name) sed_program='s/^[^|]*\|//; s/:[^:/]+$//; s|^.*/||' ;;
    path) sed_program='s/^[^|]*\|//; s/:[^:/]+$//' ;;
    *)
      log_error "assert_unique_artifact_refs: unknown mode '${mode}' (expected 'name' or 'path')"
      return 1
      ;;
  esac

  local entries
  entries=$(yq eval "${yq_expression}" "${yaml_file}" 2>/dev/null || true)
  if [[ -z "${entries}" || "${entries}" == "null" ]]; then
    return 0
  fi

  local duplicates
  duplicates=$(printf '%s\n' "${entries}" \
    | sed -E "${sed_program}" \
    | sort | uniq -d)

  if [[ -z "${duplicates}" ]]; then
    return 0
  fi

  log_error "${context_label} contains duplicate artifact references (ignoring provider prefix and version$([[ "${mode}" == "name" ]] && echo " and registry/path qualification")):"
  local dup
  while IFS= read -r dup; do
    [[ -z "${dup}" ]] && continue
    log_error "  ${dup}"
  done <<< "${duplicates}"
  return 1
}
