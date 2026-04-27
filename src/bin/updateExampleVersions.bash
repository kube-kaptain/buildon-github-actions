#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

# updateExampleVersions.bash - Update example workflow version references
#
# Fetches tags from origin, finds the highest x.y.z tag, increments the
# patch by one, and updates all @x.y.z references in examples/ to match.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXAMPLES_DIR="${PROJECT_ROOT}/examples"

git -C "${PROJECT_ROOT}" fetch --tags

highest=$(git -C "${PROJECT_ROOT}" tag --list '[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)

if [[ -z "${highest}" ]]; then
  echo "No version tags found"
  exit 1
fi

IFS='.' read -r major minor patch <<< "${highest}"
expected="${major}.${minor}.$((patch + 1))"

echo "Highest tag: ${highest}"
echo "Updating examples to: @${expected}"

updated=0

# Update plain examples
for file in "${EXAMPLES_DIR}"/*.yaml; do
  [[ -f "${file}" ]] || continue
  if grep -q '@[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' "${file}"; then
    sed -i.bak "s/@[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/@${expected}/g" "${file}"
    rm "${file}.bak"
    updated=$((updated + 1))
  fi
done

# Update guides (build.yaml in each guide subdirectory)
for file in "${EXAMPLES_DIR}"/guides/*/build.yaml; do
  [[ -f "${file}" ]] || continue
  if grep -q '@[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' "${file}"; then
    sed -i.bak "s/@[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/@${expected}/g" "${file}"
    rm "${file}.bak"
    updated=$((updated + 1))
  fi
done

echo "Updated ${updated} example file(s)"

# Update KaptainPM.yaml apiVersion to current schema version
SCHEMA_VERSION_FILE="${PROJECT_ROOT}/src/schemas/version"
if [[ ! -f "${SCHEMA_VERSION_FILE}" ]]; then
  echo "Schema version file not found: ${SCHEMA_VERSION_FILE}"
  exit 1
fi
schema_version=$(head -n 1 "${SCHEMA_VERSION_FILE}")

echo "Updating example KaptainPM.yaml apiVersion to: kaptain.org/${schema_version}"

kpm_updated=0
while IFS= read -r -d '' file; do
  if grep -q '^apiVersion:[[:space:]]*kaptain\.org/' "${file}"; then
    sed -i.bak -E "s|^apiVersion:[[:space:]]*kaptain\.org/[^[:space:]]+|apiVersion: kaptain.org/${schema_version}|" "${file}"
    rm "${file}.bak"
    kpm_updated=$((kpm_updated + 1))
  fi
done < <(find "${EXAMPLES_DIR}" -name 'KaptainPM.yaml' -print0)

echo "Updated ${kpm_updated} KaptainPM.yaml file(s)"
