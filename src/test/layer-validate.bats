#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/layer-validate
# Focuses on the always-on layerset dependency validation loop: pull each
# dep, confirm /KaptainPM.yaml is present, validate against the build's layer
# schema. All failure modes are hard fails - there is no opt-out.
#
# To avoid clobbering the real util/oci-scratch-extract, the script is run
# from an isolated mirror under TEST_DIR with a stubbed util dir.

load helpers

setup() {
  TEST_DIR=$(create_test_dir "layer-validate")

  # Mirror the on-disk layout the script expects, relative to SCRIPT_DIR.
  # The real layer-validate uses SCRIPT_DIR=$(dirname $0), then resolves
  # ../defaults, ../lib, ../util, and ../../schemas. Symlink the real ones
  # for everything except util/, which we stub.
  MIRROR_ROOT="${TEST_DIR}/mirror"
  mkdir -p "${MIRROR_ROOT}/scripts/main" "${MIRROR_ROOT}/scripts/util"
  cp "${PROJECT_ROOT}/src/scripts/main/layer-validate" "${MIRROR_ROOT}/scripts/main/layer-validate"
  ln -s "${PROJECT_ROOT}/src/scripts/defaults" "${MIRROR_ROOT}/scripts/defaults"
  ln -s "${PROJECT_ROOT}/src/scripts/lib" "${MIRROR_ROOT}/scripts/lib"
  ln -s "${PROJECT_ROOT}/src/schemas" "${MIRROR_ROOT}/schemas"
  SCRIPT="${MIRROR_ROOT}/scripts/main/layer-validate"

  # Stub oci-scratch-extract: behaviour controlled by MOCK_OCI_EXTRACT_MODE.
  cat > "${MIRROR_ROOT}/scripts/util/oci-scratch-extract" << 'STUB'
#!/usr/bin/env bash
# Args: $1 = image_ref, $2 = staging_dir, $3 = path inside image
# Modes:
#   success (default) - exit 0 and write a minimal KaptainPM.yaml to staging
#   fail              - exit 1
#   empty             - exit 0 but write nothing (image lacks the file)
mode="${MOCK_OCI_EXTRACT_MODE:-success}"
case "${mode}" in
  fail)
    exit 1
    ;;
  empty)
    exit 0
    ;;
  success)
    cat > "${2}/KaptainPM.yaml" << 'YAML'
apiVersion: kaptain.org/1.7
kind: KubeAppDockerDockerfile
metadata:
  labels: {}
  annotations: {}
spec:
  main:
    quality:
      branches:
        blockSlashes: true
YAML
    exit 0
    ;;
esac
exit 1
STUB
  chmod +x "${MIRROR_ROOT}/scripts/util/oci-scratch-extract"

  REPO_DIR="${TEST_DIR}/repo"
  mkdir -p "${REPO_DIR}"
  cd "${REPO_DIR}"

  export OUTPUT_SUB_PATH="kaptain-out"
  export DOCKER_PLATFORM="linux/amd64"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"
  export BUILD_PLATFORM="test"
  export IMAGE_BUILD_COMMAND="docker"

  SUB_DIR="${OUTPUT_SUB_PATH}/docker/substituted"
  mkdir -p "${SUB_DIR}"
  JSON_FILE="${SUB_DIR}/KaptainPM.json"

  # Mock check-jsonschema. Defaults to passing every call. Tests can flip
  # MOCK_JSONSCHEMA_FAIL_ON_DEPS=true to fail only for the per-dep validation
  # (detected by the path containing layer-validate/deps).
  mkdir -p "${MOCK_BIN_DIR}"
  cat > "${MOCK_BIN_DIR}/check-jsonschema" << 'MOCK'
#!/usr/bin/env bash
file_arg=""
for arg in "$@"; do
  case "${arg}" in
    --schemafile|--*) ;;
    *) file_arg="${arg}" ;;
  esac
done
if [[ "${MOCK_JSONSCHEMA_FAIL_ON_DEPS:-false}" == "true" && "${file_arg}" == *"layer-validate/deps"* ]]; then
  exit 1
