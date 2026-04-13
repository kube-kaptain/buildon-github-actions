#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# download-and-enforce-kaptainpm-schemas.bash - Download KaptainPM schemas and enforce no drift
#
# Pulls the spec-kaptainpm-schema OCI image for the version declared in
# src/schemas/version, extracts the JSON schema files, copies them into
# src/schemas/ with the version in the filename, and verifies via git diff
# that the committed schemas match the upstream release exactly.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCHEMAS_DIR="src/schemas"
VERSION_FILE="${SCHEMAS_DIR}/version"

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "ERROR: Schema version file not found: ${VERSION_FILE}" >&2
  exit 1
fi

SCHEMA_VERSION=$(cat "${VERSION_FILE}")
if [[ -z "${SCHEMA_VERSION}" ]]; then
  echo "ERROR: Schema version file is empty" >&2
  exit 1
fi

echo "Schema version: ${SCHEMA_VERSION}"

# Supply defaults for direct local runs
IMAGE_BUILD_COMMAND="${IMAGE_BUILD_COMMAND:-podman}"
export IMAGE_BUILD_COMMAND
BUILD_PLATFORM="${BUILD_PLATFORM:-local}"
export BUILD_PLATFORM

SCHEMA_IMAGE="ghcr.io/kube-kaptain/spec/spec-kaptainpm-schema:${SCHEMA_VERSION}"
echo "Schema image: ${SCHEMA_IMAGE}"

UTIL_DIR="src/scripts/util"
OCI_EXTRACT="${UTIL_DIR}/extract-oci-image"

if [[ ! -x "${OCI_EXTRACT}" ]]; then
  echo "ERROR: extract-oci-image not found or not executable: ${OCI_EXTRACT}" >&2
  exit 1
fi

# Staging directory for extracted files
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-kaptain-out}"
STAGING_DIR="${OUTPUT_SUB_PATH}/schema-download/${SCHEMA_VERSION}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

echo "Extracting schemas to staging: ${STAGING_DIR}"

# Extract all six schema files from the image
"${OCI_EXTRACT}" "${SCHEMA_IMAGE}" "${STAGING_DIR}" 

# Verify all expected files were extracted
for schema in spec-kaptainpm-schema.json spec-kaptainpm-schema-final.json spec-kaptainpm-schema-layer-source.json spec-kaptainpm-schema-layer.json spec-kaptainpm-schema-layerset-source.json spec-kaptainpm-schema-layerset.json; do
  if [[ ! -f "${STAGING_DIR}/${schema}" ]]; then
    echo "ERROR: Expected schema file not found after extraction: ${schema}" >&2
    exit 1
  fi
done

echo "All schema files extracted successfully"

# Remove old spec-kaptainpm schema files (preserve json-schema-draft and version)
rm -f "${SCHEMAS_DIR}"/spec-kaptainpm-schema*.json

# Copy with version in the filename
cp "${STAGING_DIR}/spec-kaptainpm-schema.json" "${SCHEMAS_DIR}/spec-kaptainpm-schema.${SCHEMA_VERSION}.json"
cp "${STAGING_DIR}/spec-kaptainpm-schema-final.json" "${SCHEMAS_DIR}/spec-kaptainpm-schema-final.${SCHEMA_VERSION}.json"
cp "${STAGING_DIR}/spec-kaptainpm-schema-layer-source.json" "${SCHEMAS_DIR}/spec-kaptainpm-schema-layer-source.${SCHEMA_VERSION}.json"
cp "${STAGING_DIR}/spec-kaptainpm-schema-layer.json" "${SCHEMAS_DIR}/spec-kaptainpm-schema-layer.${SCHEMA_VERSION}.json"
cp "${STAGING_DIR}/spec-kaptainpm-schema-layerset-source.json" "${SCHEMAS_DIR}/spec-kaptainpm-schema-layerset-source.${SCHEMA_VERSION}.json"
cp "${STAGING_DIR}/spec-kaptainpm-schema-layerset.json" "${SCHEMAS_DIR}/spec-kaptainpm-schema-layerset.${SCHEMA_VERSION}.json"

echo "Schemas installed to ${SCHEMAS_DIR}/"
ls -la "${SCHEMAS_DIR}"/spec-kaptainpm-schema*.json

# Enforce: committed schemas must match upstream
if git diff --quiet HEAD -- src/schemas/; then
  echo "Schemas are up to date with upstream"
else
  if [[ "${BUILD_MODE:-local}" == "local" ]]; then
    echo "WARNING: Schema drift detected — committed schemas do not match upstream release ${SCHEMA_VERSION}" >&2
    git diff --name-only HEAD -- src/schemas/
  else
    echo "ERROR: Schema drift detected — committed schemas do not match upstream release ${SCHEMA_VERSION}" >&2
    git diff --name-only HEAD -- src/schemas/
    exit 1
  fi
fi
