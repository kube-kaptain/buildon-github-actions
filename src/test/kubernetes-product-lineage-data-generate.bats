#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-product-lineage-data-generate.
#
# Covers happy path (product lineage data CM produced and copied into the
# substituted product tree), the four lineage data files, the resources.yaml
# inventory walk, the additional labels and annotations on the CM, the optional
# git-sha annotation and validation diagnostics for missing preconditions.

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-product-lineage-data-generate"

setup() {
  TEST_DIR=$(create_test_dir "kubernetes-product-lineage-data-generate")
  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"
}

# Stage the typical preconditions for a product build at the
# manifest-product-lineage-data-generate step:
#
#  - KaptainPM.yaml
#  - contract.yaml
#  - contents-resolved.yaml
#  - the tokens dir laid down by prepare-substitution-tokens
#  - a substituted product tree with a pair of workloads
#
# Project name is fixed at product-foo.
stage_preconditions() {
  local out="${TEST_DIR}/kaptain-out"

  mkdir -p "${TEST_DIR}/kaptainpm/final"
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/v1
kind: kubernetes-product
spec:
  global:
    tokens:
      delimiterStyle: shell
      nameStyle: PascalCase
  contents:
    - alpha:1.0
    - beta:2.0
EOF

  mkdir -p "${out}/manifests/contract"
  cat > "${out}/manifests/contract/contract.yaml" << 'EOF'
apiVersion: kaptain.org/manifests-contract/1.3
kind: kubernetes-product
config:
  required:
    - Replicas
EOF

  mkdir -p "${out}/content"
  cat > "${out}/content/contents-resolved.yaml" << 'EOF'
- ghcr.io/org/alpha:1.0.0-manifests
- ghcr.io/org/beta:2.0.0-manifests
EOF

  # Tokens dir for the sub-round substitute. PascalCase filenames matching the
  # layout prepare-substitution-tokens produces.
  mkdir -p "${out}/manifests/config"
  printf '%s' "product-foo" > "${out}/manifests/config/ProjectName"
  printf '%s' "1.2.3" > "${out}/manifests/config/Version"
  printf '%s' "product-foo" > "${out}/manifests/config/ProductName"
  printf '%s' "foo" > "${out}/manifests/config/ProductShortName"

  mkdir -p "${out}/manifests/substituted/product-foo"
  cat > "${out}/manifests/substituted/product-foo/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-foo
spec:
  replicas: 2
EOF
  cat > "${out}/manifests/substituted/product-foo/service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: product-foo
spec:
  ports:
    - port: 80
EOF
}

run_script() {
  : "${PROJECT_NAME=product-foo}"
  : "${VERSION:=1.2.3}"
  : "${PRODUCT_NAME:=product-foo}"
  : "${PRODUCT_SHORT_NAME:=foo}"
  : "${TOKEN_DELIMITER_STYLE:=shell}"
  : "${TOKEN_NAME_STYLE:=PascalCase}"
  : "${OUTPUT_SUB_PATH:=kaptain-out}"
  : "${KAPTAINPM_FILE:=kaptainpm/final/KaptainPM.yaml}"
  run env \
    PROJECT_NAME="${PROJECT_NAME}" \
    VERSION="${VERSION}" \
    PRODUCT_NAME="${PRODUCT_NAME}" \
    PRODUCT_SHORT_NAME="${PRODUCT_SHORT_NAME}" \
    TOKEN_DELIMITER_STYLE="${TOKEN_DELIMITER_STYLE}" \
    TOKEN_NAME_STYLE="${TOKEN_NAME_STYLE}" \
    OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH}" \
    KAPTAINPM_FILE="${KAPTAINPM_FILE}" \
    GIT_SHA="${GIT_SHA:-}" \
    BUILD_PLATFORM=test \
    GITHUB_OUTPUT="${GITHUB_OUTPUT}" \
    bash -c "cd '${TEST_DIR}' && '${SCRIPT}'"
}

final_product_lineage_data() {
  echo "${TEST_DIR}/kaptain-out/manifests/substituted/product-foo/kaptain-product-lineage-data.yaml"
}

# =============================================================================
# Happy path: outputs land where expected
# =============================================================================

@test "happy path: produces product lineage data CM and copies into substituted product tree" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  [ -f "$(final_product_lineage_data)" ]
  [ -f "${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/contents.yaml" ]
  [ -f "${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/contents-resolved.yaml" ]
  [ -f "${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/contract.yaml" ]
  [ -f "${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/resources.yaml" ]
  [ -f "${TEST_DIR}/kaptain-out/product-aggregate/generated-configmap/manifests/combined/configmap.yaml" ]
  [ -f "${TEST_DIR}/kaptain-out/product-aggregate/substitute-staging/kaptain-product-lineage-data.yaml" ]
}

@test "happy path: contents.yaml mirrors spec.contents from KaptainPM" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  local file="${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/contents.yaml"
  grep -q "alpha:1.0" "${file}"
  grep -q "beta:2.0" "${file}"
}

@test "happy path: contents-resolved.yaml is content-resolve's full-OCI-ref output" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  local file="${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/contents-resolved.yaml"
  grep -q "ghcr.io/org/alpha:1.0.0-manifests" "${file}"
  grep -q "ghcr.io/org/beta:2.0.0-manifests" "${file}"
}

