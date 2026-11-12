#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# check-action-pins.bash - Keep pinned action version comments honest
#
# An external action is pinned by commit, with the release that commit came
# from in a trailing comment:
#
#   uses: actions/checkout@<40 hex sha>  # v5.1.0
#
# The sha is what runs. The comment is what people and update tooling read, and
# nothing on GitHub's side compares the two, so a bumped sha under a stale
# comment (or the reverse) goes unnoticed. This asks the action's repository
# which commit the tag named in the comment points at, and fails when that is
# not the pinned sha, or when a pinned sha has no version comment at all.
#
# References not pinned to a sha (./local paths, tags, branches) are ignored.
#
# Needs network access to github.com: one git ls-remote per distinct pin.
#
# Usage: check-action-pins.bash [<file>...]
#   Defaults to the workflow and action sources plus .github/workflows.
#
# Exits 1 and prints file:line: reason for every hit.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

pinned_uses='^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*[^[:space:]@]+@[0-9a-f]{40}([[:space:]]|$)'
parse_pin='uses:[[:space:]]*([^[:space:]@]+)@([0-9a-f]{40})[[:space:]]*(#[[:space:]]*([^[:space:]]+))?'

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  for file in \
    "${PROJECT_ROOT}"/src/steps-common/*.yaml \
    "${PROJECT_ROOT}"/src/workflow-templates/*.yaml \
    "${PROJECT_ROOT}"/src/action-templates/*.yaml \
    "${PROJECT_ROOT}"/.github/workflows/*.yaml; do
    if [[ -f "${file}" ]]; then
      files+=("${file}")
    fi
  done
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ERROR: no files to check" >&2
  exit 1
fi

hits=$(grep -nHE "${pinned_uses}" "${files[@]}" || true)

# One lookup per distinct repo and tag, remembered in parallel arrays.
looked_up=()
commits=()

findings=""
checked=0

while IFS= read -r hit; do
  if [[ -z "${hit}" ]]; then
    continue
  fi

  file="${hit%%:*}"
  rest="${hit#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"

  if [[ ! "${text}" =~ ${parse_pin} ]]; then
    continue
  fi
  action="${BASH_REMATCH[1]}"
  sha="${BASH_REMATCH[2]}"
  tag="${BASH_REMATCH[4]:-}"

  where="${file#"${PROJECT_ROOT}"/}:${line}"
  checked=$((checked + 1))

  if [[ -z "${tag}" ]]; then
    findings+="${where}: ${action}@${sha} has no version comment"$'\n'
    continue
  fi

  repo=$(printf '%s' "${action}" | cut -d/ -f1-2)

  commit=""
  known=false
  for ((index = 0; index < ${#looked_up[@]}; index++)); do
    if [[ "${looked_up[index]}" == "${repo} ${tag}" ]]; then
      commit="${commits[index]}"
      known=true
      break
    fi
  done

  if [[ "${known}" == "false" ]]; then
    # An annotated tag lists twice; the ^{} line is the commit it points at.
    if ! refs=$(GIT_TERMINAL_PROMPT=0 git ls-remote "https://github.com/${repo}" \
      "refs/tags/${tag}" "refs/tags/${tag}^{}" 2>&1); then
      echo "${refs}" >&2
      echo "ERROR: could not ask github.com/${repo} about tag ${tag}" >&2
      exit 1
    fi
    commit=$(printf '%s\n' "${refs}" \
      | awk '$2 ~ /\^\{\}$/ { peeled = $1; next } { plain = $1 } END { print (peeled != "" ? peeled : plain) }')
    looked_up+=("${repo} ${tag}")
    commits+=("${commit}")
  fi

  if [[ -z "${commit}" ]]; then
    findings+="${where}: ${action}@${sha} comment says ${tag}, which is not a tag in ${repo}"$'\n'
  elif [[ "${commit}" != "${sha}" ]]; then
    findings+="${where}: ${action}@${sha} comment says ${tag}, but ${tag} is ${commit}"$'\n'
  fi
done <<< "${hits}"

if [[ -n "${findings}" ]]; then
  count=$(printf '%s' "${findings}" | wc -l | tr -d ' ')
  printf '%s' "${findings}" >&2
  echo "ERROR: ${count} pinned action reference(s) with a missing or wrong version comment" >&2
  echo "Make the sha and the comment agree: the tag in the comment must resolve to the pinned sha." >&2
  exit 1
fi

echo "${checked} pinned action reference(s) match their version comment in ${#files[@]} file(s)"
