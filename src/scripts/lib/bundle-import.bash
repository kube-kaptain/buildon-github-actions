#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# bundle-import.bash - Normalise and combine per-bundle staged content into
# the foreign-contributor drop dirs consumed by kubernetes-manifests-package-prepare.
#
# Operates on the tree staged by content-resolve.bash (under CONTENT_BASE) and
# writes the merged result to MANIFESTS_ADDITIONAL_SUB_PATH (manifests) and
# MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH (defaults). Cross-pass safe: env/rp
# builds run two import passes (content then templates) that share the same
# drop dirs; per-bundle subdir collisions and defaults-value collisions are
# fatal across passes too.
#
# Required env to source this file:
#   CONTENT_BASE                          - set by lib/content-resolve.bash
#   MANIFESTS_ADDITIONAL_SUB_PATH         - set by defaults/manifests-sub-path.bash
#   MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH - set by defaults/manifests-sub-path.bash
#   TOKEN_DELIMITER_STYLE / TOKEN_NAME_STYLE - product/env scheme to convert TO
#   CONTENT_FLAVOUR                       - set by caller; carried in errors
#
# Exported by sourcing this file:
#   BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR - intermediate, ${CONTENT_BASE}/import/defaults-normalised/
#
# Required tools: yq, find, cmp

# shellcheck disable=SC2034 # vars exported for callers
# shellcheck disable=SC2154 # CONTENT_MANIFESTS_DIR, CONTENT_CONTRACTS_DIR, CONTENT_DEFAULTS_DIR, CONTENT_FLAVOUR set by lib/content-resolve.bash and caller; TOKEN_DELIMITER_STYLE, TOKEN_NAME_STYLE set by defaults/tokens.bash

if [[ -z "${CONTENT_BASE:-}" ]]; then
  log_error "CONTENT_BASE is not set. Source lib/content-resolve.bash before bundle-import.bash."
  # shellcheck disable=SC2317 # dual-mode: works whether sourced or executed
  return 1 2>/dev/null || exit 1
fi

if [[ -z "${MANIFESTS_ADDITIONAL_SUB_PATH:-}" || -z "${MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH:-}" ]]; then
  log_error "MANIFESTS_ADDITIONAL_SUB_PATH / MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH are not set. Source defaults/manifests-sub-path.bash before bundle-import.bash."
  # shellcheck disable=SC2317 # dual-mode: works whether sourced or executed
  return 1 2>/dev/null || exit 1
fi

BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR="${CONTENT_BASE}/import/defaults-normalised"
export BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR

BUNDLE_IMPORT_UTIL_DIR="${BUNDLE_IMPORT_UTIL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../util" && pwd)}"

# Read tokens.delimiterStyle / tokens.nameStyle from a contract.yaml.
# Sets BUNDLE_DELIM_STYLE and BUNDLE_NAME_STYLE.
bundle_import_read_bundle_scheme() {
  local contract="$1"
  if [[ ! -f "${contract}" ]]; then
    log_error "Contract file not found for bundle: ${contract}"
    log_error "Bundles must be republished with a contract zip before being consumed."
    return 1
  fi
  BUNDLE_DELIM_STYLE=$(yq -r '.tokens.delimiterStyle // ""' "${contract}")
  BUNDLE_NAME_STYLE=$(yq -r '.tokens.nameStyle // ""' "${contract}")
  if [[ -z "${BUNDLE_DELIM_STYLE}" || -z "${BUNDLE_NAME_STYLE}" ]]; then
    log_error "Bundle contract is missing tokens.delimiterStyle or tokens.nameStyle: ${contract}"
    return 1
  fi
}

