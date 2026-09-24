#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-run-package: provenance and contents zips.
# Docker is mocked; the images are not under test.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-run-package"

PROVENANCE_STAGES=(
  config-defaults
  config-in-repo
  config-builtins
  config-final
  manifests-aggregated
  manifests-pruned
  manifests-substituted
  manifests-modified
  manifests-modifier-working
  manifests-checksummed
  manifests-final
)

setup() {
  TEST_DIR=$(create_test_dir "kubernetes-run-package")
  cd "${TEST_DIR}"

  setup_mock_docker
  export MOCK_DOCKER_IMAGE_EXISTS="false" MOCK_DOCKER_IMAGE_INSPECT_EXISTS="false"

  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"

  export OUTPUT_SUB_PATH="kaptain-out"
  export PROJECT_NAME="run-env-test"
  export VERSION="1.0.0"
  export BUILD_MODE="build_server"
  export IMAGE_BUILD_COMMAND="docker"
  export DOCKER_TARGET_REGISTRY="registry.example.com"
  export DOCKER_TARGET_NAMESPACE="team"
  export DOCKER_IMAGE_NAME="run-env-test"
  export DOCKER_TAG="1.0.0"
  export DOCKER_PUSH_IMAGE_LIST_FILE="${TEST_DIR}/image-uris"
  : > "${DOCKER_PUSH_IMAGE_LIST_FILE}"
  export RUN_SECRETS_ENCRYPTION_TYPE="age"
  export SECRETS_SUB_PATH="src/secrets"
  mkdir -p "${SECRETS_SUB_PATH}"
  printf '%s' 'ciphertext' > "${SECRETS_SUB_PATH}/DbPassword.age"

  write_stages "kaptain-out/run-environment"
}

write_stages() {
  local base="${1}" dir
  for dir in "${PROVENANCE_STAGES[@]}"; do
    mkdir -p "${base}/${dir}"
    cat > "${base}/${dir}/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app
data:
  mode: plain
EOF
  done
  export ENVIRONMENT_WORKLOAD_CONTENTS_SUB_PATH="${base}/manifests-final"
  mkdir -p kaptain-out/run-consumption-report
  printf 'report: yes\n' > "kaptain-out/run-consumption-report/${PROJECT_NAME}-${VERSION}-consumption-report.yaml"
}

provenance_zip() {
  printf '%s' "kaptain-out/run-package/zip/${PROJECT_NAME}-${VERSION}-environment-provenance.zip"
}

provenance_listing() {
  unzip -Z1 "$(provenance_zip)"
}

@test "run-package: the provenance zip is named environment-provenance and no report zip is built" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$(provenance_zip)" ]
  [ "$(find kaptain-out/run-package/zip -name '*consumption-report*' | grep -c .)" -eq 0 ]
  [ "$(find kaptain-out/run-package/zip -name '*workload-contents-provenance*' | grep -c .)" -eq 0 ]
}

@test "run-package: the provenance zip holds the report, every config layer and every manifests stage" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local listing dir
  listing=$(provenance_listing)
  grep -qx "${PROJECT_NAME}-${VERSION}-consumption-report.yaml" <<< "${listing}"
  for dir in "${PROVENANCE_STAGES[@]}"; do
    grep -qx "${dir}/configmap.yaml" <<< "${listing}" || { echo "missing ${dir}"; return 1; }
  done
}

@test "run-package: a stage identical to the one before it is still included" {
  # pruned and modified equal their predecessors.
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  diff -r kaptain-out/run-environment/manifests-aggregated kaptain-out/run-environment/manifests-pruned
  provenance_listing | grep -qx "manifests-pruned/configmap.yaml"
  provenance_listing | grep -qx "manifests-modified/configmap.yaml"
}

@test "run-package: env builds carry the encrypted secret values as config-secrets" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  provenance_listing | grep -qx "config-secrets/DbPassword.age"
}

@test "run-package: run-platform builds carry no config-secrets" {
  export PROJECT_NAME="run-platform-test"
  export DOCKER_IMAGE_NAME="run-platform-test"
  write_stages "kaptain-out/run-platform-meta-environment"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(provenance_listing | grep -c '^config-secrets/')" -eq 0 ]
  provenance_listing | grep -qx "manifests-final/configmap.yaml"
}

