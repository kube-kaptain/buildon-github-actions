#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# image-pull-secrets.bash - Find the imagePullSecrets names a manifest tree
# references and the Secrets it supplies.
#
# Shared by kubernetes-run-substitute, which generates a Secret per missing
# name, and kubernetes-run-finalise, which fails any name the final tree has
# no Secret for. References are names only: Kubernetes resolves them in the
# workload's own namespace, which is the run's.
#
# References are read only from workload kinds, at their pod template path:
# Deployment, StatefulSet, DaemonSet, ReplicaSet, Job and Argo Rollout at
# .spec.template.spec, CronJob at .spec.jobTemplate.spec.template.spec, and
# ServiceAccount at the top level (its pods inherit them). Pod specs embedded
# in other resources (operator CRs, CRD schemas) are not references; a
# project that needs a Secret for one supplies it.
#
# A Secret counts as supplied only from a secret*.template.yaml file: the one
# place Secrets belong, where the deploy fills their values in.
#
# A file yq cannot parse is skipped when it holds an unresolved token, as the
# finalise gate fails that file anyway. Any other unparseable file fails here.
#
# Functions:
#   image_pull_secrets_scan <tree>
#       Sets IMAGE_PULL_SECRETS_REFERENCED, the sorted unique names, one per
#       line, and IMAGE_PULL_SECRETS_SUPPLIED, "<name><TAB><relative path>"
#       per Secret in a secret*.template.yaml file. Returns 1 on an
#       unparseable file with no token in it.
#
# Requires lib/log.bash, lib/manifest-file-kinds.bash and lib/token-format.bash.
# Reads TOKEN_DELIMITER_STYLE and TOKEN_NAME_STYLE from the caller's scope.
#
# Required tools: yq, grep, sort.

IMAGE_PULL_SECRETS_REFERENCES_EXPR='((select(.kind == "Deployment" or .kind == "StatefulSet" or .kind == "DaemonSet" or .kind == "ReplicaSet" or .kind == "Job" or .kind == "Rollout") | (.spec.template.spec.imagePullSecrets // [])[] | .name), (select(.kind == "CronJob") | (.spec.jobTemplate.spec.template.spec.imagePullSecrets // [])[] | .name), (select(.kind == "ServiceAccount") | (.imagePullSecrets // [])[] | .name)) | select(. != null)'

image_pull_secrets_scan() {
  local tree="$1"
  # shellcheck disable=SC2034 # read by the caller
  IMAGE_PULL_SECRETS_REFERENCED=""
  IMAGE_PULL_SECRETS_SUPPLIED=""

  local token_regex
  # shellcheck disable=SC2154 # TOKEN_*_STYLE set by the caller (defaults/tokens.bash)
  token_regex=$(unresolved_token_regex "${TOKEN_DELIMITER_STYLE}" "${TOKEN_NAME_STYLE}") || return 1

  local file rel names secrets failures=0 referenced=""
  while IFS= read -r file; do
    manifest_file_classify "${file}" || continue
    # shellcheck disable=SC2154 # MANIFEST_FILE_KIND set by manifest_file_classify
    [[ "${MANIFEST_FILE_KIND}" == "manifest" ]] || continue
    rel="${file#"${tree}"/}"
    secrets=""
    # -N: no '---' between documents, which would read as a name.
    if ! names=$(yq ea -N "${IMAGE_PULL_SECRETS_REFERENCES_EXPR}" "${file}" 2>/dev/null) \
        || { [[ "$(basename "${file}")" == secret*.template.yaml ]] \
          && ! secrets=$(yq ea -N 'select(.kind == "Secret") | .metadata.name | select(. != null)' "${file}" 2>/dev/null); }; then
      grep -qE "${token_regex}" "${file}" && continue
      log_error "  ${rel}: not parseable YAML"
      failures=$((failures + 1))
      continue
    fi
    [[ -n "${names}" ]] && referenced="${referenced}${names}"$'\n'
    [[ -n "${secrets}" ]] && IMAGE_PULL_SECRETS_SUPPLIED="${IMAGE_PULL_SECRETS_SUPPLIED}$(awk -v r="${rel}" '{ print $0 "\t" r }' <<< "${secrets}")"$'\n'
  done < <(manifest_files_find_packageable "${tree}" | LC_ALL=C sort)

  # shellcheck disable=SC2034 # read by the caller
  IMAGE_PULL_SECRETS_REFERENCED=$(printf '%s' "${referenced}" | grep . | LC_ALL=C sort -u || true)
  [[ "${failures}" -eq 0 ]]
}
