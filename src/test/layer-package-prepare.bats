#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/layer-package-prepare
# Covers: project name detection (prefix/suffix), KaptainPM.yaml XOR between
# source_dir and context_dir, case-sensitive filename validation, layerset
# extras enforcement, copy behaviour.

load helpers

SCRIPT="$SCRIPTS_DIR/layer-package-prepare"

setup() {
  TEST_DIR=$(create_test_dir "layer-package-prepare")
  REPO_DIR="${TEST_DIR}/repo"
  mkdir -p "${REPO_DIR}"
  cd "${REPO_DIR}"

  export VERSION="1.0.0"
  export REPOSITORY_OWNER="kube-kaptain"
  export REPOSITORY_NAME="layer-test"
  export OUTPUT_SUB_PATH="kaptain-out"
  export LAYER_PACKAGING_BASE_IMAGE="scratch"
  export BUILD_PLATFORM="test"

  # Mock check-jsonschema (schema files themselves are real; we don't want to
  # validate against them in these tests, just exercise the script's own logic)
  mkdir -p "${MOCK_BIN_DIR}"
  cat > "${MOCK_BIN_DIR}/check-jsonschema" << 'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
  chmod +x "${MOCK_BIN_DIR}/check-jsonschema"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  # Mock docker for the layerset verification loop (artifact-exists). Defaults
  # to "exists" so the happy-path tests don't need to opt in. Individual tests
  # can flip MOCK_DOCKER_MANIFEST_EXISTS=false to exercise the failure path.
  export IMAGE_BUILD_COMMAND="docker"
  export MOCK_DOCKER_MANIFEST_EXISTS=true
  setup_mock_docker

  if ! command -v yq &>/dev/null; then
    skip "yq not available"
  fi
}

# Helper: write a minimal valid layer KaptainPM.yaml to a given path
write_layer_pm() {
  local target="${1}"
  mkdir -p "$(dirname "${target}")"
  cat > "${target}" << 'EOF'
apiVersion: kaptain.org/1.8
kind: kubernetes-app-docker-dockerfile
metadata:
  labels: {}
  annotations: {}
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
}

# Helper: write a minimal valid layerset KaptainPM.yaml to a given path
write_layerset_pm() {
  local target="${1}"
  mkdir -p "$(dirname "${target}")"
  cat > "${target}" << 'EOF'
apiVersion: kaptain.org/1.8
kind: kubernetes-app-docker-dockerfile
metadata:
  labels: {}
  annotations: {}
spec:
  layers:
    - ghcr.io/kube-kaptain/quality/quality-strict:1.0.0
EOF
}

# =============================================================================
# PROJECT_NAME detection - prefix and suffix
# =============================================================================

@test "fails when PROJECT_NAME has no layer or layerset prefix or suffix" {
  export PROJECT_NAME="something-else"
  write_layer_pm "src/layer/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"must start or end with"* ]]
}

@test "detects layer from prefix (layer-foo)" {
  export PROJECT_NAME="layer-foo"
  write_layer_pm "src/layer/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Layer type: layer"* ]]
}

@test "detects layer from suffix (foo-layer)" {
  export PROJECT_NAME="foo-layer"
  write_layer_pm "src/layer/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Layer type: layer"* ]]
}

@test "detects layerset from prefix (layerset-foo)" {
  export PROJECT_NAME="layerset-foo"
  write_layerset_pm "src/layerset/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Layer type: layerset"* ]]
}

@test "detects layerset from suffix (foo-layerset)" {
  export PROJECT_NAME="foo-layerset"
  write_layerset_pm "src/layerset/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Layer type: layerset"* ]]
}

@test "layerset suffix wins over layer suffix ambiguity (my-layerset)" {
  # my-layerset must be classified as layerset, not layer. The script checks
  # layerset first to avoid the ambiguity.
  export PROJECT_NAME="my-layerset"
  write_layerset_pm "src/layerset/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Layer type: layerset"* ]]
}

# =============================================================================
# XOR presence: neither / both
# =============================================================================

@test "fails when KaptainPM.yaml is in neither source_dir nor context_dir" {
  export PROJECT_NAME="layer-foo"
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"not found in src/layer/"* ]]
}

@test "fails when KaptainPM.yaml is in both source_dir and context_dir" {
  export PROJECT_NAME="layer-foo"
  write_layer_pm "src/layer/KaptainPM.yaml"
  write_layer_pm "${OUTPUT_SUB_PATH}/layer-build/context/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"present in both"* ]]
  [[ "$output" == *"pick one"* ]]
}

# =============================================================================
# Case-sensitive validation
# =============================================================================

