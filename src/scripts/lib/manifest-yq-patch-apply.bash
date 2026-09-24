#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# manifest-yq-patch-apply.bash - Apply yq patches to the manifests beside them
#
# Design in YqPatches.md; patch file grammar in lib/manifest-file-kinds.bash.
# Each target's intermediate states are kept in a per-target sandbox for
# provenance.
#
# Rules for all patch types:
#
#   Compare against a yq-normalised baseline: yq reformats the whole file even
#   for a no-op, so raw bytes would always differ.
#
#   A patch that changes nothing fails: yq exits 0 silently when an expression
#   matches no path.
#
#   Check output shape (non-empty, kind, apiVersion): yq never emits invalid
#   YAML, so a parse check cannot catch a destroyed manifest.
#
# Functions:
#   manifest_patch_tree - apply all patches in a tree, in order, per target
#
# Requires lib/log.bash and lib/manifest-file-kinds.bash. Requires yq 4.
#
# shellcheck disable=SC2154  # MANIFEST_FILE_* set by lib/manifest-file-kinds.bash
# shellcheck disable=SC2016  # '$ENV' is a yq operator

# Operators that read files or environment variables, which could then be
# written into a pushed manifest. The sandbox cannot contain them: yq file
# operators accept any path. yq has no dynamic dispatch, so a literal check
# suffices. merge-yaml is exempt because its content is never evaluated.
# Matched with the opening paren so a key named 'env' passes. Longest first:
# shorter names are substrings of longer ones, and matches are stripped as found.
MANIFEST_PATCH_BANNED_OPERATORS=('load_str(' 'loadJson(' 'strenv(' 'load(' 'env(' '$ENV')

# Internal: checksum of yq's normalised output, blind to formatting.
manifest_patch_checksum() {
  yq e '.' "${1}" 2>/dev/null | shasum -a 256 | cut -d' ' -f1
}

# Internal: does this file still look like a Kubernetes manifest?
# Usage: manifest_patch_shape_ok <file> <label>
manifest_patch_shape_ok() {
  local file="${1}" label="${2}"
  local kind api

  if [[ ! -s "${file}" ]]; then
    log_error "  ${label}: left the manifest empty"
    return 1
  fi
  kind=$(yq e '.kind // ""' "${file}" 2>/dev/null || true)
  api=$(yq e '.apiVersion // ""' "${file}" 2>/dev/null || true)
  if [[ -z "${kind}" || -z "${api}" ]]; then
    log_error "  ${label}: left the manifest without kind or apiVersion"
    return 1
  fi
  return 0
}

# Internal: reject an expression that reads outside itself.
# Usage: manifest_patch_check_operators <patch-file> <label>
manifest_patch_check_operators() {
  local patch="${1}" label="${2}"
  local op content clean=true

  content=$(cat "${patch}")
  for op in "${MANIFEST_PATCH_BANNED_OPERATORS[@]}"; do
    case "${content}" in
      *"${op}"*)
        log_error "  ${label}: uses '${op}', which reads outside the patch"
        clean=false
        # Stop shorter substring operators matching this occurrence.
        content="${content//"${op}"/}"
        ;;
    esac
  done

  if ! ${clean}; then
    log_error "    A patch may use tokens, which resolve through substitution and are"
    log_error "    declared. Reading a file or an environment variable is neither."
  fi
  ${clean}
}

# Internal: apply one patch file to one manifest, in the sandbox.
# Usage: manifest_patch_apply_one <manifest> <patch> <type> <label> <sandbox> <seq>
manifest_patch_apply_one() {
  local manifest="${1}" patch="${2}" patch_type="${3}" label="${4}" sandbox="${5}" seq="${6}"

  case "${patch_type}" in
    merge-yaml)
      if ! yq e '.' "${patch}" >/dev/null 2>&1; then
        log_error "  ${label}: not valid YAML"
        return 1
      fi
      manifest_patch_step "${manifest}" "${label}" "${sandbox}" "${seq}" "" \
        ". *+ load(\"${patch}\")"
      ;;
    from-file)
      manifest_patch_check_operators "${patch}" "${label}" || return 1
      if [[ ! -s "${patch}" ]]; then
        log_error "  ${label}: empty patch file"
        return 1
      fi
      manifest_patch_step "${manifest}" "${label}" "${sandbox}" "${seq}" "" \
        "$(cat "${patch}")"
      ;;
    expression-list)
      manifest_patch_check_operators "${patch}" "${label}" || return 1
      local line_no=0 expression applied=0
      while IFS= read -r expression || [[ -n "${expression}" ]]; do
        line_no=$((line_no + 1))
        case "${expression}" in
          ''|[[:space:]]*'#'*|'#'*) continue ;;
        esac
        [[ -z "${expression//[[:space:]]/}" ]] && continue
        manifest_patch_step "${manifest}" "${label} line ${line_no}" \
          "${sandbox}" "${seq}" "${line_no}" "${expression}" || return 1
        applied=$((applied + 1))
      done < "${patch}"
      if [[ "${applied}" -eq 0 ]]; then
        log_error "  ${label}: no expressions, only blanks and comments"
        return 1
      fi
      ;;
  esac
}