fi
exit 0
MOCK
  chmod +x "${MOCK_BIN_DIR}/check-jsonschema"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

# Helper: write a layerset substituted JSON file with the given layer refs
write_layerset_json() {
  local layers_json="${1}"
  cat > "${JSON_FILE}" << EOF
{
  "apiVersion": "kaptain.org/1.7",
  "kind": "KubeAppDockerDockerfile",
  "metadata": {"labels": {}, "annotations": {}},
  "spec": {
    "layers": ${layers_json}
  }
}
EOF
}

# Helper: write a layer (not layerset) substituted JSON file
write_layer_json() {
  cat > "${JSON_FILE}" << 'EOF'
{
  "apiVersion": "kaptain.org/1.7",
  "kind": "KubeAppDockerDockerfile",
  "metadata": {"labels": {}, "annotations": {}},
  "spec": {
    "main": {
      "quality": {
        "branches": {"blockSlashes": true}
      }
    }
  }
}
EOF
}

# =============================================================================
# Layerset dependency validation - happy path
# =============================================================================

@test "layerset: all deps pull, contain manifest, pass schema" {
  export LAYER_TYPE="layerset"
  write_layerset_json '["ghcr.io/kube-kaptain/layer/quality-strict:1.0.0", "ghcr.io/kube-kaptain/layer/java-base:2.0.0"]'
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Layerset dependency validation passed"* ]]
  [[ "$output" == *"ok: ghcr.io/kube-kaptain/layer/quality-strict:1.0.0"* ]]
  [[ "$output" == *"ok: ghcr.io/kube-kaptain/layer/java-base:2.0.0"* ]]
}

# =============================================================================
# Layerset dependency validation - failure modes
# =============================================================================

@test "layerset: fails when oci-scratch-extract fails on a dep" {
  export LAYER_TYPE="layerset"
  export MOCK_OCI_EXTRACT_MODE=fail
  write_layerset_json '["ghcr.io/kube-kaptain/layer/quality-strict:1.0.0"]'
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Failed to pull dependency"* ]]
  [[ "$output" == *"Layerset dependency validation failed"* ]]
}

@test "layerset: fails when extract succeeds but writes no KaptainPM.yaml" {
  export LAYER_TYPE="layerset"
  export MOCK_OCI_EXTRACT_MODE=empty
  write_layerset_json '["ghcr.io/kube-kaptain/layer/quality-strict:1.0.0"]'
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"does not contain /KaptainPM.yaml"* ]]
  [[ "$output" == *"Layerset dependency validation failed"* ]]
}

@test "layerset: fails when dep KaptainPM.yaml fails schema validation" {
  export LAYER_TYPE="layerset"
  export MOCK_JSONSCHEMA_FAIL_ON_DEPS=true
  write_layerset_json '["ghcr.io/kube-kaptain/layer/quality-strict:1.0.0"]'
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"failed schema validation"* ]]
  [[ "$output" == *"Layerset dependency validation failed"* ]]
}

@test "layerset: fails when spec.layers is empty" {
  export LAYER_TYPE="layerset"
  write_layerset_json '[]'
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Layerset has no entries in spec.layers"* ]]
}

@test "layerset: continues checking remaining deps after a failure (collects all errors)" {
  export LAYER_TYPE="layerset"
  export MOCK_OCI_EXTRACT_MODE=fail
  write_layerset_json '["ghcr.io/kube-kaptain/layer/a:1.0.0", "ghcr.io/kube-kaptain/layer/b:1.0.0"]'
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  # Both refs should appear in output - script doesn't bail on first failure
  [[ "$output" == *"ghcr.io/kube-kaptain/layer/a:1.0.0"* ]]
  [[ "$output" == *"ghcr.io/kube-kaptain/layer/b:1.0.0"* ]]
}

# =============================================================================
# Layer (not layerset) - skips dep loop entirely
# =============================================================================

@test "layer: does not run layerset dependency validation" {
  export LAYER_TYPE="layer"
  write_layer_json
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"Layerset dependency validation"* ]]
}
