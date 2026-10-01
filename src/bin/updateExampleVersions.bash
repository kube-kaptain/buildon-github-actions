#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

# updateExampleVersions.bash - Update example workflow version references
#
# Fetches tags from origin, works out the version this branch will build with
# the same provider the build uses (git-auto-closest-highest: the closest tag
# reachable from HEAD picks the series, the highest in that series plus one),
# and updates all @x.y.z references in examples/ to match. Using every tag in
# the repo instead let tags on unmerged commits push examples ahead of the
# version the build actually produces.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXAMPLES_DIR="${PROJECT_ROOT}/examples"

git -C "${PROJECT_ROOT}" fetch --tags

version_out=$(mktemp -d)
mkdir -p "${version_out}/versions-and-naming/tag-version-calculation-provider"
(
  cd "${PROJECT_ROOT}"
  BUILD_PLATFORM=local OUTPUT_SUB_PATH="${version_out}" TAG_VERSION_MAX_PARTS=3 \
    "${PROJECT_ROOT}/src/scripts/plugins/tag-version-calculation-providers/tag-version-calculation-git-auto-closest-highest"
)
expected=$(cat "${version_out}/versions-and-naming/tag-version-calculation-provider/VERSION")
rm -rf "${version_out:?}"

echo "Version this branch builds: ${expected}"
echo "Updating examples to: @${expected}"

updated=0

# Update every build.yaml under examples/ (top-level examples and guides).
while IFS= read -r -d '' file; do
  if grep -q '@[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' "${file}"; then
    sed -i.bak "s/@[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/@${expected}/g" "${file}"
    rm "${file}.bak"
    updated=$((updated + 1))
  fi
done < <(find "${EXAMPLES_DIR}" -name 'build.yaml' -print0)

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