@test "fails on case mismatch in source_dir" {
  export PROJECT_NAME="layer-foo"
  write_layer_pm "src/layer/kaptainpm.yaml"
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"case mismatch"* ]]
  [[ "$output" == *"failed validation"* ]]
}

# =============================================================================
# Layerset extras check - source_dir and context_dir
# =============================================================================

@test "layerset fails when source_dir has extra files" {
  export PROJECT_NAME="layerset-foo"
  write_layerset_pm "src/layerset/KaptainPM.yaml"
  echo "extra" > "src/layerset/unexpected.txt"
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Unexpected file in src/layerset/"* ]]
  [[ "$output" == *"unexpected.txt"* ]]
}

@test "layerset fails when context_dir has extra files alongside the manifest" {
  export PROJECT_NAME="layerset-foo"
  mkdir -p "${OUTPUT_SUB_PATH}/layer-build/context"
  write_layerset_pm "${OUTPUT_SUB_PATH}/layer-build/context/KaptainPM.yaml"
  echo "extra" > "${OUTPUT_SUB_PATH}/layer-build/context/unexpected.txt"
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Unexpected file in"* ]]
  [[ "$output" == *"unexpected.txt"* ]]
}

# =============================================================================
# Layerset from pre-populated context_dir (no source_dir)
# =============================================================================

@test "layerset accepts KaptainPM.yaml pre-populated in context_dir" {
  export PROJECT_NAME="layerset-foo"
  mkdir -p "${OUTPUT_SUB_PATH}/layer-build/context"
  write_layerset_pm "${OUTPUT_SUB_PATH}/layer-build/context/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "${OUTPUT_SUB_PATH}/layer-build/context/KaptainPM.yaml" ]]
  [[ -f "${OUTPUT_SUB_PATH}/layer-build/context/Dockerfile" ]]
}

# =============================================================================
# Layer copy: all source files flow through
# =============================================================================

@test "layer copies all source files including non-KaptainPM ones" {
  export PROJECT_NAME="layer-foo"
  write_layer_pm "src/layer/KaptainPM.yaml"
  echo "static content" > "src/layer/extra-static.txt"
  mkdir -p "src/layer/subdir"
  echo "nested" > "src/layer/subdir/nested.txt"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "${OUTPUT_SUB_PATH}/layer-build/context/KaptainPM.yaml" ]]
  [[ -f "${OUTPUT_SUB_PATH}/layer-build/context/extra-static.txt" ]]
  [[ -f "${OUTPUT_SUB_PATH}/layer-build/context/subdir/nested.txt" ]]
}

# =============================================================================
# Layer from pre-populated context_dir (no source_dir)
# =============================================================================

@test "layer accepts KaptainPM.yaml pre-populated in context_dir (no source_dir)" {
  export PROJECT_NAME="layer-foo"
  mkdir -p "${OUTPUT_SUB_PATH}/layer-build/context"
  write_layer_pm "${OUTPUT_SUB_PATH}/layer-build/context/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "${OUTPUT_SUB_PATH}/layer-build/context/KaptainPM.yaml" ]]
  [[ -f "${OUTPUT_SUB_PATH}/layer-build/context/Dockerfile" ]]
}

# =============================================================================
# context_dir is not wiped at script start
# =============================================================================

# =============================================================================
# Layerset remote-existence verification loop
# =============================================================================

@test "layerset verifies all spec.layers exist at remote" {
  export PROJECT_NAME="layerset-foo"
  export MOCK_DOCKER_MANIFEST_EXISTS=true
  write_layerset_pm "src/layerset/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Verifying remote existence"* ]]
  [[ "$output" == *"Remote existence verification complete"* ]]
}

@test "layerset fails when a spec.layers entry does not exist at remote" {
  export PROJECT_NAME="layerset-foo"
  export MOCK_DOCKER_MANIFEST_EXISTS=false
  write_layerset_pm "src/layerset/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Layer dependency does not exist at remote"* ]]
}

@test "layer path does not run remote-existence verification" {
  export PROJECT_NAME="layer-foo"
  write_layer_pm "src/layer/KaptainPM.yaml"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"Verifying remote existence"* ]]
}

@test "does not remove pre-existing files in context_dir (no rm-rf)" {
  export PROJECT_NAME="layer-foo"
  write_layer_pm "src/layer/KaptainPM.yaml"
  mkdir -p "${OUTPUT_SUB_PATH}/layer-build/context"
  echo "pre-existing" > "${OUTPUT_SUB_PATH}/layer-build/context/hook-generated.txt"
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "${OUTPUT_SUB_PATH}/layer-build/context/hook-generated.txt" ]]
  run cat "${OUTPUT_SUB_PATH}/layer-build/context/hook-generated.txt"
  [[ "$output" == "pre-existing" ]]
}
