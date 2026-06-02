#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# download-and-enforce-env-report-schema.bash - Download manifests env-report schema and enforce no drift
#
# Pulls the spec-manifests-env-report-schema OCI image for the version declared in
# src/schemas/manifests-env-report/version, extracts the schema files, and copies
# them into src/schemas/manifests-env-report/. Env-report schema files already have
# the version in their filenames so they are copied as-is without renaming.
# Verifies via git diff that the committed schemas match upstream exactly.
#
set -euo pipefail

SCHEMAS_DIR="src/schemas/manifests-env-report"
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

echo "Env-report schema version: ${SCHEMA_VERSION}"

# Supply defaults for direct local runs
IMAGE_BUILD_COMMAND="${IMAGE_BUILD_COMMAND:-podman}"
export IMAGE_BUILD_COMMAND
BUILD_PLATFORM="${BUILD_PLATFORM:-local}"
export BUILD_PLATFORM

SCHEMA_IMAGE="ghcr.io/kube-kaptain/spec/spec-manifests-env-report-schema:${SCHEMA_VERSION}"
echo "Schema image: ${SCHEMA_IMAGE}"

UTIL_DIR="src/scripts/util"
OCI_EXTRACT="${UTIL_DIR}/extract-oci-image"

if [[ ! -x "${OCI_EXTRACT}" ]]; then
  echo "ERROR: extract-oci-image not found or not executable: ${OCI_EXTRACT}" >&2
  exit 1
fi

# Staging directory for extracted files
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-kaptain-out}"
STAGING_DIR="${OUTPUT_SUB_PATH}/env-report-schema-download/${SCHEMA_VERSION}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

echo "Extracting schemas to staging: ${STAGING_DIR}"

"${OCI_EXTRACT}" "${SCHEMA_IMAGE}" "${STAGING_DIR}"

# Verify expected schema file was extracted (already versioned in filename)
EXPECTED_SCHEMA="spec-manifests-env-report-schema-${SCHEMA_VERSION}.json"
if [[ ! -f "${STAGING_DIR}/${EXPECTED_SCHEMA}" ]]; then
  echo "ERROR: Expected schema file not found after extraction: ${EXPECTED_SCHEMA}" >&2
  exit 1
fi

echo "Schema file extracted successfully"

# Remove old env-report schema files (preserve version file)
rm -f "${SCHEMAS_DIR}"/spec-manifests-env-report-schema*.json

# Copy extracted file as-is (already have version in filename)
schema_file="${STAGING_DIR}/${EXPECTED_SCHEMA}"
cp "${schema_file}" "${SCHEMAS_DIR}/"
echo "Installed: $(basename "${schema_file}")"

echo "Schema installed to ${SCHEMAS_DIR}/"
ls -la "${SCHEMAS_DIR}"/spec-manifests-env-report-schema*.json

# Enforce: committed schemas must match upstream
if git diff --quiet HEAD -- "${SCHEMAS_DIR}/"; then
  echo "Env-report schemas are up to date with upstream"
else
  if [[ "${BUILD_MODE:-local}" == "local" ]]; then
    echo "WARNING: Schema drift detected — committed env-report schemas do not match upstream release ${SCHEMA_VERSION}" >&2
    git diff --name-only HEAD -- "${SCHEMAS_DIR}/"
  else
    echo "ERROR: Schema drift detected — committed env-report schemas do not match upstream release ${SCHEMA_VERSION}" >&2
    git diff --name-only HEAD -- "${SCHEMAS_DIR}/"
    exit 1
  fi
fi
