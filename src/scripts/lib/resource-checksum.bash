#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# resource-checksum.bash - Checksum-marked resource renaming with tree-wide
# reference rewrite. See todo-checked/ResourceChecksum.md for the design.
#
# The '-<kind>-checksum' name marker is replaced by the hash
# (app-configmap-checksum -> app-x2y5z). A name ending '-checksum' without its
# own lowercased kind fragment may be a legitimate name, so it only warns.
#
# Secret templates go first so consumers hash over final Secret names; an
# empty secrets dir skips them (RP builds: child-owned secrets). Other kinds
# follow in order-file sequence, each hashed over its current document so
# earlier rewrites count, then its references are rewritten before the next.
#
# The rename is one bounded text rewrite across the tree, the resource's own
# metadata.name included: marked names are unique and may appear anywhere
# (env values, CRD fields, annotations, comments). Name characters are the
# Kubernetes set [a-z0-9.-] and anything else is a boundary, so
# wtf-bbq-configmap-checksum cannot match inside omg-wtf-bbq-configmap-checksum
# or omg.wtf-bbq-configmap-checksum. Each rewrite is verified: the old name is
# gone, exactly one resource of the kind carries the new name, and every other
# marked name occurs as often as before. Any failure fails the build.
#
# Usage: checksum_tree <tree> <secrets-dir-or-empty> <order-file>
#
# Configuration env vars (read here, set by the entrypoint):
#   RESOURCE_CHECKSUM_LENGTH    Suffix length in Base32 chars. Default 5.
#                               Warns <4 or >12. Hard-fails >52
#                               (SHA-256 has 256 bits = 52 Base32 chars).
#   RESOURCE_CHECKSUM_AUDIT_DIR Secret input blobs, kept for inspection
#                               (default <output>/run-finalise/secret-checksum-inputs).
#   TOKEN_DELIMITER_STYLE / TOKEN_NAME_STYLE  How secret-template tokens are
#                               matched (defaults/tokens.bash).
#
# Requires lib/token-format.bash, lib/token-markers.bash and
# lib/secret-encryption-types.bash sourced by the caller, with
# SECRET_ENCRYPTION_TYPES_FILE written (the caller checks it exists).
#
# Required tools: yq 4, find, sed, sha256sum (via hash-base32.sh).

# shellcheck source=src/scripts/lib/hash-base32.sh
RESOURCE_CHECKSUM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${RESOURCE_CHECKSUM_LIB_DIR}/hash-base32.sh"

# Sets RESOURCE_CHECKSUM_LENGTH in place instead of printing it, so warnings
# are not swallowed by a command substitution.
resource_checksum_length() {
  local length="${RESOURCE_CHECKSUM_LENGTH:-5}"
  if [[ ! "${length}" =~ ^[0-9]+$ ]]; then
    log_error "RESOURCE_CHECKSUM_LENGTH must be a positive integer, got '${length}'"
    return 1
  fi
  if (( length > 52 )); then
    log_error "RESOURCE_CHECKSUM_LENGTH=${length} exceeds 52 (SHA-256 only yields 52 Base32 chars)"
    return 1
  fi
  if (( length < 4 )); then
    log_warning "RESOURCE_CHECKSUM_LENGTH=${length} (< 4); collision risk rises sharply"
  elif (( length > 12 )); then
    log_warning "RESOURCE_CHECKSUM_LENGTH=${length} (> 12); long suffixes hurt readability"
  fi
  RESOURCE_CHECKSUM_LENGTH="${length}"
}

# LC_ALL=C for a deterministic order. Same-kind reference chains only cascade
# when the referenced resource sorts first: the order file orders kinds, not
# resources within a kind. A real chain needs a dependency sort in the kind pass.
resource_checksum_find_yaml() {
  local tree="$1"
  find "${tree}" -type f -name '*.yaml' -print0 | LC_ALL=C sort -z
}

# Printed by the calling step.
RESOURCE_CHECKSUM_TOTAL_RESOURCES=0
RESOURCE_CHECKSUM_TOTAL_REFS=0
RESOURCE_CHECKSUM_TOTAL_REF_FILES=0