# Per-bundle scheme conversion for manifests. Writes verbatim or
# converted copy to <manifests_target>/<bundle>/, where manifests_target
# defaults to MANIFESTS_ADDITIONAL_SUB_PATH if not supplied.
# Fails if the target subdir exists already (cross-pass collision).
bundle_import_normalise_manifests() {
  local bundle="$1"
  local manifests_target="${2:-${MANIFESTS_ADDITIONAL_SUB_PATH}}"
  local manifests_dir="${CONTENT_MANIFESTS_DIR}/${bundle}"
  local normalised_dir="${manifests_target}/${bundle}"
  local contract_file="${CONTENT_CONTRACTS_DIR}/${bundle}/contract.yaml"

  if [[ -e "${normalised_dir}" ]]; then
    log_error "Bundle ${bundle} from this pass conflicts with bundle ${bundle} imported earlier in the build (flavour=${CONTENT_FLAVOUR})."
    log_error "Target subdir already exists: ${normalised_dir}"
    return 1
  fi

  bundle_import_read_bundle_scheme "${contract_file}"
  log "Bundle ${bundle}:"
  log "  Path: ${manifests_dir}"
  log "  Scheme: ${BUNDLE_DELIM_STYLE}-${BUNDLE_NAME_STYLE}"
  if [[ "${BUNDLE_DELIM_STYLE}" == "${TOKEN_DELIMITER_STYLE}" \
     && "${BUNDLE_NAME_STYLE}" == "${TOKEN_NAME_STYLE}" ]]; then
    log "  Token scheme matches."
    cp -R "${manifests_dir}" "${normalised_dir}"
    log "  Copied verbatim to ${normalised_dir}"
    log ""
    return 0
  else
    log "  Token scheme mismatch."
    local token_count
    token_count=$(yq -r '(.config.required // []) | length' "${contract_file}")
    log "  Tokens to convert: ${token_count}"
  fi

  if [[ "${token_count}" -eq 0 ]]; then
    log "  No tokens to convert, consuming as is."
    cp -R "${manifests_dir}" "${normalised_dir}"
    log "  Copied verbatim to ${normalised_dir}"
    log ""
    return 0
  fi

  local target_combo="${TOKEN_DELIMITER_STYLE}-${TOKEN_NAME_STYLE}"

  local assessment
  assessment=$("${BUNDLE_IMPORT_UTIL_DIR}/assess-token-compatibility" \
      "${BUNDLE_DELIM_STYLE}" "${BUNDLE_NAME_STYLE}" "${manifests_dir}")

  local section="" found_auto=false found_repackage=false
  while IFS= read -r line; do
    case "${line}" in
      AUTOMATIC_CONVERSION:) section="auto" ;;
      REPACKAGE_REQUIRED:)   section="repackage" ;;
      "") ;;
      *)
        if [[ "${line}" == "${target_combo}" ]]; then
          [[ "${section}" == "auto" ]]      && found_auto=true
          [[ "${section}" == "repackage" ]] && found_repackage=true
        fi
        ;;
    esac
  done <<< "${assessment}"

  if ${found_auto}; then
    cp -R "${manifests_dir}" "${normalised_dir}"
    "${BUNDLE_IMPORT_UTIL_DIR}/convert-tokens-in-tree" \
      "${BUNDLE_DELIM_STYLE}" "${BUNDLE_NAME_STYLE}" \
      "${TOKEN_DELIMITER_STYLE}" "${TOKEN_NAME_STYLE}" \
      "${normalised_dir}" \
      "  "
    log ""
    return 0
  fi

  if ${found_repackage}; then
    log_error "Bundle ${bundle} uses token substitution scheme ${BUNDLE_DELIM_STYLE}-${BUNDLE_NAME_STYLE},"
    log_error "which cannot be automatically converted to the consuming project's token substitution scheme"
    log_error "${target_combo}. The bundle's manifests contain content that is declared as incompatible"
    log_error "with this project's token substitution scheme by the contract supplied with the manifests."
    log_error "Rebuild the upstream project to suit or repackage if you don't control it."
    log ""
    return 1
  fi

  log_error "assess-token-compatibility did not classify ${target_combo} for bundle ${bundle}"
  log ""
  return 1
}

# Mirror of bundle_import_normalise_manifests for the bundle's defaults dir.
# Reads BUNDLE_NAME_STYLE populated by an earlier bundle_import_read_bundle_scheme
# call; matches the consuming project's TOKEN_NAME_STYLE by walking each
# defaults file, canonicalising its relative path, and re-emitting it under the
# target style. Empty/missing source -> log and skip; matching styles ->
# verbatim copy.
bundle_import_normalise_defaults() {
  local bundle="$1"
  local source_dir="${CONTENT_DEFAULTS_DIR}/${bundle}"
  local normalised_dir="${BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR}/${bundle}"

  log "Bundle ${bundle} defaults:"
  if [[ ! -d "${source_dir}" ]] \
     || [[ -z "$(find "${source_dir}" -type f 2>/dev/null)" ]]; then
    log "  No defaults present"
    log ""
    return 0
  fi

  if [[ "${BUNDLE_NAME_STYLE}" == "${TOKEN_NAME_STYLE}" ]]; then
    log "  Default names match."
    cp -R "${source_dir}" "${normalised_dir}"
    log "  Copied verbatim to ${normalised_dir}"
    log ""
    return 0
  fi

  local default_count
  default_count=$(find "${source_dir}" -type f | wc -l | tr -d ' ')
  log "  Default names mismatch."
  log "  Renaming ${default_count} default(s) from ${BUNDLE_NAME_STYLE} to ${TOKEN_NAME_STYLE}"

  mkdir -p "${normalised_dir}"
  local file rel canonical target target_path
  while IFS= read -r -d '' file; do
    rel="${file#"${source_dir}/"}"
    canonical=$(canonicalize_token_name "${BUNDLE_NAME_STYLE}" "${rel}")
    target=$(convert_token_name "${TOKEN_NAME_STYLE}" "${canonical}")
    target_path="${normalised_dir}/${target}"
    mkdir -p "$(dirname "${target_path}")"
    cp "${file}" "${target_path}"
    log "   - Renamed ${rel} → ${target}"
  done < <(find "${source_dir}" -type f -print0)
  log ""
}

