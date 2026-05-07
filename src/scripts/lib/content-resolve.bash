#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# content-resolve.bash - Resolve and stage spec.contents entries.
#
# Sourced library exposing functions to resolve OCI artifact references,
# fetch and unpack the manifests + contract zips that each entry contains,
# and stage the result into per-entry directories. Used by product-aggregate
# now and environment-build later.
#
# Policy-free: the library only stages whatever is in spec.contents into
# per-bundle subdirectories. Conflict detection across defaults, scheme
# conversion decisions, and merging are caller concerns.
#
# Output layout (under <content-base> chosen by the caller):
#   <out-extract-dir>/<artifact-slug>/      - OCI image contents incl. the zips,
#                                             left in place as audit trail
#   <out-unzipped-dir>/<artifact-slug>/     - contents of both zips, left in
#                                             place as audit trail
#   <out-manifests-dir>/<project>/...       - cp from unzipped/<slug>/<project>
#   <out-defaults-dir>/<project>/<token>    - cp from unzipped/<slug>/defaults
#   <out-contracts-dir>/<project>/contract.yaml  - cp from unzipped/<slug>
#
# <artifact-slug> is the resolved OCI URI with '/' and ':' replaced by '_'.
#
# Functions:
#   content_resolve_all           - Orchestrator: resolve every entry in spec.contents
#   content_find_zips             - Locate manifests + contract zips in an extracted tree
#   content_unzip_manifests       - Unzip manifests zip into audit dir, cp project subdir to out
#   content_unzip_contract        - Unzip contract zip into audit dir, cp contract+defaults to out
#
# Output variables (set by helpers, read by caller / orchestrator):
#   CONTENT_MANIFESTS_ZIP   - absolute path to located manifests zip
#   CONTENT_CONTRACT_ZIP    - absolute path to located contract zip
#   CONTENT_PROJECT_NAME    - project name discovered from the manifests zip
#
# Required env (for content_resolve_all):
#   IMAGE_BUILD_COMMAND - docker or podman (used by extract-oci-image)
#
# Required tools: yq, unzip

# shellcheck disable=SC2034 # Some helpers set output vars consumed by callers.

_CONTENT_RESOLVE_UTIL_DIR="${_CONTENT_RESOLVE_UTIL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../util" && pwd)}"
_CONTENT_RESOLVE_PLUGINS_DIR="${_CONTENT_RESOLVE_PLUGINS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../plugins" && pwd)}"
_CONTENT_RESOLVE_SCHEMAS_DIR="${_CONTENT_RESOLVE_SCHEMAS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../schemas" && pwd)}"

# Reduce a resolved OCI URI to a filesystem-safe slug. Replaces '/' and ':'
# with '_'. The slug names per-artifact subdirs under <out-extract-dir> and
# <out-unzipped-dir> so the audit trail is keyed on the artifact identity.
_content_artifact_slug() {
  local uri="$1"
  echo "${uri}" | tr '/:' '__'
}