@test "run-package: a missing consumption report fails" {
  rm "kaptain-out/run-consumption-report/${PROJECT_NAME}-${VERSION}-consumption-report.yaml"
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "Consumption report not found"
}

@test "run-package: the artifacts image carries the contents and provenance zips only" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local context="kaptain-out/run-package/artifacts-image-context"
  [ -f "${context}/${PROJECT_NAME}-${VERSION}-environment-contents.zip" ]
  [ -f "${context}/${PROJECT_NAME}-${VERSION}-environment-provenance.zip" ]
  [ "$(find "${context}" -name '*.zip' | grep -c .)" -eq 2 ]
}

@test "run-package: publishes the provenance zip path and no report zip path" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx "RUN_PROVENANCE_ZIP_FILE=$(provenance_zip)" "${GITHUB_OUTPUT}"
  [ "$(grep -c '^RUN_CONSUMPTION_REPORT_ZIP_FILE=' "${GITHUB_OUTPUT}")" -eq 0 ]
}

# =============================================================================
# Contents zip layout: <project>, <project>-namespaced, <project>-cluster-scoped
# =============================================================================

contents_zip() {
  printf '%s' "kaptain-out/run-package/zip/${PROJECT_NAME}-${VERSION}-environment-contents.zip"
}

contents_listing() {
  unzip -Z1 "$(contents_zip)"
}

write_final_cluster_role() {
  cat > "${ENVIRONMENT_WORKLOAD_CONTENTS_SUB_PATH}/clusterrole.yaml" << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app
rules: []
EOF
}

@test "run-package: contents zip without a carve-out holds only the whole set" {
  write_final_cluster_role
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  contents_listing | grep -qx "${PROJECT_NAME}/configmap.yaml"
  contents_listing | grep -qx "${PROJECT_NAME}/clusterrole.yaml"
  [ "$(contents_listing | grep -c -E "^${PROJECT_NAME}-(namespaced|cluster-scoped)/")" -eq 0 ]
}

@test "run-package: an env carve-out adds namespaced and cluster-scoped beside the whole set" {
  export ENV_CLUSTER_SCOPED_DELEGATION="parent"
  write_final_cluster_role
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local listing
  listing=$(contents_listing)
  grep -qx "${PROJECT_NAME}/configmap.yaml" <<< "${listing}"
  grep -qx "${PROJECT_NAME}/clusterrole.yaml" <<< "${listing}"
  grep -qx "${PROJECT_NAME}-namespaced/configmap.yaml" <<< "${listing}"
  [ "$(grep -c "^${PROJECT_NAME}-namespaced/clusterrole.yaml$" <<< "${listing}")" -eq 0 ]
  grep -qx "${PROJECT_NAME}-cluster-scoped/clusterrole.yaml" <<< "${listing}"
  [ "$(grep -c "^${PROJECT_NAME}-cluster-scoped/configmap.yaml$" <<< "${listing}")" -eq 0 ]
  [ "$(grep -c 'cluster-scoped-on-behalf' <<< "${listing}")" -eq 0 ]
}

@test "run-package: a run-platform carries its children's sets under cluster-scoped, not in the whole set" {
  export PROJECT_NAME="run-platform-test"
  export DOCKER_IMAGE_NAME="run-platform-test"
  write_stages "kaptain-out/run-platform-meta-environment"
  mkdir -p kaptain-out/run-platform/cluster-scoped-on-behalf/run-child
  cat > kaptain-out/run-platform/cluster-scoped-on-behalf/run-child/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: run-child
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local listing
  listing=$(contents_listing)
  grep -qx "${PROJECT_NAME}-cluster-scoped/run-child/namespace.yaml" <<< "${listing}"
  [ "$(grep -c "^${PROJECT_NAME}/run-child/" <<< "${listing}")" -eq 0 ]
  [ "$(grep -c "^${PROJECT_NAME}-namespaced/" <<< "${listing}")" -eq 0 ]
}

teardown() {
  dump_bats_result
}
