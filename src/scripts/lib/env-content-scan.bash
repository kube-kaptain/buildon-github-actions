#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# env-content-scan.bash - Emit content-data.yaml (EnvContentData.md) from the
# kaptain.org/* provenance annotations in a substituted env workload tree:
#
#   apiVersion: kaptain.org/content-data/1
#   kind: environment | run-platform
#   name: <env or RP name>
#   version: <env or RP version>
#   children:
#     - kind: app|bundle|product
#       name: <project-name>
#       version: <kaptain.org/version>
#       versionSpec: <kaptain.org/version-spec>
#       origin:
#         url: <kaptain.org/origin-url>
#         revision: <kaptain.org/origin-revision>
#         registry: <kaptain.org/origin-registry>
#       workloads:
#         - name: <metadata.name>
#           kind: <Deployment|Job|...>
#           namespace: <metadata.namespace || "">
#           sourcePath: <path-rel-to-tree>
#
# Run after the resource-checksum pass so workload names carry their final
# suffixes.
#
# Function:
#   env_content_scan_tree <tree> <doc-kind> <name> <version> <out-file>
#       <doc-kind>: environment | run-platform
#
# Required tools: yq 4, find.

# EnvContentData.md §3 allowlist. Extend when workload CRDs (Rollout, etc.)
# are adopted.
ENV_CONTENT_SCAN_WORKLOAD_KINDS_REGEX='^(Deployment|StatefulSet|DaemonSet|ReplicaSet|Job|CronJob|Pod)$'

# Name heuristic until a kaptain.org/build-kind annotation is reliable across
# all build flows.
env_content_scan_classify_child() {
  local name="$1"
  case "${name}" in
    product-*|*-product) echo "product" ;;
    vendor-*|bundle-*)   echo "bundle" ;;
    *)                   echo "app" ;;
  esac
}

env_content_scan_anno() {
  local file="$1" doc_index="$2" key="$3"
  local val
  val=$(yq "select(di == ${doc_index}) | .metadata.annotations.\"kaptain.org/${key}\" // \"\"" "${file}" 2>/dev/null)
  [[ "${val}" == "null" ]] && val=""
  echo "${val}"
}

env_content_scan_emit_field() {
  local out="$1" indent="$2" key="$3" value="$4"
  [[ -z "${value}" ]] && return 0
  printf '%*s%s: %s\n' "${indent}" '' "${key}" "${value}" >> "${out}"
}

env_content_scan_tree() {
  local tree="$1"
  local doc_kind="$2"
  local name="$3"
  local version="$4"
  local out_file="$5"

  if [[ -z "${tree}" || -z "${doc_kind}" || -z "${name}" || -z "${version}" || -z "${out_file}" ]]; then
    log_error "env_content_scan_tree: usage: <tree> <doc-kind> <name> <version> <out-file>"
    return 1
  fi
  if [[ ! -d "${tree}" ]]; then
    log_error "env_content_scan_tree: tree dir not found: ${tree}"
    return 1
  fi

  # TSV: project, version, versionSpec, url, revision, registry.
  # First doc per project wins; provenance is expected to match across its manifests.
  local provenance_file
  provenance_file=$(mktemp)
  # TSV: project, kind, name, namespace, sourcePath.
  local workloads_file
  workloads_file=$(mktemp)

  local file rel kinds i k project version version_spec url revision registry name namespace
  while IFS= read -r -d '' file; do
    rel="${file#"${tree}/"}"
    kinds=$(yq ea '.kind // "null"' "${file}" 2>/dev/null) || continue
    [[ -z "${kinds}" ]] && continue

    i=0
    while IFS= read -r k; do
      project=$(env_content_scan_anno "${file}" "${i}" "project-name")
      if [[ -n "${project}" ]]; then
        if ! grep -q "^${project}	" "${provenance_file}" 2>/dev/null; then
          version=$(env_content_scan_anno      "${file}" "${i}" "version")
          version_spec=$(env_content_scan_anno "${file}" "${i}" "version-spec")
          url=$(env_content_scan_anno          "${file}" "${i}" "origin-url")
          revision=$(env_content_scan_anno     "${file}" "${i}" "origin-revision")
          registry=$(env_content_scan_anno     "${file}" "${i}" "origin-registry")
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${project}" "${version}" "${version_spec}" \
            "${url}" "${revision}" "${registry}" >> "${provenance_file}"
        fi

        if [[ "${k}" =~ ${ENV_CONTENT_SCAN_WORKLOAD_KINDS_REGEX} ]]; then
          name=$(yq      "select(di == ${i}) | .metadata.name // \"\""      "${file}")
          namespace=$(yq "select(di == ${i}) | .metadata.namespace // \"\"" "${file}")
          [[ "${namespace}" == "null" ]] && namespace=""
          printf '%s\t%s\t%s\t%s\t%s\n' \
            "${project}" "${k}" "${name}" "${namespace}" "${rel}" >> "${workloads_file}"
        fi
      fi
      i=$((i + 1))
    done <<< "${kinds}"
  done < <(find "${tree}" -type f -name '*.yaml' -print0)

  # Sorted for deterministic output.
  : > "${out_file}"
  {
    printf 'apiVersion: kaptain.org/content-data/1\n'
    printf 'kind: %s\n' "${doc_kind}"
    printf 'name: %s\n' "${name}"
    printf 'version: %s\n' "${version}"
    printf 'children:\n'
  } >> "${out_file}"

  if [[ ! -s "${provenance_file}" ]]; then
    printf '  []\n' >> "${out_file}"
    rm -f "${provenance_file}" "${workloads_file}"
    return 0
  fi

  local child_kind
  while IFS=$'\t' read -r project version version_spec url revision registry; do
    [[ -z "${project}" ]] && continue
    child_kind=$(env_content_scan_classify_child "${project}")
    {
      printf '  - kind: %s\n' "${child_kind}"
      printf '    name: %s\n' "${project}"
    } >> "${out_file}"
    env_content_scan_emit_field "${out_file}" 4 "version" "${version}"
    env_content_scan_emit_field "${out_file}" 4 "versionSpec" "${version_spec}"
    if [[ -n "${url}" || -n "${revision}" || -n "${registry}" ]]; then
      printf '    origin:\n' >> "${out_file}"
      env_content_scan_emit_field "${out_file}" 6 "url"      "${url}"
      env_content_scan_emit_field "${out_file}" 6 "revision" "${revision}"
      env_content_scan_emit_field "${out_file}" 6 "registry" "${registry}"
    fi
    printf '    workloads:\n' >> "${out_file}"
    local project_workloads
    project_workloads=$(awk -F '\t' -v p="${project}" '$1 == p' "${workloads_file}" \
                          | LC_ALL=C sort -t $'\t' -k 2,2 -k 3,3 -k 5,5)
    if [[ -z "${project_workloads}" ]]; then
      printf '      []\n' >> "${out_file}"
    else
      local w_project w_kind w_name w_ns w_path
      while IFS=$'\t' read -r w_project w_kind w_name w_ns w_path; do
        [[ -z "${w_project}" ]] && continue
        {
          printf '      - name: %s\n' "${w_name}"
          printf '        kind: %s\n' "${w_kind}"
        } >> "${out_file}"
        env_content_scan_emit_field "${out_file}" 8 "namespace"  "${w_ns}"
        env_content_scan_emit_field "${out_file}" 8 "sourcePath" "${w_path}"
      done <<< "${project_workloads}"
    fi
  done < <(LC_ALL=C sort "${provenance_file}")

  rm -f "${provenance_file}" "${workloads_file}"
}
