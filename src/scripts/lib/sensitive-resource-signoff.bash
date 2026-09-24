#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# sensitive-resource-signoff.bash - Verify each sensitive K8s resource in
# the assembled manifest tree has a matching checked-in signoff.
#
# Sensitive kinds (Ingress, Gateway, RBAC, webhook configurations, etc.)
# can introduce privilege escalation, data exfiltration, or traffic
# redirection when aggregated into an env or run-platform unreviewed.
#
# Layout: the signoffs dir mirrors the manifest tree exactly, so a child's or
# product's own folder is part of the path and two children cannot share a
# signoff. <signoffs-dir> comes from the signoffsSubPath setting;
# trustedContributorsOnly=true at the entrypoint skips the check.
#
# Example: a manifest at  <tree>/shop/billing/ingress.yaml
# expects its signoff at  <signoffs-dir>/shop/billing/ingress.yaml
#
# Signoff file shape (YAML):
#
#   sourcePath:       shop/billing/ingress.yaml
#   checksum:         sha256:<hex>
#   relatedManifests:                        # optional, informational
#     - shop/billing/httproute.yaml
#   reviewer:         fred                   # optional, informational
#   signoffTimestamp: 2026-09-26T01:00:00Z   # optional, informational
#   reference:        KAP-1234               # optional, informational
#
# reviewer and signoffTimestamp are required on server builds
# (BUILD_MODE=build_server). signoffTimestamp must be ISO 8601 with a zone.
# Leftover skeleton header and placeholder lines fail server builds, and
# local builds once the file is committed unchanged (local builds warn
# while it is uncommitted).
#
# Granularity: per manifest file; a multi-doc YAML file is one unit.
# Per-doc signoff would need a synthetic identifier.
#
# Canonicalisation: the hash excludes build-injected provenance and
# integration metadata so it tracks resource content only.
# Stripped keys:
#   metadata.annotations: our provenance annotations by exact name
#     (kaptain.org/ build-timestamp built-by generated-by git-sha
#     helm-upstream-chart image-uri source-repository), and ^keel.sh/
#     ^keelson.io/
#   metadata.labels      matching ^kaptain.org/version$ ^app.kubernetes.io/version$
#   metadata.creationTimestamp / resourceVersion / uid / generation /
#   managedFields, and status
# The same stripping applies to spec.template.metadata where present
# (pod templates carry the rollout-trigger annotations).
#
# Our annotations are listed by name so the check fails safe: a new
# kaptain.org/ annotation is hashed, and so reviewed, until added here.
#
# Failure modes:
#   - Sensitive resource with no signoff.
#   - Checksum mismatch (resource changed; re-review).
#   - Signoff with no matching sensitive resource (stale).
#
# Functions:
#   signoff_check_tree <manifests-dir> <signoffs-dir> [<sensitive-kinds-file>]
#       Top-level. Validates coverage and integrity against the signoffs.
#
#   signoff_canonical_hash <manifest-file>
#       Print the canonical hash (hex SHA-256, no prefix).
#
# <sensitive-kinds-file>: one Kind per line, '#' comments. Mapped by the
# caller from spec.main.environment.sensitiveResourceKinds (or
# src/config/SensitiveResourceKinds).
#
# Output: one status line per resource (OK, MISSING, CHANGED, INVALID,
# PENDING, STALE) relative to the dirs named once at the top, then what to do,
# then a single error line with the counts.
#
# SIGNOFF_SKELETON_DIR (optional env): when set, each missing, changed or
# invalid signoff also gets a review-ready skeleton (sourcePath + canonical
# checksum) at <SIGNOFF_SKELETON_DIR>/<sourcePath>.
#
# SIGNOFF_MERGED_DIR (optional env, needs SIGNOFF_SKELETON_DIR): on failure,
# the whole signoffs dir with those skeletons in place and stale signoffs
# removed, ready to replace the source dir after review.
#
# Both dirs are emptied at the start of each check.

# shellcheck disable=SC2034 # Public function output vars are read by callers.

