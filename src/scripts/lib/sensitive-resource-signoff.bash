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
# Layout: the signoff path mirrors the manifest's path in the assembled
# tree, env-root segment stripped, regardless of where the manifest came
# from (local src/kubernetes, apps, bundles, products). <signoffs-dir> comes
# from the signoffsSubPath setting; trustedContributorsOnly=true at the
# entrypoint skips the check.
#
# Example: a manifest at  <tree>/run-foo/widgets/extra/gateway.yaml
# expects its signoff at  <signoffs-dir>/widgets/extra/gateway.yaml
#
# Signoff file shape (YAML):
#
#   sourcePath:       widgets/extra/gateway.yaml
#   checksum:         sha256:<hex>
#   relatedManifests:                        # optional, informational
#     - widgets/extra/httproute.yaml
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
# SIGNOFF_SKELETON_DIR (optional env): when set, each missing or mismatched
# signoff also gets a review-ready skeleton (sourcePath + canonical
# checksum) at <SIGNOFF_SKELETON_DIR>/<sourcePath>.

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

# The tree's first segment is the run/RP project name (env root).
#
# Usage: signoff_source_path <manifests-dir> <manifest-file>
signoff_source_path() {
  local manifests_dir="$1"
  local file="$2"
  local rel="${file#"${manifests_dir}/"}"
  case "${rel}" in
    */*) echo "${rel#*/}" ;;
    *)   echo "${rel}" ;;
  esac
}

# Must not survive into a committed signoff. Header 2 is completed per file.
SIGNOFF_SKELETON_HEADER_1="# Generated signoff skeleton - REVIEW THE RESOURCE FIRST."
SIGNOFF_SKELETON_HEADER_2_PREFIX="# Once reviewed, copy this file to: "
SIGNOFF_SKELETON_HEADER_3="# Remove these three lines, and fill in or remove the reference line: left in, they fail the build."
SIGNOFF_SKELETON_REFERENCE_PLACEHOLDER="# reference: <review ticket/PR reference>"

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
  log_error "  skeleton written:   ${skeleton_file}"
}

# Tracked and identical to HEAD. False outside a git work tree.
signoff_file_committed() {
  local file="$1"
  git ls-files --error-unmatch -- "${file}" > /dev/null 2>&1 \
    && git diff --quiet HEAD -- "${file}" 2> /dev/null
}

# Local builds only warn while the file is uncommitted or modified, so a
# signoff in progress does not block iteration.
#
# Usage: signoff_check_content <signoff-file>
signoff_check_content() {
  local signoff_file="$1"
  local problems=()

  local line
  for line in "${SIGNOFF_SKELETON_HEADER_1}" \
              "${SIGNOFF_SKELETON_HEADER_2_PREFIX}${signoff_file}" \
              "${SIGNOFF_SKELETON_HEADER_3}" \
              "${SIGNOFF_SKELETON_REFERENCE_PLACEHOLDER}"; do
    if grep -qxF -- "${line}" "${signoff_file}"; then
      problems+=("leftover skeleton line: ${line}")
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
  if [[ "${server}" == "true" ]] || signoff_file_committed "${signoff_file}"; then
    log_error "Signoff file needs attention: ${signoff_file}"
    for problem in "${problems[@]}"; do
      log_error "  ${problem}"
    done
    return 1
  fi
  log_warning "Signoff file needs attention before it is committed: ${signoff_file}"
  for problem in "${problems[@]}"; do
    log_warning "  ${problem}"
  done
  return 0
}