@test "happy path: contract.yaml is a verbatim copy of the manifests contract" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  diff -q \
    "${TEST_DIR}/kaptain-out/manifests/contract/contract.yaml" \
    "${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/contract.yaml"
}

# =============================================================================
# resources.yaml inventory
# =============================================================================

@test "resources.yaml: includes every kind/name in the substituted product tree" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  local file="${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/resources.yaml"
  grep -q "path: deployment.yaml" "${file}"
  grep -q "path: service.yaml" "${file}"
  grep -q "kind: Deployment" "${file}"
  grep -q "kind: Service" "${file}"
}

@test "resources.yaml: includes self-reference for the product lineage data ConfigMap" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  local file="${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/resources.yaml"
  grep -q "path: kaptain-product-lineage-data.yaml" "${file}"
  grep -q "kind: ConfigMap" "${file}"
}

@test "resources.yaml: self-reference name uses project-name token (resolved post sub-round)" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  # The pre-substitute resources.yaml carries the ${ProjectName} token; the
  # final product lineage data file in the substituted tree must have it resolved.
  grep -q '\${ProjectName}' \
    "${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/resources.yaml"
  ! grep -q '\${ProjectName}' "$(final_product_lineage_data)"
}

@test "resources.yaml: handles a multi-document yaml file" {
  stage_preconditions
  cat > "${TEST_DIR}/kaptain-out/manifests/substituted/product-foo/multi.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: product-foo-extra-cm
---
apiVersion: v1
kind: Secret
metadata:
  name: product-foo-extra-secret
EOF
  run_script
  [ "${status}" -eq 0 ]
  local file="${TEST_DIR}/kaptain-out/product-aggregate/product-lineage-data/resources.yaml"
  grep -q "name: product-foo-extra-cm" "${file}"
  grep -q "name: product-foo-extra-secret" "${file}"
}

# =============================================================================
# Product lineage data CM metadata - additional labels and annotations
# =============================================================================

@test "metadata: kaptain.org/role label is kaptain-product-lineage-data" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  grep -q "kaptain.org/role: kaptain-product-lineage-data" "$(final_product_lineage_data)"
}

@test "metadata: kaptain.org/build-kind label is kubernetes-product-aggregate" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  grep -q "kaptain.org/build-kind: kubernetes-product-aggregate" "$(final_product_lineage_data)"
}

@test "metadata: kaptain.org/product-name label resolves to project name" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  grep -q "kaptain.org/product-name: product-foo" "$(final_product_lineage_data)"
}

@test "metadata: kaptain.org/product-short-name label resolves to short name" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  grep -q "kaptain.org/product-short-name: foo" "$(final_product_lineage_data)"
}

@test "metadata: kaptain.org/git-sha annotation present when GIT_SHA set" {
  stage_preconditions
  GIT_SHA=abc123def456 run_script
  [ "${status}" -eq 0 ]
  grep -q "kaptain.org/git-sha: abc123def456" "$(final_product_lineage_data)"
}

@test "metadata: kaptain.org/git-sha annotation absent when GIT_SHA empty" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  ! grep -q "kaptain.org/git-sha" "$(final_product_lineage_data)"
}

# =============================================================================
# CM body - data keys
# =============================================================================

@test "data keys: CM has one key per lineage data file" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  local final
  final="$(final_product_lineage_data)"
  grep -q "^  contents.yaml:" "${final}"
  grep -q "^  contents-resolved.yaml:" "${final}"
  grep -q "^  contract.yaml:" "${final}"
  grep -q "^  resources.yaml:" "${final}"
}

@test "data keys: product lineage data CM metadata.name resolves to project name" {
  stage_preconditions
  run_script
  [ "${status}" -eq 0 ]
  # ConfigMap is generated with NAME_CHECKSUM_INJECTION=false, no suffix, no
  # combined sub-path; the bare project-name token is the metadata.name.
  grep -q "^  name: product-foo$" "$(final_product_lineage_data)"
}

# =============================================================================
# Validation: missing inputs
# =============================================================================

@test "validation: missing substituted product dir fails with diagnostic" {
  stage_preconditions
  rm -rf "${TEST_DIR}/kaptain-out/manifests/substituted"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Substituted product directory not found"
  assert_output_contains "kubernetes-manifests-substitute"
}

@test "validation: missing contract.yaml fails with diagnostic" {
  stage_preconditions
  rm -f "${TEST_DIR}/kaptain-out/manifests/contract/contract.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Contract file not found"
  assert_output_contains "kubernetes-manifests-contract-generate"
}

@test "validation: missing contents-resolved.yaml fails with diagnostic" {
  stage_preconditions
  rm -f "${TEST_DIR}/kaptain-out/content/contents-resolved.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Resolved-contents file not found"
  assert_output_contains "kubernetes-product-aggregate"
}

@test "validation: missing tokens directory fails with diagnostic" {
  stage_preconditions
  rm -rf "${TEST_DIR}/kaptain-out/manifests/config"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Tokens directory not found"
  assert_output_contains "kubernetes-manifests-package-prepare"
}

@test "validation: missing KaptainPM file fails with diagnostic" {
  stage_preconditions
  rm -f "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "KaptainPM file not found"
}

@test "validation: missing PROJECT_NAME fails with diagnostic" {
  stage_preconditions
  PROJECT_NAME="" run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}