# Kind lists ship as versioned-immutable data
# (src/data/signoff-kinds/<name>-<version>.txt). The selected file is the
# whole list (no merge).

# Not `(.x // {}) |= with_entries(...)`: yq leaves `x: null` for an absent
# x but `x: {}` when only stripped keys existed, giving different hashes.
# The assignment form normalises both to {}.
SIGNOFF_STRIP_ANNOTATION_KEEP='(.key | test("^(kaptain\\.org/(build-timestamp|built-by|generated-by|git-sha|helm-upstream-chart|image-uri|source-repository)$|keel\\.sh/|keelson\\.io/)")) | not'
SIGNOFF_STRIP_LABEL_KEEP='(.key != "kaptain.org/version") and (.key != "app.kubernetes.io/version")'
SIGNOFF_STRIP_EXPR="
  .metadata.annotations = ((.metadata.annotations // {}) | with_entries(select(${SIGNOFF_STRIP_ANNOTATION_KEEP})))
  | .metadata.labels = ((.metadata.labels // {}) | with_entries(select(${SIGNOFF_STRIP_LABEL_KEEP})))
  | del(.metadata.creationTimestamp,
        .metadata.resourceVersion,
        .metadata.uid,
        .metadata.generation,
        .metadata.managedFields,
        .status)
  | with(select(.spec.template != null).spec.template;
      .metadata.annotations = ((.metadata.annotations // {}) | with_entries(select(${SIGNOFF_STRIP_ANNOTATION_KEEP})))
      | .metadata.labels = ((.metadata.labels // {}) | with_entries(select(${SIGNOFF_STRIP_LABEL_KEEP}))))
"

# Duplicates checksum-resolve.bash so this library sources standalone.
signoff_sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    log_error "No SHA-256 tool found (sha256sum or shasum required)"
    return 1
  fi
}

# Usage: signoff_canonical_hash <manifest-file>
signoff_canonical_hash() {
  if [[ $# -ne 1 ]]; then
    log_error "signoff_canonical_hash requires exactly 1 argument, got $#"
    return 1
  fi
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    log_error "Manifest file not found: ${file}"
    return 1
  fi
  yq eval-all "${SIGNOFF_STRIP_EXPR}" -o=json "${file}" \
    | jq -cS '.' \
    | signoff_sha256_hex
}

# A missing file is fatal so the gate cannot run with an empty list.
signoff_load_kinds() {
  local kinds_file="${1:-}"
  if [[ -z "${kinds_file}" || ! -f "${kinds_file}" ]]; then
    log_error "signoff_load_kinds: kinds file not found: ${kinds_file:-<empty>}"
    return 1
  fi
  awk 'NF && $1 !~ /^#/ { gsub(/^[ \t]+|[ \t]+$/, "", $0); print }' "${kinds_file}"
}

# Dot-files are index files written by neighbouring libraries.
signoff_find_sensitive_files() {
  local manifests_dir="$1"
  local kinds_pattern="$2"

  local file kinds matched
  while IFS= read -r -d '' file; do
    case "$(basename "${file}")" in
      .*) continue ;;
    esac
    kinds=$(yq eval-all '.kind // ""' "${file}" 2>/dev/null | LC_ALL=C sort -u | grep -v '^$' || true)
    [[ -z "${kinds}" ]] && continue
    matched=false
    local k
    while IFS= read -r k; do
      [[ -z "${k}" ]] && continue
      if grep -qxF "${k}" <<< "${kinds_pattern}"; then
        matched=true
        break
      fi
    done <<< "${kinds}"
    if [[ "${matched}" == "true" ]]; then
      printf '%s\n' "${file}"
    fi
  done < <(find "${manifests_dir}" -type f -name '*.yaml' -print0)
  # Without this, a non-sensitive last file returns 1 and kills set -e callers.
  return 0
}

# Usage: signoff_source_path <manifests-dir> <manifest-file>
signoff_source_path() {
  local manifests_dir="$1"
  local file="$2"
  echo "${file#"${manifests_dir}/"}"
}

# Must not survive into a committed signoff. Header 2 is completed per file.
SIGNOFF_SKELETON_HEADER_1="# Generated signoff skeleton - REVIEW THE RESOURCE FIRST."
SIGNOFF_SKELETON_HEADER_2_PREFIX="# Once reviewed, copy this file to: "
SIGNOFF_SKELETON_HEADER_3="# Remove these three lines, and fill in or remove the reference line: left in, they fail the build."
SIGNOFF_SKELETON_REFERENCE_PLACEHOLDER="# reference: <review ticket/PR reference>"

# Source paths this run wrote skeletons for, and stale signoffs it found
# (signoffs-dir relative). signoff_write_merged builds from these, not from
# whatever an earlier run left in the skeleton dir.
SIGNOFF_SKELETONS_WRITTEN=()
SIGNOFF_STALE=()

SIGNOFF_TIMESTAMP_PATTERN='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|[+-][0-9]{2}:?[0-9]{2})$'

# Usage: signoff_write_skeleton <source-path> <signoff-file> <canonical-hash>
signoff_write_skeleton() {
  local source_path="$1"
  local signoff_file="$2"
  local actual_hash="$3"
  [[ -n "${SIGNOFF_SKELETON_DIR:-}" ]] || return 0
  local skeleton_file="${SIGNOFF_SKELETON_DIR}/${source_path}"
  mkdir -p "$(dirname "${skeleton_file}")"
  local reviewer
  reviewer=$(git config user.name 2>/dev/null || true)
  {
    echo "${SIGNOFF_SKELETON_HEADER_1}"
    echo "${SIGNOFF_SKELETON_HEADER_2_PREFIX}${signoff_file}"
    echo "${SIGNOFF_SKELETON_HEADER_3}"
    echo "sourcePath: ${source_path}"
    echo "checksum: sha256:${actual_hash}"
    if [[ -n "${reviewer}" ]]; then
      # JSON quoting is valid YAML and safe for any name.
      echo "reviewer: $(printf '%s' "${reviewer}" | jq -Rr '@json')"
    else
      echo "# reviewer: <who reviewed it>"
    fi
    echo "signoffTimestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "${SIGNOFF_SKELETON_REFERENCE_PLACEHOLDER}"
  } > "${skeleton_file}"
  SIGNOFF_SKELETONS_WRITTEN+=("${source_path}")
}

# The signoffs dir as it should be after review, so it can replace the source
# dir wholesale: the existing signoffs, stale ones dropped, and this run's
# skeletons laid over the missing and changed ones. Other files in the source
# dir are kept. The skeleton header lines still fail the build until removed.
#
# Usage: signoff_write_merged <signoffs-dir>
signoff_write_merged() {
  local signoffs_dir="$1"
  local merged="${SIGNOFF_MERGED_DIR}"
  rm -rf "${merged}"
  mkdir -p "${merged}"
  if [[ -d "${signoffs_dir}" ]]; then
    cp -R "${signoffs_dir}/." "${merged}/"
  fi
  local rel
  for rel in "${SIGNOFF_STALE[@]+"${SIGNOFF_STALE[@]}"}"; do
    rm -f "${merged}/${rel}"
  done
  for rel in "${SIGNOFF_SKELETONS_WRITTEN[@]+"${SIGNOFF_SKELETONS_WRITTEN[@]}"}"; do
    mkdir -p "$(dirname "${merged}/${rel}")"
    cp "${SIGNOFF_SKELETON_DIR}/${rel}" "${merged}/${rel}"
  done
  # Directories only stale signoffs lived in would otherwise survive empty.
  find "${merged}" -mindepth 1 -type d -empty -delete
}

# Tracked and identical to HEAD. False outside a git work tree.
signoff_file_committed() {
  local file="$1"
  git ls-files --error-unmatch -- "${file}" > /dev/null 2>&1 \
    && git diff --quiet HEAD -- "${file}" 2> /dev/null
}

# Local builds only flag the file as pending while it is uncommitted or
# modified, so a signoff in progress does not block iteration.
#
# Sets SIGNOFF_CONTENT_STATE (ok | fail | pending) and SIGNOFF_CONTENT_DETAIL
# (the problems, '; ' separated). Logs nothing: the caller reports.
#
# Usage: signoff_check_content <signoff-file>
signoff_check_content() {
  local signoff_file="$1"
  local problems=()
  SIGNOFF_CONTENT_STATE="ok"
  SIGNOFF_CONTENT_DETAIL=""

  local line
  for line in "${SIGNOFF_SKELETON_HEADER_1}" \
              "${SIGNOFF_SKELETON_HEADER_2_PREFIX}${signoff_file}" \
              "${SIGNOFF_SKELETON_HEADER_3}" \
              "${SIGNOFF_SKELETON_REFERENCE_PLACEHOLDER}"; do
    if grep -qxF -- "${line}" "${signoff_file}"; then
      problems+=("leftover skeleton lines")
      break
    fi
  done

  local reviewer timestamp
  reviewer=$(yq -r '.reviewer // ""' "${signoff_file}")
  timestamp=$(yq -r '.signoffTimestamp // ""' "${signoff_file}")
  if [[ -n "${timestamp}" && ! "${timestamp}" =~ ${SIGNOFF_TIMESTAMP_PATTERN} ]]; then
    problems+=("signoffTimestamp '${timestamp}' is not an ISO 8601 date and time with a zone (Z or an offset)")
  fi

  local server="false"
  [[ "${BUILD_MODE:-}" == "build_server" ]] && server="true"
  if [[ "${server}" == "true" ]]; then
    [[ -z "${reviewer}" ]] && problems+=("reviewer is required on server builds")
    [[ -z "${timestamp}" ]] && problems+=("signoffTimestamp is required on server builds")
  fi

  [[ ${#problems[@]} -eq 0 ]] && return 0

  local problem
  for problem in "${problems[@]}"; do
    SIGNOFF_CONTENT_DETAIL="${SIGNOFF_CONTENT_DETAIL:+${SIGNOFF_CONTENT_DETAIL}; }${problem}"
  done
  if [[ "${server}" == "true" ]] || signoff_file_committed "${signoff_file}"; then
    SIGNOFF_CONTENT_STATE="fail"
  else
    SIGNOFF_CONTENT_STATE="pending"
  fi
}

# Sets SIGNOFF_STATUS (OK | PENDING | MISSING | CHANGED | INVALID) and
# SIGNOFF_DETAIL (reason, may be empty). Every failing status gets a skeleton
# at the current canonical checksum. Logs nothing: the caller reports.
# Returns 1 only when the hash cannot be computed.
#
# Usage: signoff_verify_file <manifests-dir> <signoffs-dir> <manifest-file>
signoff_verify_file() {
  local manifests_dir="$1"
  local signoffs_dir="$2"
  local manifest="$3"
  SIGNOFF_STATUS=""
  SIGNOFF_DETAIL=""

  local source_path
  source_path=$(signoff_source_path "${manifests_dir}" "${manifest}")
  local signoff_file="${signoffs_dir}/${source_path}"

  local actual
  actual=$(signoff_canonical_hash "${manifest}") || return 1

  if [[ ! -f "${signoff_file}" ]]; then
    SIGNOFF_STATUS="MISSING"
  else
    signoff_check_content "${signoff_file}"
    local expected
    expected=$(yq -r '.checksum // ""' "${signoff_file}")
    expected="${expected#sha256:}"
    if [[ -z "${expected}" ]]; then
      SIGNOFF_STATUS="INVALID"
      SIGNOFF_DETAIL="no checksum field"
    elif [[ "${actual}" != "${expected}" ]]; then
      SIGNOFF_STATUS="CHANGED"
    elif [[ "${SIGNOFF_CONTENT_STATE}" == "fail" ]]; then
      SIGNOFF_STATUS="INVALID"
      SIGNOFF_DETAIL="${SIGNOFF_CONTENT_DETAIL}"
    elif [[ "${SIGNOFF_CONTENT_STATE}" == "pending" ]]; then
      SIGNOFF_STATUS="PENDING"
      SIGNOFF_DETAIL="${SIGNOFF_CONTENT_DETAIL}; fails once committed"
      return 0
    else
      SIGNOFF_STATUS="OK"
      return 0
    fi
  fi
  signoff_write_skeleton "${source_path}" "${signoff_file}" "${actual}"
}

# Stale signoffs: no matching sensitive resource in the tree. Collected into
# SIGNOFF_STALE (signoffs-dir relative); the caller reports.
signoff_find_stale() {
  local signoffs_dir="$1"
  local consumed_index="$2"

  [[ -d "${signoffs_dir}" ]] || return 0

  local file rel
  while IFS= read -r -d '' file; do
    rel="${file#"${signoffs_dir}/"}"
    if ! grep -qxF "${rel}" "${consumed_index}"; then
      SIGNOFF_STALE+=("${rel}")
    fi
  done < <(find "${signoffs_dir}" -type f -name '*.yaml' -print0 | LC_ALL=C sort -z)
}

# Join words as 'a', 'a and b', 'a, b and c'.
signoff_join_and() {
  local out=""
  local i=1
  local word
  for word in "$@"; do
    if [[ ${i} -eq 1 ]]; then
      out="${word}"
    elif [[ ${i} -eq $# ]]; then
      out="${out} and ${word}"
    else
      out="${out}, ${word}"
    fi
    i=$((i + 1))
  done
  printf '%s' "${out}"
}

# Usage: signoff_check_tree <manifests-dir> <signoffs-dir> <sensitive-kinds-file>
signoff_check_tree() {
  if [[ $# -ne 3 ]]; then
    log_error "Usage: signoff_check_tree <manifests-dir> <signoffs-dir> <sensitive-kinds-file>"
    return 1
  fi
  local manifests_dir="$1"
  local signoffs_dir="$2"
  local kinds_file="$3"

  if [[ ! -d "${manifests_dir}" ]]; then
    log_error "Manifests directory not found: ${manifests_dir}"
    return 1
  fi
  # Also checked here: signoff_load_kinds runs in a command substitution,
  # which swallows its error message.
  if [[ ! -f "${kinds_file}" ]]; then
    log_error "Sensitive-kinds file not found: ${kinds_file}"
    return 1
  fi
  for tool in yq jq; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      log_error "${tool} is required for signoff_check_tree"
      return 1
    fi
  done

  local kinds_pattern
  kinds_pattern=$(signoff_load_kinds "${kinds_file}") || return 1
  local kinds_path
  kinds_path="$(cd "$(dirname "${kinds_file}")" && pwd)/$(basename "${kinds_file}")"

  local consumed_index="${manifests_dir}/.signoff-consumed"
  : > "${consumed_index}"

  # Output of an earlier run would otherwise mix into this one's.
  SIGNOFF_SKELETONS_WRITTEN=()
  SIGNOFF_STALE=()
  [[ -n "${SIGNOFF_SKELETON_DIR:-}" ]] && rm -rf "${SIGNOFF_SKELETON_DIR}"
  [[ -n "${SIGNOFF_MERGED_DIR:-}" ]] && rm -rf "${SIGNOFF_MERGED_DIR}"

  local sensitive_files
  sensitive_files=$(signoff_find_sensitive_files "${manifests_dir}" "${kinds_pattern}")
  local total
  total=$(grep -c . <<< "${sensitive_files}" || true)

  # Where everything lives, once; every line below is a sub path of these.
  log "Signoff check: ${total} sensitive resource(s) in ${manifests_dir}/"
  log "Sensitive kinds checked are listed in ${kinds_path}"
  log "Signoffs read from ${signoffs_dir}/"
  log "Paths below are relative to those dirs."
  log ""

  local missing=0 changed=0 invalid=0 pending=0
  local manifest source_path line
  while IFS= read -r manifest; do
    [[ -z "${manifest}" ]] && continue
    source_path=$(signoff_source_path "${manifests_dir}" "${manifest}")
    printf '%s\n' "${source_path}" >> "${consumed_index}"
    signoff_verify_file "${manifests_dir}" "${signoffs_dir}" "${manifest}" || return 1
    case "${SIGNOFF_STATUS}" in
      MISSING) missing=$((missing + 1)) ;;
      CHANGED) changed=$((changed + 1)) ;;
      INVALID) invalid=$((invalid + 1)) ;;
      PENDING) pending=$((pending + 1)) ;;
    esac
    line=$(printf '  %-7s  %s' "${SIGNOFF_STATUS}" "${source_path}")
    log "${line}${SIGNOFF_DETAIL:+ (${SIGNOFF_DETAIL})}"
  done <<< "${sensitive_files}"

  signoff_find_stale "${signoffs_dir}" "${consumed_index}"
  local stale=${#SIGNOFF_STALE[@]}
  local rel
  for rel in "${SIGNOFF_STALE[@]+"${SIGNOFF_STALE[@]}"}"; do
    log "$(printf '  %-7s  %s' "STALE" "${rel}")"
  done
  log ""

  local failed_resources=$((missing + changed + invalid))
  if (( failed_resources == 0 && stale == 0 )); then
    if (( pending > 0 )); then
      log_warning "Signoff check passed, ${pending} signoff(s) pending cleanup before commit."
    else
      log "Signoff check passed: ${total} of ${total} sensitive resource(s) signed off."
    fi
    return 0
  fi

  # What to do, as plain lines; the one error comes last.
  local statuses=() counts=()
  if (( missing > 0 )); then
    statuses+=("MISSING")
    counts+=("${missing} missing")
  fi
  if (( changed > 0 )); then
    statuses+=("CHANGED")
    counts+=("${changed} changed")
  fi
  if (( invalid > 0 )); then
    statuses+=("INVALID")
    counts+=("${invalid} invalid")
  fi
  if (( failed_resources > 0 )); then
    if [[ -n "${SIGNOFF_SKELETON_DIR:-}" ]]; then
      log "Review each $(signoff_join_and "${statuses[@]}") entry in ${SIGNOFF_SKELETON_DIR}/ and add if appropriate."
    else
      log "Review each $(signoff_join_and "${statuses[@]}") entry and add a signoff for it under ${signoffs_dir}/."
    fi
  fi
  if (( stale > 0 )); then
    log "Delete each STALE signoff from ${signoffs_dir}/ if its resource was removed on purpose."
  fi
  if [[ -n "${SIGNOFF_SKELETON_DIR:-}" && -n "${SIGNOFF_MERGED_DIR:-}" ]]; then
    signoff_write_merged "${signoffs_dir}"
    if (( stale > 0 )); then
      log "To accept them all once reviewed (stale ones are already left out):"
    else
      log "To accept them all once reviewed:"
    fi
    log "  rm -r ${signoffs_dir} && mv ${SIGNOFF_MERGED_DIR} ${signoffs_dir}"
    if (( failed_resources > 0 )); then
      log "Then remove the three generated comment lines from each new signoff and fill in or remove its reference line; left in, they fail the build."
    fi
  fi

  local count_text
  count_text=$(signoff_join_and "${counts[@]+"${counts[@]}"}")
  if (( stale == 0 )); then
    log_error "${failed_resources} of ${total} sensitive resource(s) failed the signoff check (${count_text}). See the list above."
  elif (( failed_resources == 0 )); then
    log_error "${stale} signoff(s) in ${signoffs_dir}/ match no sensitive resource (${stale} stale). See the list above."
  else
    log_error "$((failed_resources + stale)) signoff problem(s): ${failed_resources} of ${total} sensitive resource(s) failed (${count_text}), ${stale} stale signoff(s). See the list above."
  fi
  return 1
}