# Walk every per-bundle defaults directory under
# BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR and merge byte-identical files into
# MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH. Differing values fail with diagnostics.
# Existing files in the target dir from prior import passes are treated as
# additional contributions and must also be byte-identical.
bundle_import_combine_defaults() {
  mkdir -p "${MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH}"
  [[ -d "${BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR}" ]] || return 0

  # Build a list of "<token-rel-path>\t<bundle>" lines across every bundle.
  local index_file="${CONTENT_BASE}/import/.defaults-index"
  mkdir -p "$(dirname "${index_file}")"
  : > "${index_file}"
  local bundle_dir bundle file rel
  for bundle_dir in "${BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR}"/*; do
    [[ -d "${bundle_dir}" ]] || continue
    bundle=$(basename "${bundle_dir}")
    while IFS= read -r -d '' file; do
      rel="${file#"${bundle_dir}/"}"
      printf '%s\t%s\n' "${rel}" "${bundle}" >> "${index_file}"
    done < <(find "${bundle_dir}" -type f -print0)
  done

  [[ -s "${index_file}" ]] || { rm -f "${index_file}"; return 0; }

  # Group by token rel path and verify byte-identical contents.
  local tokens
  tokens=$(awk -F '\t' '{print $1}' "${index_file}" | LC_ALL=C sort -u)

  local token first_bundle first_file other_bundle other_file
  while IFS= read -r token; do
    [[ -z "${token}" ]] && continue
    local bundles=()
    while IFS=$'\t' read -r t b; do
      [[ "${t}" == "${token}" ]] && bundles+=("${b}")
    done < "${index_file}"

    first_bundle="${bundles[0]}"
    first_file="${BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR}/${first_bundle}/${token}"

    local i
    for ((i = 1; i < ${#bundles[@]}; i++)); do
      other_bundle="${bundles[i]}"
      other_file="${BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR}/${other_bundle}/${token}"
      if ! cmp -s "${first_file}" "${other_file}"; then
        log_error "Default value collision for token '${token}':"
        log_error "  ${first_bundle}: $(cat "${first_file}")"
        log_error "  ${other_bundle}: $(cat "${other_file}")"
        log_error "Bundles ship different defaults for the same token name. Either align the"
        log_error "values upstream or prefix the token with the project name in one bundle to"
        log_error "disambiguate."
        rm -f "${index_file}"
        return 1
      fi
    done

    # Cross-pass collision: a prior import pass (e.g. content before templates
    # in an env/rp build) may already have written this token. Treat the
    # existing file as another contributor and require byte-identical.
    local target_file="${MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH}/${token}"
    if [[ -e "${target_file}" ]]; then
      if ! cmp -s "${first_file}" "${target_file}"; then
        log_error "Default value collision for token '${token}' across import passes:"
        log_error "  earlier pass: $(cat "${target_file}")"
        log_error "  ${first_bundle} (flavour=${CONTENT_FLAVOUR}): $(cat "${first_file}")"
        log_error "An earlier bundle import wrote a different default for the same token name."
        log_error "Align the values upstream or prefix the token with the project name in one"
        log_error "of the bundles to disambiguate."
        rm -f "${index_file}"
        return 1
      fi
    else
      mkdir -p "$(dirname "${target_file}")"
      cp "${first_file}" "${target_file}"
    fi
  done <<< "${tokens}"

  rm -f "${index_file}"
}

# Orchestrate the import of every bundle staged under CONTENT_MANIFESTS_DIR:
# per-bundle scheme conversion for manifests and defaults, then cross-bundle
# defaults combination.
#
# Optional arg: manifests_target - per-bundle manifest output dir. Defaults to
# MANIFESTS_ADDITIONAL_SUB_PATH. Callers that need an intermediate dir (e.g.
# templates-import staging before flattening) pass it explicitly.
#
# Does NOT clear the manifest target or MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH
# because earlier import passes (other flavour) and other build stages may have
# written into them; per-pass collisions are detected explicitly.
bundle_import_all() {
  local manifests_target="${1:-${MANIFESTS_ADDITIONAL_SUB_PATH}}"
  mkdir -p "${manifests_target}" "${BUNDLE_IMPORT_DEFAULTS_NORMALISED_DIR}"

  log ""
  log "Per-bundle scheme conversion to ${TOKEN_DELIMITER_STYLE}-${TOKEN_NAME_STYLE} if needed..."
  log ""
  local bundle_dir bundle
  for bundle_dir in "${CONTENT_MANIFESTS_DIR}"/*; do
    [[ -d "${bundle_dir}" ]] || continue
    bundle=$(basename "${bundle_dir}")
    bundle_import_normalise_manifests "${bundle}" "${manifests_target}"
    bundle_import_normalise_defaults "${bundle}"
  done

  log ""
  log "Merging per-bundle defaults into ${MANIFESTS_ADDITIONAL_DEFAULTS_SUB_PATH}..."
  log ""
  bundle_import_combine_defaults
}
