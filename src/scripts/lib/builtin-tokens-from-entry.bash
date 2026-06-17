#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# builtin-tokens-from-entry.bash - Per-entry auto-builtin token emitter.
#
# Emits three canonical-named token files for every spec.contents,
# spec.templates, and spec.layers entry, so downstream substitution can
# reference the version, version spec, and full reference of any child of
# the current project.
#
# Owns the on-disk parent location: ${OUTPUT_SUB_PATH}/builtin-resolved-tokens.
# Callers pass the subdir name (e.g. "contents", "templates", "layers"); the
# emitter constructs the full path. The consumer (util/prepare-substitution-tokens)
# knows the same parent layout.
#
# Files on disk are always written in UPPER_SNAKE form. The downstream
# prepare-substitution-tokens utility converts each name to the consumer's
# TOKEN_NAME_STYLE when copying into the substitution tokens dir.
#
# Files per entry, under ${OUTPUT_SUB_PATH}/builtin-resolved-tokens/<subdir>/:
#   ${PREFIX}_${SLUG}_REF           - entry as written, verbatim
#   ${PREFIX}_${SLUG}_VERSION_SPEC  - version part as written (e.g. "[1.2.3]")
#   ${PREFIX}_${SLUG}_VERSION       - resolved single version (e.g. "1.2.3")
#
# The token-name prefix is derived from the subdir by stripping one trailing
# 's' and upper-casing, so callers only pass the subdir:
#   contents  -> CONTENT
#   templates -> TEMPLATE
#   layers    -> LAYER (covers both layers and layersets; their project names
#                      already encode the distinction, e.g. layer-foo vs
#                      layerset-foo, so they cannot collide).
#
# SLUG derivation from entry-as-written:
#   1. Strip optional provider prefix "<x>|" (e.g. "docker|app:1.0").
#   2. Strip trailing version spec: everything from the first ':' onward.
#   3. Replace '/' with '.'.
#   4. Split on '.'.
#   5. Convert each segment via convert_kebab_name UPPER_SNAKE.
#   6. Join segments with '_'.
#
# Examples:
#   ghcr.io/org/branchoutgroup/app-foo:1.2.3
#     -> SLUG=GHCR_IO_ORG_BRANCHOUTGROUP_APP_FOO
#     -> CONTENT_GHCR_IO_ORG_BRANCHOUTGROUP_APP_FOO_{REF,VERSION_SPEC,VERSION}
#
#   docker|app-foo:[1.2.3]
#     -> SLUG=APP_FOO
#     -> CONTENT_APP_FOO_{REF,VERSION_SPEC,VERSION}
#
# Requires:
#   log_error from lib/log.bash (sourced by caller before this file)
#   convert_kebab_name from lib/token-format.bash (sourced by this file)

# shellcheck source=src/scripts/lib/token-format.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/token-format.bash"

# Emit the three builtin token files for a single entry.
#
# Usage: emit_builtin_tokens_for_entry <entry> <resolved-version> <subdir>
# Requires: OUTPUT_SUB_PATH set in the environment.
emit_builtin_tokens_for_entry() {
  if [[ $# -ne 3 ]]; then
    log_error "emit_builtin_tokens_for_entry requires exactly 3 arguments, got $#"
    return 1
  fi

  local entry="$1"
  local resolved_version="$2"
  local subdir="$3"

  if [[ -z "${entry}" ]]; then
    log_error "emit_builtin_tokens_for_entry: entry is required"
    return 1
  fi
  if [[ -z "${subdir}" ]]; then
    log_error "emit_builtin_tokens_for_entry: subdir is required"
    return 1
  fi
  if [[ -z "${OUTPUT_SUB_PATH:-}" ]]; then
    log_error "emit_builtin_tokens_for_entry: OUTPUT_SUB_PATH is required"
    return 1
  fi

  # Prefix: drop trailing 's' from subdir, uppercase. e.g. layers -> LAYER.
  local prefix
  prefix=$(printf '%s' "${subdir%s}" | tr '[:lower:]' '[:upper:]')

  local out_dir="${OUTPUT_SUB_PATH}/builtin-resolved-tokens/${subdir}"

  # Strip optional provider prefix "<x>|" (no-op when '|' is absent).
  local ref="${entry#*|}"

  # Version spec is whatever follows the first ':' (empty if no ':').
  local version_spec=""
  if [[ "${ref}" == *:* ]]; then
    version_spec="${ref#*:}"
  fi

  # URI without trailing version spec.
  local uri_without_version="${ref%%:*}"

  if [[ -z "${uri_without_version}" ]]; then
    log_error "emit_builtin_tokens_for_entry: entry has no path component before version: '${entry}'"
    return 1
  fi

  # Normalise / to . then split on . for slug segments.
  local seg_input="${uri_without_version//\//.}"
  local slug=""
  local segment converted
  local IFS_BACKUP="${IFS}"
  IFS='.'
  # shellcheck disable=SC2086 # intentional word-split on '.'
  set -- ${seg_input}
  IFS="${IFS_BACKUP}"
  for segment in "$@"; do
    [[ -z "${segment}" ]] && continue
    converted=$(convert_kebab_name UPPER_SNAKE "${segment}") || return 1
    if [[ -z "${slug}" ]]; then
      slug="${converted}"
    else
      slug="${slug}_${converted}"
    fi
  done

  if [[ -z "${slug}" ]]; then
    log_error "emit_builtin_tokens_for_entry: could not derive slug from entry '${entry}'"
    return 1
  fi

  mkdir -p "${out_dir}"

  local base="${prefix}_${slug}"
  printf '%s' "${entry}" > "${out_dir}/${base}_REF"
  printf '%s' "${version_spec}" > "${out_dir}/${base}_VERSION_SPEC"
  printf '%s' "${resolved_version}" > "${out_dir}/${base}_VERSION"
}