# Locate the manifests and contract zips inside an extracted OCI image tree.
# Sets CONTENT_MANIFESTS_ZIP and CONTENT_CONTRACT_ZIP to absolute paths.
# Returns 1 with diagnostic if either is missing or duplicated.
#
# Usage: content_find_zips <extract-dir>
content_find_zips() {
  if [[ $# -ne 1 ]]; then
    log_error "content_find_zips requires exactly 1 argument, got $#"
    return 1
  fi
  local extract_dir="$1"
  if [[ ! -d "${extract_dir}" ]]; then
    log_error "Extract dir not found: ${extract_dir}"
    return 1
  fi

  local manifests_zips=()
  local contract_zips=()
  while IFS= read -r -d '' zip; do
    case "${zip}" in
      *-manifests.zip) manifests_zips+=("${zip}") ;;
      *-contract.zip)  contract_zips+=("${zip}") ;;
    esac
  done < <(find "${extract_dir}" -type f -name '*.zip' -print0)

  if [[ ${#manifests_zips[@]} -ne 1 ]]; then
    log_error "Expected exactly one *-manifests.zip in ${extract_dir}, found ${#manifests_zips[@]}"
    return 1
  fi
  if [[ ${#contract_zips[@]} -ne 1 ]]; then
    log_error "Expected exactly one *-contract.zip in ${extract_dir}, found ${#contract_zips[@]}"
    return 1
  fi

  CONTENT_MANIFESTS_ZIP="${manifests_zips[0]}"
  CONTENT_CONTRACT_ZIP="${contract_zips[0]}"
}

# Unzip a manifests zip into <unzipped-dir> (audit trail) and cp the
# project subdir into <out-manifests-dir>. The zip contains a single
# top-level <project>/ directory which becomes a sibling of any
# previously staged bundle. Sets CONTENT_PROJECT_NAME.
#
# Usage: content_unzip_manifests <manifests-zip> <unzipped-dir> <out-manifests-dir>
content_unzip_manifests() {
  if [[ $# -ne 3 ]]; then
    log_error "content_unzip_manifests requires exactly 3 arguments, got $#"
    return 1
  fi
  local zip="$1"
  local unzipped_dir="$2"
  local out_dir="$3"
  if [[ ! -f "${zip}" ]]; then
    log_error "Manifests zip not found: ${zip}"
    return 1
  fi

  local project
  project=$(unzip -Z1 "${zip}" 2>/dev/null | head -1 | cut -d/ -f1)
  if [[ -z "${project}" ]]; then
    log_error "Could not determine project name from ${zip}"
    return 1
  fi

  mkdir -p "${out_dir}"
  if [[ -e "${out_dir}/${project}" ]]; then
    log_error "Project ${project} already staged in ${out_dir}"
    return 1
  fi

  mkdir -p "${unzipped_dir}"
  unzip -q "${zip}" -d "${unzipped_dir}"

  cp -R "${unzipped_dir}/${project}" "${out_dir}/${project}"
  CONTENT_PROJECT_NAME="${project}"
}

# Unzip a contract zip into <unzipped-dir> (audit trail) and cp its pieces
# into the per-project layout:
#   contract.yaml -> <out-contracts-dir>/<project>/contract.yaml
#   defaults/*    -> <out-defaults-dir>/<project>/*
#
# <unzipped-dir> may already contain unzipped manifests-zip output (the
# orchestrator unzips both into the same audit dir); the contract zip's
# top-level entries (contract.yaml and optional defaults/) do not collide
# with the manifests zip's <project>/ subdir.
#
# Usage: content_unzip_contract <contract-zip> <unzipped-dir> <out-contracts-dir> <out-defaults-dir> <project>
content_unzip_contract() {
  if [[ $# -ne 5 ]]; then
    log_error "content_unzip_contract requires exactly 5 arguments, got $#"
    return 1
  fi
  local zip="$1"
  local unzipped_dir="$2"
  local out_contracts_dir="$3"
  local out_defaults_dir="$4"
  local project="$5"
  if [[ ! -f "${zip}" ]]; then
    log_error "Contract zip not found: ${zip}"
    return 1
  fi
  if [[ -z "${project}" ]]; then
    log_error "project name is required"
    return 1
  fi

  mkdir -p "${unzipped_dir}"
  unzip -q "${zip}" -d "${unzipped_dir}"

  if [[ ! -f "${unzipped_dir}/contract.yaml" ]]; then
    log_error "contract.yaml not found inside ${zip}"
    return 1
  fi

  mkdir -p "${out_contracts_dir}/${project}"
  cp "${unzipped_dir}/contract.yaml" "${out_contracts_dir}/${project}/contract.yaml"

  if [[ -d "${unzipped_dir}/defaults" ]]; then
    mkdir -p "${out_defaults_dir}/${project}"
    local src rel dest
    while IFS= read -r -d '' src; do
      rel="${src#"${unzipped_dir}/defaults/"}"
      dest="${out_defaults_dir}/${project}/${rel}"
      mkdir -p "$(dirname "${dest}")"
      cp "${src}" "${dest}"
    done < <(find "${unzipped_dir}/defaults" -type f -print0)
  fi
}

# Validate a staged bundle against its declared contract: contract conforms to
# its schema; defaults filenames match the contract's declared name style;
# every defaults file maps to a required token; every unresolved token in the
# manifests is declared as required by the contract. Catches malformed or
# foreign bundles before the product/environment build operates on their
# innards.
#
# Usage: content_validate_bundle <project> <out-contracts-dir> <out-defaults-dir> <out-manifests-dir>
content_validate_bundle() {
  if [[ $# -ne 4 ]]; then
    log_error "content_validate_bundle requires exactly 4 arguments, got $#"
    return 1
  fi
  local project="$1"
  local out_contracts_dir="$2"
  local out_defaults_dir="$3"
  local out_manifests_dir="$4"

  local contract_file="${out_contracts_dir}/${project}/contract.yaml"
  local defaults_dir="${out_defaults_dir}/${project}"
  local manifests_dir="${out_manifests_dir}/${project}"

  if [[ ! -f "${contract_file}" ]]; then
    log_error "Bundle ${project}: contract.yaml not found at ${contract_file}"
    return 1
  fi
  if [[ ! -d "${manifests_dir}" ]]; then
    log_error "Bundle ${project}: manifests directory not found at ${manifests_dir}"
    return 1
  fi

  # Validate against the contract schema this build of kaptain ships, mirroring
  # how KaptainPM.yaml is validated. The version file is the single source of
  # truth; older bundles whose payload still satisfies the current schema keep
  # working, ones that don't fail with a clear validation error.
  local schema_dir schema_version schema_file
  schema_dir="${_CONTENT_RESOLVE_SCHEMAS_DIR}/manifests-contract"
  schema_version=$(cat "${schema_dir}/version")
  schema_file="${schema_dir}/spec-manifests-contract-schema-${schema_version}.json"
  if [[ ! -f "${schema_file}" ]]; then
    log_error "Bundle ${project}: schema not found: ${schema_file}"
    return 1
  fi
  if ! check-jsonschema --schemafile "${schema_file}" "${contract_file}"; then
    log_error "Bundle ${project}: contract.yaml does not validate against schema ${schema_version}"
    return 1
  fi

  local bundle_name_style bundle_delim_style
  bundle_name_style=$(yq -r '.tokens.nameStyle // ""' "${contract_file}")
  bundle_delim_style=$(yq -r '.tokens.delimiterStyle // ""' "${contract_file}")
  if [[ -z "${bundle_name_style}" || -z "${bundle_delim_style}" ]]; then
    log_error "Bundle ${project}: contract.yaml is missing tokens.nameStyle or tokens.delimiterStyle"
    return 1
  fi

  local has_defaults="false"
  if [[ -d "${defaults_dir}" ]] \
     && [[ -n "$(find "${defaults_dir}" -type f 2>/dev/null)" ]]; then
    has_defaults="true"
  fi

  # Defaults filenames must pass the contract's declared name style validator.
  # Catches producers that lied about their style or hand-edited the bundle.
  if [[ "${has_defaults}" == "true" ]]; then
    local validator_script="${_CONTENT_RESOLVE_PLUGINS_DIR}/token-name-validators/${bundle_name_style}"
    if [[ ! -x "${validator_script}" ]]; then
      log_error "Bundle ${project}: token-name validator not found for style ${bundle_name_style}"
      return 1
    fi
    if ! "${validator_script}" "${defaults_dir}"; then
      log_error "Bundle ${project}: one or more defaults filenames do not match the contract's declared name style ${bundle_name_style}"
      return 1
    fi
  fi

  local required_tokens
  required_tokens=$(yq -r '.config.required // [] | .[]' "${contract_file}")

  # Every defaults file's relative path must appear in .config.required.
  if [[ "${has_defaults}" == "true" ]]; then
    local orphans=()
    local default_file rel
    while IFS= read -r -d '' default_file; do
      rel="${default_file#"${defaults_dir}/"}"
      if [[ -z "${required_tokens}" ]] || ! grep -qxF "${rel}" <<< "${required_tokens}"; then
        orphans+=("${rel}")
      fi
    done < <(find "${defaults_dir}" -type f -print0)
    if [[ ${#orphans[@]} -gt 0 ]]; then
      log_error "Bundle ${project}: defaults file(s) not declared in contract .config.required:"
      for rel in "${orphans[@]}"; do
        log_error "  ${rel}"
      done
      return 1
    fi
  fi

  # Every unresolved token actually present in the manifests must appear in
  # .config.required. Producer claims to enumerate everything; verify by scan.
  local unresolved_tokens
  unresolved_tokens=$("${_CONTENT_RESOLVE_UTIL_DIR}/scan-unresolved-tokens" \
    "${bundle_delim_style}" "${bundle_name_style}" "${manifests_dir}")
  if [[ -n "${unresolved_tokens}" ]]; then
    local missing=()
    local token
    while IFS= read -r token; do
      [[ -z "${token}" ]] && continue
      if [[ -z "${required_tokens}" ]] || ! grep -qxF "${token}" <<< "${required_tokens}"; then
        missing+=("${token}")
      fi
    done <<< "${unresolved_tokens}"
    if [[ ${#missing[@]} -gt 0 ]]; then
      log_error "Bundle ${project}: unresolved token(s) present in manifests but not declared in contract .config.required:"
      for token in "${missing[@]}"; do
        log_error "  ${token}"
      done
      return 1
    fi
  fi
}

# Resolve every entry in spec.contents of <kaptainpm-file>, fetch the
# corresponding -manifests OCI image, and stage the unzipped manifests,
# contract, and defaults into the three given output directories.
#
# OCI image extraction lands in <out-extract-dir>/<artifact-slug>/ and
# both zips are unzipped into <out-unzipped-dir>/<artifact-slug>/. Both
# are kept after the run as the audit trail.
#
# When <out-resolved-yaml-file> is given, each entry's full resolved OCI
# reference (registry/namespace/repo:concrete-version) is appended as a
# YAML list item to that file. The file is truncated at the start.
#
# Usage: content_resolve_all <kaptainpm-file> <out-manifests-dir> <out-defaults-dir> <out-contracts-dir> <out-extract-dir> <out-unzipped-dir> [<out-resolved-yaml-file>]
content_resolve_all() {
  if [[ $# -lt 6 || $# -gt 7 ]]; then
    log_error "Usage: content_resolve_all <kaptainpm-file> <out-manifests-dir> <out-defaults-dir> <out-contracts-dir> <out-extract-dir> <out-unzipped-dir> [<out-resolved-yaml-file>]"
    return 1
  fi
  local kaptainpm_file="$1"
  local out_manifests_dir="$2"
  local out_defaults_dir="$3"
  local out_contracts_dir="$4"
  local out_extract_dir="$5"
  local out_unzipped_dir="$6"
  local out_resolved_yaml="${7:-}"

  if [[ ! -f "${kaptainpm_file}" ]]; then
    log_error "KaptainPM file not found: ${kaptainpm_file}"
    return 1
  fi

  if ! command -v yq >/dev/null 2>&1; then
    log_error "yq is required for content_resolve_all"
    return 1
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    log_error "unzip is required for content_resolve_all"
    return 1
  fi

  mkdir -p "${out_manifests_dir}" "${out_defaults_dir}" "${out_contracts_dir}" \
           "${out_extract_dir}" "${out_unzipped_dir}"

  if [[ -n "${out_resolved_yaml}" ]]; then
    mkdir -p "$(dirname "${out_resolved_yaml}")"
    : > "${out_resolved_yaml}"
  fi

  local entries
  entries=$(yq eval '.spec.contents[]' "${kaptainpm_file}" 2>/dev/null || true)
  if [[ -z "${entries}" || "${entries}" == "null" ]]; then
    log "No spec.contents entries to resolve"
    return 0
  fi

  local total
  total=$(echo "${entries}" | grep -c .)
  log "Contents lists ${total} entr$([[ ${total} -eq 1 ]] && echo y || echo ies):"
  local summary_entry
  while IFS= read -r summary_entry; do
    [[ -z "${summary_entry}" ]] && continue
    log "  ${summary_entry}"
  done <<< "${entries}"
  log ""

  local entry_index=0
  local entry
  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    entry_index=$((entry_index + 1))
    log "Resolving content entry ${entry_index}: ${entry}"

    # Resolve to the concrete OCI URI. Land the resolved-uri file at a
    # known per-entry path, then move it into the slug-named extract dir
    # once we know the slug. Keeping it makes the audit trail show what
    # the entry actually resolved to at the moment of the build.
    local resolve_seed="${out_extract_dir}/resolved-entry-${entry_index}.uri"
    "${_CONTENT_RESOLVE_UTIL_DIR}/artifact-resolve" "${entry}" "${resolve_seed}" manifests || return $?
    local resolved_uri
    resolved_uri=$(cat "${resolve_seed}")
    log "  Resolved: ${resolved_uri}"

    if [[ -n "${out_resolved_yaml}" ]]; then
      printf -- '- %s\n' "${resolved_uri}" >> "${out_resolved_yaml}"
    fi

    local slug
    slug=$(_content_artifact_slug "${resolved_uri}")
    local extract_dir="${out_extract_dir}/${slug}"
    local unzipped_dir="${out_unzipped_dir}/${slug}"
    mkdir -p "${extract_dir}" "${unzipped_dir}"
    mv "${resolve_seed}" "${extract_dir}/resolved-uri"

    "${_CONTENT_RESOLVE_UTIL_DIR}/extract-oci-image" "${resolved_uri}" "${extract_dir}" || return $?

    content_find_zips "${extract_dir}" || return $?
    content_unzip_manifests "${CONTENT_MANIFESTS_ZIP}" "${unzipped_dir}" "${out_manifests_dir}" || return $?
    local project="${CONTENT_PROJECT_NAME}"
    content_unzip_contract "${CONTENT_CONTRACT_ZIP}" "${unzipped_dir}" \
      "${out_contracts_dir}" "${out_defaults_dir}" "${project}" || return $?

    content_validate_bundle "${project}" "${out_contracts_dir}" "${out_defaults_dir}" "${out_manifests_dir}" || return $?

    log "  Staged ${project}"
    log ""
  done <<< "${entries}"

  log "Resolved ${entry_index} content entr$([[ ${entry_index} -eq 1 ]] && echo y || echo ies)"
}