# Usage: signoff_verify_file <manifests-dir> <signoffs-dir> <manifest-file>
signoff_verify_file() {
  local manifests_dir="$1"
  local signoffs_dir="$2"
  local manifest="$3"

  local source_path
  source_path=$(signoff_source_path "${manifests_dir}" "${manifest}")
  local signoff_file="${signoffs_dir}/${source_path}"

  if [[ ! -f "${signoff_file}" ]]; then
    local actual_hash
    actual_hash=$(signoff_canonical_hash "${manifest}") || return 1
    log_error "Sensitive resource has no signoff:"
    log_error "  manifest:           ${manifest}"
    log_error "  source path:        ${source_path}"
    log_error "  expected at:        ${signoff_file}"
    log_error "  canonical checksum: sha256:${actual_hash}"
    signoff_write_skeleton "${source_path}" "${signoff_file}" "${actual_hash}"
    return 1
  fi

  local content_failed="false"
  signoff_check_content "${signoff_file}" || content_failed="true"

  local actual expected
  actual=$(signoff_canonical_hash "${manifest}") || return 1
  expected=$(yq -r '.checksum // ""' "${signoff_file}")
  expected="${expected#sha256:}"

  if [[ -z "${expected}" ]]; then
    log_error "Signoff file is missing 'checksum' field: ${signoff_file}"
    return 1
  fi

  if [[ "${actual}" != "${expected}" ]]; then
    log_error "Signoff checksum mismatch:"
    log_error "  manifest: ${manifest}"
    log_error "  signoff:  ${signoff_file}"
    log_error "  expected: sha256:${expected}"
    log_error "  actual:   sha256:${actual}"
    log_error "Resource has changed since sign-off. Re-review and update the"
    log_error "checksum field in the signoff file."
    signoff_write_skeleton "${source_path}" "${signoff_file}" "${actual}"
    return 1
  fi

  [[ "${content_failed}" == "true" ]] && return 1
  log "  OK  ${source_path}"
}

# Stale signoffs: no matching sensitive resource in the tree.
signoff_find_stale() {
  local signoffs_dir="$1"
  local consumed_index="$2"

  [[ -d "${signoffs_dir}" ]] || return 0

  local file rel
  local stale=()
  while IFS= read -r -d '' file; do
    rel="${file#"${signoffs_dir}/"}"
    if ! grep -qxF "${rel}" "${consumed_index}"; then
      stale+=("${file}")
    fi
  done < <(find "${signoffs_dir}" -type f -name '*.yaml' -print0)

  if (( ${#stale[@]} > 0 )); then
    log_error "Stale signoff(s) - no matching sensitive resource in the assembled tree:"
    local entry
    for entry in "${stale[@]}"; do
      log_error "  ${entry}"
    done
    log_error "Delete the file if the resource was intentionally removed, or"
    log_error "investigate why the resource is no longer present."
    return 1
  fi
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
  log "Sensitive kinds in effect (${kinds_file}):"
  local k
  while IFS= read -r k; do
    log "  - ${k}"
  done <<< "${kinds_pattern}"
  log ""

  local consumed_index="${manifests_dir}/.signoff-consumed"
  : > "${consumed_index}"

  log "Scanning ${manifests_dir} for sensitive resources..."
  local sensitive_files
  sensitive_files=$(signoff_find_sensitive_files "${manifests_dir}" "${kinds_pattern}")
  if [[ -z "${sensitive_files}" ]]; then
    log "  None found."
  fi

  local failed=0
  local manifest source_path
  while IFS= read -r manifest; do
    [[ -z "${manifest}" ]] && continue
    source_path=$(signoff_source_path "${manifests_dir}" "${manifest}")
    printf '%s\n' "${source_path}" >> "${consumed_index}"
    if ! signoff_verify_file "${manifests_dir}" "${signoffs_dir}" "${manifest}"; then
      failed=$((failed + 1))
    fi
  done <<< "${sensitive_files}"

  log ""
  if ! signoff_find_stale "${signoffs_dir}" "${consumed_index}"; then
    failed=$((failed + 1))
  fi

  if (( failed > 0 )); then
    log_error ""
    log_error "${failed} signoff problem(s) detected."
    if [[ -n "${SIGNOFF_SKELETON_DIR:-}" ]]; then
      log_error "Review-ready skeletons for missing and changed signoffs were written under:"
      log_error "  ${SIGNOFF_SKELETON_DIR}/"
      log_error "Review each resource, then copy its skeleton into ${signoffs_dir}/."
    fi
    return 1
  fi
  log "Signoff check passed."
}