# Kubernetes object name rule (DNS subdomain). Kinds needing the stricter
# DNS label form are left to the API server.
is_kubernetes_name() {
  local name="$1"
  [[ ${#name} -le 253 ]] || return 1
  [[ "${name}" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$ ]]
}

# Occurrence count of each name in <names> (one per line) across all YAML
# under <tree>, as '<count> <name>' lines. awk 1 ends every file with a
# newline so names cannot join across file boundaries.
marked_name_counts() {
  local tree="$1"
  local names="$2"
  find "${tree}" -type f -name '*.yaml' -exec awk 1 {} + \
    | tr -cs 'a-z0-9.-' '\n' | grep -xFf <(printf '%s\n' "${names}") | LC_ALL=C sort | uniq -c || true
}

# Rewrite bounded occurrences of <old> to <new> in all YAML under <tree>,
# renaming the resource itself along with every reference to it.
# Counting splits on non-name characters because a boundary-consuming regex
# undercounts adjacent matches.
rewrite_name_refs() {
  local tree="$1"
  local old="$2"
  local new="$3"

  if ! is_kubernetes_name "${old}"; then
    log_error "'${old}' is not a valid Kubernetes name; cannot rewrite it"
    return 1
  fi
  # '.' is the only regex metacharacter a valid name can hold.
  local old_re
  old_re=$(printf '%s' "${old}" | sed 's/\./\\./g')

  local file count
  local match_lines=""
  local match_count=0
  while IFS= read -r -d '' file; do
    count=$(tr -cs 'a-z0-9.-' '\n' < "${file}" | grep -cxF "${old}" || true)
    if [[ "${count}" -gt 0 ]]; then
      match_lines="${match_lines}${count}	${file}
"
      match_count=$((match_count + 1))
    fi
  done < <(resource_checksum_find_yaml "${tree}")

  log "  Found ${match_count} referring resources:"

  [[ "${match_count}" -eq 0 ]] && return 0

  # Loop to stability: occurrences sharing a boundary character ('x,x') need
  # re-runs. <new> cannot re-match <old>, so this terminates.
  local tmp line
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    count="${line%%	*}"
    file="${line#*	}"
    tmp=$(mktemp)
    cp "${file}" "${tmp}"
    while :; do
      sed -E "s#(^|[^a-z0-9.-])(${old_re})([^a-z0-9.-]|\$)#\\1${new}\\3#g" "${tmp}" > "${tmp}.next"
      if cmp -s "${tmp}" "${tmp}.next"; then
        rm -f "${tmp}.next"
        break
      fi
      mv "${tmp}.next" "${tmp}"
    done
    mv "${tmp}" "${file}"
    # shellcheck disable=SC2059 # fixed format
    log "$(printf '  %-2d references replaced in %s' "${count}" "${file#"${tree}"/}")"
    RESOURCE_CHECKSUM_TOTAL_REFS=$((RESOURCE_CHECKSUM_TOTAL_REFS + count))
    RESOURCE_CHECKSUM_TOTAL_REF_FILES=$((RESOURCE_CHECKSUM_TOTAL_REF_FILES + 1))
  done <<< "${match_lines}"
}

# Fail unless the rewrite of <old> to <new> left the tree consistent: <old>
# occurs nowhere, exactly one <kind> document is named <new>, and the other
# marked names in <names> still occur as in <counts-before>.
verify_rename() {
  local tree="$1"
  local kind="$2"
  local old="$3"
  local new="$4"
  local names="$5"
  local counts_before="$6"
  local failed=false

  local left
  left=$(find "${tree}" -type f -name '*.yaml' -exec awk 1 {} + \
    | tr -cs 'a-z0-9.-' '\n' | grep -cxF "${old}" || true)
  if [[ "${left}" -ne 0 ]]; then
    log_error "  '${old}' still occurs ${left} time(s) after renaming it to '${new}'"
    failed=true
  fi

  local named
  named=$(find "${tree}" -type f -name '*.yaml' -exec env KIND="${kind}" NAME="${new}" \
    yq ea 'select(.kind == env(KIND) and .metadata.name == env(NAME)) | .kind' {} + \
    | grep -cxF "${kind}" || true)
  if [[ "${named}" -ne 1 ]]; then
    log_error "  ${named} ${kind} resource(s) named '${new}' after the rename, expected exactly 1"
    failed=true
  fi

  local counts_after
  counts_after=$(marked_name_counts "${tree}" "${names}")
  if [[ "$(grep -v -E " ${old//./\\.}\$" <<< "${counts_before}" || true)" \
      != "$(grep -v -E " ${old//./\\.}\$" <<< "${counts_after}" || true)" ]]; then
    log_error "  Renaming '${old}' changed occurrences of other marked names:"
    log_error "  before: $(tr '\n' ' ' <<< "${counts_before}")"
    log_error "  after:  $(tr '\n' ' ' <<< "${counts_after}")"
    failed=true
  fi

  if ${failed}; then
    return 1
  fi
}

# Hash a Secret template's input set: its raw bytes (no yq, so printer changes
# cannot move the hash), then the base64 of each token's encrypted value in
# token order. No token-name prefixes, so a rename with an unchanged value only
# moves the hash via the template text.
#
# Sets SECRET_HASH and SECRET_TOKEN_COUNT. Returns 1 on error.
checksum_secret_input_set() {
  local tree="$1"
  local template_file="$2"
  local secrets_dir="$3"
  local length="$4"

  # Token order feeds the hash. It sorts on delimited matches: sorting bare
  # names would reorder inputs (${Ab} before ${A}, but Ab after A) and rename
  # existing checksummed Secrets. IgnoreUnresolved-covered tokens have no value.
  local token_regex
  # shellcheck disable=SC2154 # TOKEN_*_STYLE set by the caller
  token_regex=$(unresolved_token_regex "${TOKEN_DELIMITER_STYLE}" "${TOKEN_NAME_STYLE}") || return 1
  local tokens
  tokens=$(token_markers_file_unmarked_tokens "IgnoreUnresolved" "${template_file}" "${token_regex}" "${TOKEN_DELIMITER_STYLE}")

  local rel_path="${template_file#"${tree}"/}"
  local input_blob="${RESOURCE_CHECKSUM_AUDIT_DIR:-${OUTPUT_SUB_PATH:-kaptain-out}/run-finalise/secret-checksum-inputs}/${rel_path}.checksum-input"
  mkdir -p "$(dirname "${input_blob}")"

  cat "${template_file}" > "${input_blob}"

  local tok value_file
  while IFS= read -r tok; do
    [[ -z "${tok}" ]] && continue
    value_file=$(secret_value_file_for_token "${secrets_dir}" "${tok}" || true)
    if [[ -z "${value_file}" || ! -f "${value_file}" ]]; then
      # The substitution gate should already have failed this in all modes.
      log_error "  Secret template ${rel_path} references token '${tok}'"
      log_error "  but no value exists at ${secrets_dir}/${tok}.<type>"
      log_error "  The upstream substitution gate should have failed this build already."
      return 1
    fi
    printf '%s\n' "$(base64 < "${value_file}" | tr -d '\n')" >> "${input_blob}"
  done <<< "${tokens}"

  SECRET_HASH=$(hash_base32 "${input_blob}" "${length}")
  SECRET_TOKEN_COUNT=$(printf '%s' "${tokens}" | grep -c . || true)
}

# See the file header.
# Usage: checksum_tree <tree> <secrets-dir-or-empty> <order-file>
checksum_tree() {
  local tree="$1"
  local secrets_dir="$2"
  local order_file="$3"
  if [[ -z "${tree}" || -z "${order_file}" ]]; then
    log_error "checksum_tree: usage: <tree> <secrets-dir-or-empty> <order-file>"
    return 1
  fi
  if [[ ! -d "${tree}" ]]; then
    log_error "checksum_tree: tree dir not found: ${tree}"
    return 1
  fi
  if [[ ! -f "${order_file}" ]]; then
    log_error "checksum_tree: order file not found: ${order_file}"
    return 1
  fi

  resource_checksum_length || return 1
  local length="${RESOURCE_CHECKSUM_LENGTH}"

  # --- 1. Inventory: file<TAB>kind<TAB>name ---
  local inventory=""
  local warn_lines=""
  local found=0
  local file doc_line doc_kind doc_name own_marker
  while IFS= read -r -d '' file; do
    while IFS= read -r doc_line; do
      doc_kind="${doc_line%%	*}"
      doc_name="${doc_line#*	}"
      [[ -z "${doc_name}" || "${doc_name}" == "null" ]] && continue
      [[ "${doc_name}" != *-checksum ]] && continue
      if [[ "${file}" == *.template.yaml && "${doc_kind}" == "Secret" && -z "${secrets_dir}" ]]; then
        continue
      fi
      own_marker="-$(printf '%s' "${doc_kind}" | tr '[:upper:]' '[:lower:]')-checksum"
      if [[ "${doc_name}" != *"${own_marker}" ]]; then
        warn_lines="${warn_lines}${file#"${tree}"/}: ${doc_kind} '${doc_name}' ends '-checksum' but not '${own_marker}'; assuming legit resource name - not processed
"
        continue
      fi
      inventory="${inventory}${file}	${doc_kind}	${doc_name}
"
      found=$((found + 1))
    done < <(yq ea '(.kind // "") + "	" + (.metadata.name // "")' "${file}" 2>/dev/null || true)
  done < <(resource_checksum_find_yaml "${tree}")

  # Paths logged tree-relative; the step header states the base.
  log "Found ${found} resources with metadata.name -kind-checksum suffix marker:"
  local entry
  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    file="${entry%%	*}"
    log "  ${file#"${tree}"/}: ${entry##*	}"
  done <<< "${inventory}"
  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    log_warning "${entry}"
  done <<< "${warn_lines}"
  log ""

  [[ "${found}" -eq 0 ]] && return 0

  # Every marked name must be a valid Kubernetes name: the rewrite and its
  # checks only work on name characters. All are reported before failing.
  local names=""
  local invalid=0
  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    file="${entry%%	*}"
    doc_name="${entry##*	}"
    if ! is_kubernetes_name "${doc_name}"; then
      log_error "  ${file#"${tree}"/}: '${doc_name}' is not a valid Kubernetes name"
      invalid=$((invalid + 1))
    fi
    names="${names}${doc_name}
"
  done <<< "${inventory}"
  if [[ "${invalid}" -gt 0 ]]; then
    log_error "${invalid} checksum-marked name(s) invalid; names are lowercase a-z, 0-9, '-' and '.'"
    return 1
  fi

  local processed_keys=""
  local kind_lc marker old_name new_name hash tmp_doc doc_index doc_count counts_before

  # --- 2. Secret templates ---
  if [[ -n "${secrets_dir}" ]]; then
    while IFS= read -r entry; do
      [[ -z "${entry}" ]] && continue
      file="${entry%%	*}"
      doc_kind=$(printf '%s' "${entry}" | cut -f2)
      old_name="${entry##*	}"
      [[ "${file}" != *.template.yaml || "${doc_kind}" != "Secret" ]] && continue

      checksum_secret_input_set "${tree}" "${file}" "${secrets_dir}" "${length}" || return 1
      processed_keys="${processed_keys}${file}	${old_name}
"
      new_name="${old_name%-secret-checksum}-${SECRET_HASH}"
      log "Processing ${file#"${tree}"/}:"
      log "  ${old_name} -> ${new_name} (input set: template + ${SECRET_TOKEN_COUNT} token value(s))"
      RESOURCE_CHECKSUM_TOTAL_RESOURCES=$((RESOURCE_CHECKSUM_TOTAL_RESOURCES + 1))
      counts_before=$(marked_name_counts "${tree}" "${names}")
      rewrite_name_refs "${tree}" "${old_name}" "${new_name}" || return 1
      verify_rename "${tree}" "Secret" "${old_name}" "${new_name}" "${names}" "${counts_before}" || return 1
      log ""
    done <<< "${inventory}"
  fi

  # --- 3. Remaining kinds in order-file sequence ---
  local kind
  while IFS= read -r kind; do
    kind="${kind%%#*}"
    kind="${kind## }"
    kind="${kind%% }"
    [[ -z "${kind}" ]] && continue
    kind_lc=$(printf '%s' "${kind}" | tr '[:upper:]' '[:lower:]')
    marker="-${kind_lc}-checksum"

    while IFS= read -r entry; do
      [[ -z "${entry}" ]] && continue
      file="${entry%%	*}"
      doc_kind=$(printf '%s' "${entry}" | cut -f2)
      old_name="${entry##*	}"
      [[ "${doc_kind}" != "${kind}" ]] && continue
      [[ "${file}" == *.template.yaml && "${doc_kind}" == "Secret" ]] && continue
      # Defensive; inventory entries are unique.
      case "${processed_keys}" in *"${file}	${old_name}"*) continue ;; esac
      # The inventory guarantees old_name ends "${marker}".

      # Hash the current document: earlier rewrites may have changed it.
      doc_count=$(yq ea '[.] | length' "${file}")
      doc_index=0
      while [[ "${doc_index}" -lt "${doc_count}" ]]; do
        doc_kind=$(DOC_INDEX="${doc_index}" yq ea 'select(document_index == (env(DOC_INDEX) | tonumber)) | .kind // ""' "${file}")
        doc_name=$(DOC_INDEX="${doc_index}" yq ea 'select(document_index == (env(DOC_INDEX) | tonumber)) | .metadata.name // ""' "${file}")
        if [[ "${doc_kind}" == "${kind}" && "${doc_name}" == "${old_name}" ]]; then
          break
        fi
        doc_index=$((doc_index + 1))
      done
      if [[ "${doc_index}" -ge "${doc_count}" ]]; then
        log_error "checksum_tree: inventoried ${kind} '${old_name}' no longer found in ${file#"${tree}"/}"
        return 1
      fi

      tmp_doc=$(mktemp)
      yq "select(di == ${doc_index})" "${file}" > "${tmp_doc}"
      hash=$(hash_base32 "${tmp_doc}" "${length}")
      rm -f "${tmp_doc}"
      new_name="${old_name%"${marker}"}-${hash}"

      log "Processing ${file#"${tree}"/}:"
      log "  ${old_name} -> ${new_name}"
      RESOURCE_CHECKSUM_TOTAL_RESOURCES=$((RESOURCE_CHECKSUM_TOTAL_RESOURCES + 1))
      processed_keys="${processed_keys}${file}	${old_name}
"
      counts_before=$(marked_name_counts "${tree}" "${names}")
      rewrite_name_refs "${tree}" "${old_name}" "${new_name}" || return 1
      verify_rename "${tree}" "${kind}" "${old_name}" "${new_name}" "${names}" "${counts_before}" || return 1
      log ""
    done <<< "${inventory}"
  done < "${order_file}"

  # --- 4. Fail on unprocessed marked resources ---
  local leftovers=0
  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    file="${entry%%	*}"
    doc_kind=$(printf '%s' "${entry}" | cut -f2)
    old_name="${entry##*	}"
    case "${processed_keys}" in *"${file}	${old_name}"*) continue ;; esac
    log_error "  ${file#"${tree}"/}: ${doc_kind} '${old_name}' is checksum-marked but was never processed"
    log_error "  (kind missing from ${order_file}, or a marked Secret outside *.template.yaml)"
    leftovers=$((leftovers + 1))
  done <<< "${inventory}"
  if [[ "${leftovers}" -gt 0 ]]; then
    log_error "${leftovers} marked resource(s) left unprocessed."
    return 1
  fi
}
