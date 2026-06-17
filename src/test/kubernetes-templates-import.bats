#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-templates-import.
#
# Focuses on behaviour specific to this script: products-in-templates rejection,
# input validation, the flat vs hierarchy layout split, flat-mode lineage CM
# lifting + collision detection, and the ENV_BUILD_SECTION lineage routing.
# Shared content-resolve / bundle-import behaviour (scheme conversion, defaults
# merge, OCI extraction, audit trail) is covered exhaustively in
# kubernetes-product-aggregate.bats.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-templates-import"

setup() {
  TEST_DIR=$(create_test_dir "kubernetes-templates-import")
  mkdir -p "${TEST_DIR}/kaptainpm/final"
  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"
}

# Write a KaptainPM.yaml with optional spec.templates entries.
write_pm() {
  local pm_file="${TEST_DIR}/kaptainpm/final/KaptainPM.yaml"
  cat > "${pm_file}" << 'EOF'
apiVersion: kaptain.org/v1
kind: kubernetes-app
spec:
  global:
    tokens:
      delimiterStyle: shell
      nameStyle: PascalCase
EOF
  if [[ $# -gt 0 ]]; then
    {
      echo "  templates:"
      local entry
      for entry in "$@"; do
        echo "    - ${entry}"
      done
    } >> "${pm_file}"
  fi
}

# Build a manifests zip with one deployment manifest and optionally a
# lineage CM. Args:
#   zip_path
#   project          name of the project dir inside the zip (= bundle name)
#   manifest_basename  filename for the deployment manifest (default deployment.yaml)
#   lineage_kind     bundle|app|product to emit kaptain-<kind>-lineage-data.yaml,
#                    or empty to skip
make_manifests_zip() {
  local zip_path="$1"
  local project="$2"
  local manifest_basename="${3:-deployment.yaml}"
  local lineage_kind="${4:-}"
  local stage="${TEST_DIR}/_stage-mz-$$-${RANDOM}"
  mkdir -p "${stage}/${project}"
  cat > "${stage}/${project}/${manifest_basename}" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${project}
spec:
  replicas: \${Replicas}
EOF
  if [[ -n "${lineage_kind}" ]]; then
    cat > "${stage}/${project}/kaptain-${lineage_kind}-lineage-data.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${project}-lineage
data:
  source: ${project}
EOF
  fi
  ( cd "${stage}" && zip -qr "${zip_path}" "${project}" )
  rm -rf "${stage}"
}

# Build a contract zip. Args: zip_path, delim, name, [token=value]...
# config.required is auto-populated with Replicas (the default token in
# make_manifests_zip) plus each default name.
make_contract_zip() {
  local zip_path="$1"
  local delim="$2"
  local name="$3"
  shift 3
  local stage="${TEST_DIR}/_stage-cz-$$-${RANDOM}"
  mkdir -p "${stage}"
  cat > "${stage}/contract.yaml" << EOF
apiVersion: kaptain.org/manifests-contract/1.2
kind: kubernetes-bundle
tokens:
  delimiterStyle: ${delim}
  nameStyle: ${name}
compatibility:
  automaticConversion: []
  repackageRequired: []
config:
  required:
    - Replicas
EOF
  if [[ $# -gt 0 ]]; then
    mkdir -p "${stage}/defaults"
    local pair token value
    for pair in "$@"; do
      token="${pair%%=*}"
      value="${pair#*=}"
      if [[ "${token}" != "Replicas" ]]; then
        printf '    - %s\n' "${token}" >> "${stage}/contract.yaml"
      fi
      printf '%s' "${value}" > "${stage}/defaults/${token}"
    done
  fi
  ( cd "${stage}" && zip -qr "${zip_path}" . )
  rm -rf "${stage}"
}

# Mock util/artifact-resolve and util/extract-oci-image so the library doesn't
# hit a real registry. Sets MOCK_UTIL_DIR and MOCK_OCI_DIR globals.
setup_mock_oci() {
  MOCK_UTIL_DIR="${TEST_DIR}/mock-util-bin"
  MOCK_OCI_DIR="${TEST_DIR}/oci-fixtures"
  mkdir -p "${MOCK_UTIL_DIR}" "${MOCK_OCI_DIR}"

  cat > "${MOCK_UTIL_DIR}/artifact-resolve" << 'MOCK'
#!/usr/bin/env bash
ref="$1"
out="$2"
variant="${3:-}"
if [[ -n "${variant}" ]]; then
  echo "${ref}-${variant}" > "${out}"
else
  echo "${ref}" > "${out}"
fi
MOCK
  chmod +x "${MOCK_UTIL_DIR}/artifact-resolve"

  cat > "${MOCK_UTIL_DIR}/extract-oci-image" << 'MOCK'
#!/usr/bin/env bash
image_uri="$1"
out_dir="$2"
mkdir -p "${out_dir}"
key=$(echo "${image_uri}" | tr '/:' '__')
src="${MOCK_OCI_DIR}/${key}"
if [[ ! -d "${src}" ]]; then
  echo "mock extract-oci-image: no fixture for key ${key} (uri ${image_uri})" >&2
  exit 1
fi
cp -R "${src}/." "${out_dir}/"
MOCK
  chmod +x "${MOCK_UTIL_DIR}/extract-oci-image"

  ln -sf "${SCRIPTS_DIR}/util/scan-unresolved-tokens" "${MOCK_UTIL_DIR}/scan-unresolved-tokens"
}

# Stage a fake OCI fixture so the library finds manifests + contract zips for
# the given URI. Args:
#   manifests_uri      OCI URI the library will resolve
#   project            project dir name inside the manifests zip (= bundle name)
#   delim              tokens.delimiterStyle in the contract
#   name               tokens.nameStyle in the contract
#   manifest_basename  filename for the manifest (default deployment.yaml)
#   lineage_kind       bundle|app|product or empty (default empty)
stage_oci_fixture() {
  local manifests_uri="$1"
  local project="$2"
  local delim="$3"
  local name="$4"
  local manifest_basename="${5:-deployment.yaml}"
  local lineage_kind="${6:-}"
  local key
  key=$(echo "${manifests_uri}" | tr '/:' '__')
  local fixture_dir="${MOCK_OCI_DIR}/${key}"
  mkdir -p "${fixture_dir}"
  make_manifests_zip "${fixture_dir}/${project}-1.0-manifests.zip" \
    "${project}" "${manifest_basename}" "${lineage_kind}"
  make_contract_zip "${fixture_dir}/${project}-1.0-contract.zip" \
    "${delim}" "${name}"
}

run_script() {
  : "${PROJECT_NAME=app-foo}"
  : "${OUTPUT_SUB_PATH:=kaptain-out}"
  : "${TOKEN_DELIMITER_STYLE:=shell}"
  : "${TOKEN_NAME_STYLE:=PascalCase}"
  : "${TEMPLATES_LAYOUT:=flat}"
  : "${KAPTAINPM_FILE:=${TEST_DIR}/kaptainpm/final/KaptainPM.yaml}"
  run env \
    PROJECT_NAME="${PROJECT_NAME}" \
    OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH}" \
    TOKEN_DELIMITER_STYLE="${TOKEN_DELIMITER_STYLE}" \
    TOKEN_NAME_STYLE="${TOKEN_NAME_STYLE}" \
    TEMPLATES_LAYOUT="${TEMPLATES_LAYOUT}" \
    ENV_BUILD_SECTION="${ENV_BUILD_SECTION:-}" \
    BUILD_PLATFORM=test \
    GITHUB_OUTPUT="${GITHUB_OUTPUT}" \
    KAPTAINPM_FILE="${KAPTAINPM_FILE}" \
    CONTENT_RESOLVE_UTIL_DIR="${MOCK_UTIL_DIR:-}" \
    MOCK_OCI_DIR="${MOCK_OCI_DIR:-}" \
    bash -c "cd '${TEST_DIR}' && '${SCRIPT}'"
}

github_output_value() {
  grep "^${1}=" "${GITHUB_OUTPUT}" | tail -1 | cut -d= -f2-
}

# =============================================================================
# Products in templates
# =============================================================================

@test "products-in-templates: rejects entry whose repo starts with product-" {
  write_pm "product-other:1.0"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Including a product as a template"
  assert_output_contains "product-other:1.0"
}

@test "products-in-templates: rejects entry whose repo ends with -product" {
  write_pm "ghcr.io/org/sub/some-product:9.9"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Including a product as a template"
  assert_output_contains "some-product"
}

@test "products-in-templates: accepts non-product entries" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase
  write_pm "alpha:1.0"
  run_script
  [ "${status}" -eq 0 ]
}

# =============================================================================
# Required-input validation
# =============================================================================

@test "missing KAPTAINPM_FILE: fails with diagnostic" {
  KAPTAINPM_FILE="${TEST_DIR}/does-not-exist.yaml" run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "KaptainPM file not found"
}

@test "missing PROJECT_NAME: fails" {
  write_pm
  PROJECT_NAME="" run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "invalid TEMPLATES_LAYOUT: fails with diagnostic" {
  setup_mock_oci
  write_pm
  TEMPLATES_LAYOUT="garbage" run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Invalid TEMPLATES_LAYOUT"
  assert_output_contains "flat or hierarchy"
}

# =============================================================================
# Empty spec.templates
# =============================================================================

@test "empty spec.templates: succeeds and writes empty templates.yaml + output var" {
  setup_mock_oci
  write_pm
  run_script
  [ "${status}" -eq 0 ]
  local list="${TEST_DIR}/kaptain-out/templates/templates.yaml"
  [ -f "${list}" ]
  [ ! -s "${list}" ]
  [ "$(github_output_value TEMPLATES_LIST_FILE)" = "kaptain-out/templates/templates.yaml" ]
}

# =============================================================================
# Hierarchy layout
# =============================================================================

@test "hierarchy: single bundle stages into additional-manifests/<bundle>/" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase
  write_pm "alpha:1.0"
  TEMPLATES_LAYOUT=hierarchy run_script
  [ "${status}" -eq 0 ]
  [ -f "${TEST_DIR}/kaptain-out/manifests/additional-manifests/alpha/deployment.yaml" ]
  # No flat-mode intermediate dir in hierarchy mode.
  [ ! -d "${TEST_DIR}/kaptain-out/templates-import" ]
}

@test "hierarchy: two bundles stage into sibling subdirs" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase
  stage_oci_fixture "beta:2.0-manifests"  "beta"  shell PascalCase
  write_pm "alpha:1.0" "beta:2.0"
  TEMPLATES_LAYOUT=hierarchy run_script
  [ "${status}" -eq 0 ]
  [ -f "${TEST_DIR}/kaptain-out/manifests/additional-manifests/alpha/deployment.yaml" ]
  [ -f "${TEST_DIR}/kaptain-out/manifests/additional-manifests/beta/deployment.yaml" ]
}

@test "hierarchy: lineage CM stays inside per-bundle subdir (not lifted)" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase \
    "deployment.yaml" "bundle"
  write_pm "alpha:1.0"
  TEMPLATES_LAYOUT=hierarchy run_script
  [ "${status}" -eq 0 ]
  [ -f "${TEST_DIR}/kaptain-out/manifests/additional-manifests/alpha/kaptain-bundle-lineage-data.yaml" ]
  [ ! -d "${TEST_DIR}/kaptain-out/lineage-data/data-files" ]
}

