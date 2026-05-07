#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/vendor-helm-inject-build-details

load helpers

SCRIPT="$SCRIPTS_DIR/vendor-helm-inject-build-details"

setup() {
  TEST_DIR=$(create_test_dir "vendor-helm-inject-bd")
  REPO_DIR="${TEST_DIR}/repo"
  mkdir -p "${REPO_DIR}"
  cd "${REPO_DIR}"

  export OUTPUT_SUB_PATH="kaptain-out"
  export BUILD_PLATFORM="test"
  COMBINED_DIR="${REPO_DIR}/${OUTPUT_SUB_PATH}/manifests/combined"

  if ! command -v yq &>/dev/null; then
    skip "yq not available"
  fi
}

write_manifest() {
  local path="$1"
  local name="$2"
  mkdir -p "$(dirname "${path}")"
  cat > "${path}" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  labels:
    app: ${name}
  annotations:
    kaptain.org/generated-by: pre-existing
spec:
  replicas: 1
EOF
}

@test "stamps build-timestamp and built-by into every yaml under combined/" {
  mkdir -p "${COMBINED_DIR}"
  write_manifest "${COMBINED_DIR}/deployment.yaml" "alpha"
  write_manifest "${COMBINED_DIR}/sub/service.yaml" "beta"

  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  local stamp_a stamp_b built_a built_b
  stamp_a=$(yq eval '.metadata.annotations."kaptain.org/build-timestamp"' "${COMBINED_DIR}/deployment.yaml")
  stamp_b=$(yq eval '.metadata.annotations."kaptain.org/build-timestamp"' "${COMBINED_DIR}/sub/service.yaml")
  built_a=$(yq eval '.metadata.annotations."kaptain.org/built-by"' "${COMBINED_DIR}/deployment.yaml")
  built_b=$(yq eval '.metadata.annotations."kaptain.org/built-by"' "${COMBINED_DIR}/sub/service.yaml")

  [[ "${stamp_a}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
  [[ "${stamp_a}" == "${stamp_b}" ]]
  [[ "${built_a}" == "test" ]]
  [[ "${built_b}" == "test" ]]
}

@test "preserves pre-existing annotations and other content" {
  mkdir -p "${COMBINED_DIR}"
  write_manifest "${COMBINED_DIR}/deployment.yaml" "alpha"

  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  local generated_by replicas app_label
  generated_by=$(yq eval '.metadata.annotations."kaptain.org/generated-by"' "${COMBINED_DIR}/deployment.yaml")
  replicas=$(yq eval '.spec.replicas' "${COMBINED_DIR}/deployment.yaml")
  app_label=$(yq eval '.metadata.labels.app' "${COMBINED_DIR}/deployment.yaml")

  [[ "${generated_by}" == "pre-existing" ]]
  [[ "${replicas}" == "1" ]]
  [[ "${app_label}" == "alpha" ]]
}

@test "overwrites a pre-existing build-timestamp" {
  mkdir -p "${COMBINED_DIR}"
  cat > "${COMBINED_DIR}/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpha
  annotations:
    kaptain.org/build-timestamp: "1999-01-01T00:00:00Z"
EOF

  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  local stamp
  stamp=$(yq eval '.metadata.annotations."kaptain.org/build-timestamp"' "${COMBINED_DIR}/deployment.yaml")
  [[ "${stamp}" != "1999-01-01T00:00:00Z" ]]
  [[ "${stamp}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "fails when combined/ directory is missing" {
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Combined manifests directory not found"* ]]
}

@test "fails when combined/ directory is empty" {
  mkdir -p "${COMBINED_DIR}"

  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"No .yaml manifests"* ]]
}

@test "fails when a manifest has no annotations: anchor" {
  mkdir -p "${COMBINED_DIR}"
  cat > "${COMBINED_DIR}/no-anno.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: bare
data:
  key: value
EOF

  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"No 'annotations:' line"* ]]
}

@test "overwrites a pre-existing built-by" {
  mkdir -p "${COMBINED_DIR}"
  cat > "${COMBINED_DIR}/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpha
  annotations:
    kaptain.org/built-by: stale-value
EOF

  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  local built
  built=$(yq eval '.metadata.annotations."kaptain.org/built-by"' "${COMBINED_DIR}/deployment.yaml")
  [[ "${built}" == "test" ]]
}

teardown() {
  dump_bats_result
}