# Internal: one yq application. Enforces the header rules for all types.
#
# Usage: manifest_patch_step <manifest> <label> <sandbox> <seq> <line-or-empty> <expression>
manifest_patch_step() {
  local manifest="${1}" label="${2}" sandbox="${3}" seq="${4}" line="${5}" expression="${6}"
  local before_name
  before_name="before-$(printf '%03d' "${seq}")"
  [[ -n "${line}" ]] && before_name="${before_name}-line-$(printf '%03d' "${line}")"

  cp "${manifest}" "${sandbox}/${before_name}.yaml"

  local baseline result
  baseline=$(manifest_patch_checksum "${manifest}")

  local tmp="${manifest}.applying"
  cp "${manifest}" "${tmp}"
  if ! yq e -i "${expression}" "${tmp}" 2>"${sandbox}/${before_name}.stderr"; then
    log_error "  ${label}: yq rejected the expression"
    while IFS= read -r line; do log_error "    ${line}"; done < "${sandbox}/${before_name}.stderr"
    rm -f "${tmp}"
    return 1
  fi
  rm -f "${sandbox}/${before_name}.stderr"

  result=$(manifest_patch_checksum "${tmp}")
  if [[ "${result}" == "${baseline}" ]]; then
    log_error "  ${label}: changed nothing"
    log_error "    yq reports success when an expression matches no path, so a patch that"
    log_error "    does nothing is either already applied, aimed at the wrong thing, or"
    log_error "    written against a shape the manifest no longer has."
    rm -f "${tmp}"
    return 1
  fi

  if ! manifest_patch_shape_ok "${tmp}" "${label}"; then
    rm -f "${tmp}"
    return 1
  fi

  mv "${tmp}" "${manifest}"
}

# Apply each patch in a tree to the manifest beside it.
#
# Patches for a target apply in LC_ALL=C order of description. Sorting whole
# filenames would let the type decide the order.
#
# Usage: manifest_patch_tree <tree> <sandbox-base>
# Returns: 0 when all patches applied, 1 with failures logged
# Sets: MANIFEST_PATCH_APPLIED_COUNT, MANIFEST_PATCH_TARGET_COUNT
manifest_patch_tree() {
  local tree="${1}" sandbox_base="${2}"
  local LC_ALL=C

  MANIFEST_PATCH_APPLIED_COUNT=0
  MANIFEST_PATCH_TARGET_COUNT=0

  # '<target-path>\t<desc>\t<patch-path>\t<type>'
  local index="${sandbox_base}/patch-index.tsv"
  mkdir -p "${sandbox_base}"
  : > "${index}"

  local file target_path
  while IFS= read -r file; do
    manifest_file_classify "${file}" || continue
    [[ "${MANIFEST_FILE_KIND}" == "modifier" && "${MANIFEST_FILE_MODIFIER_TYPE}" == yq-* ]] || continue
    target_path="$(dirname "${file}")/${MANIFEST_FILE_MODIFIER_TARGET}"
    printf '%s\t%s\t%s\t%s\n' "${target_path}" "${MANIFEST_FILE_MODIFIER_DESC}" \
      "${file}" "${MANIFEST_FILE_MODIFIER_TYPE#yq-}" >> "${index}"
  done < <(manifest_files_find_packageable "${tree}")

  [[ -s "${index}" ]] || return 0

  local failed=false current="" sandbox seq rel
  local sorted="${sandbox_base}/patch-order.tsv"
  LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k2,2 "${index}" > "${sorted}"

  # 'desc' is read only to consume its column.
  local patch_path patch_type desc
  # shellcheck disable=SC2034
  while IFS="$(printf '\t')" read -r target_path desc patch_path patch_type; do
    if [[ "${target_path}" != "${current}" ]]; then
      current="${target_path}"
      seq=0
      MANIFEST_PATCH_TARGET_COUNT=$((MANIFEST_PATCH_TARGET_COUNT + 1))
      rel="${target_path#"${tree}"/}"
      sandbox="${sandbox_base}/$(printf '%s' "${rel}" | tr '/' '_')"
      mkdir -p "${sandbox}"
      log ""
      log "  ${rel}"
    fi
    seq=$((seq + 1))
    if manifest_patch_apply_one "${target_path}" "${patch_path}" "${patch_type}" \
        "${patch_path##*/}" "${sandbox}" "${seq}"; then
      log "    applied ${patch_path##*/}"
      MANIFEST_PATCH_APPLIED_COUNT=$((MANIFEST_PATCH_APPLIED_COUNT + 1))
    else
      failed=true
    fi
    cp "${target_path}" "${sandbox}/after-$(printf '%03d' "${seq}").yaml" 2>/dev/null || true
  done < "${sorted}"

  ! ${failed}
}