# =============================================================================
# Flat layout
# =============================================================================

@test "flat: single bundle flattens with no per-bundle prefix" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase
  write_pm "alpha:1.0"
  run_script
  [ "${status}" -eq 0 ]
  [ -f "${TEST_DIR}/kaptain-out/manifests/additional-manifests/deployment.yaml" ]
  [ ! -d "${TEST_DIR}/kaptain-out/manifests/additional-manifests/alpha" ]
}

@test "flat: lineage CM lifted to lineage-data/data-files/<bundle>-<name>" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase \
    "deployment.yaml" "bundle"
  write_pm "alpha:1.0"
  run_script
  [ "${status}" -eq 0 ]
  [ -f "${TEST_DIR}/kaptain-out/lineage-data/data-files/alpha-kaptain-bundle-lineage-data.yaml" ]
  # Lifted file must NOT also appear in additional-manifests.
  [ ! -f "${TEST_DIR}/kaptain-out/manifests/additional-manifests/kaptain-bundle-lineage-data.yaml" ]
  [ ! -f "${TEST_DIR}/kaptain-out/manifests/additional-manifests/alpha/kaptain-bundle-lineage-data.yaml" ]
}

@test "flat: cross-bundle manifest collision fails with diagnostic" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase
  stage_oci_fixture "beta:2.0-manifests"  "beta"  shell PascalCase
  write_pm "alpha:1.0" "beta:2.0"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Flat-mode templates import: file collision"
}

@test "flat: ENV_BUILD_SECTION routes lineage lift under per-section dir" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase \
    "deployment.yaml" "bundle"
  write_pm "alpha:1.0"
  ENV_BUILD_SECTION="rp" run_script
  [ "${status}" -eq 0 ]
  [ -f "${TEST_DIR}/kaptain-out/lineage-data/rp/data-files/alpha-kaptain-bundle-lineage-data.yaml" ]
  [ ! -d "${TEST_DIR}/kaptain-out/lineage-data/data-files" ]
}

# =============================================================================
# Templates list output
# =============================================================================

@test "templates-list: writes bullets for every spec.templates entry verbatim" {
  setup_mock_oci
  stage_oci_fixture "alpha:1.0-manifests" "alpha" shell PascalCase
  stage_oci_fixture "ghcr.io/org/sub/beta:2.0-manifests" "beta" shell PascalCase \
    "service-b.yaml"
  write_pm "alpha:1.0" "ghcr.io/org/sub/beta:2.0"
  TEMPLATES_LAYOUT=hierarchy run_script
  [ "${status}" -eq 0 ]
  local list="${TEST_DIR}/kaptain-out/templates/templates.yaml"
  [ -f "${list}" ]
  [ "$(github_output_value TEMPLATES_LIST_FILE)" = "kaptain-out/templates/templates.yaml" ]
  grep -qx -- "- alpha:1.0" "${list}"
  grep -qx -- "- ghcr.io/org/sub/beta:2.0" "${list}"
}

teardown() {
  dump_bats_result
}
