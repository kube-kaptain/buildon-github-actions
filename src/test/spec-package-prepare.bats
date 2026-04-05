#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

SCRIPT="$SCRIPTS_DIR/spec-package-prepare"

# Tests are run via: bash -c "cd '${SPECS_ROOT}' && '${SCRIPT}'"
# so that src/specs/ and the output path are resolved from the temp dir.
setup() {
  local base_dir
  base_dir=$(create_test_dir "spec-package-prepare")
  export SPECS_ROOT="${base_dir}"
  export OUTPUT_DIR="${base_dir}/output"
  export YAML_DIR="${OUTPUT_DIR}/specs/yaml"
  export JSON_DIR="${OUTPUT_DIR}/specs/json"

  # Mock yq: outputs valid JSON for any input
  mkdir -p "${MOCK_BIN_DIR}"
  cat > "${MOCK_BIN_DIR}/yq" << 'MOCK'
#!/usr/bin/env bash
echo '{}'
MOCK
  chmod +x "${MOCK_BIN_DIR}/yq"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  export PROJECT_NAME="my-spec"
  export VERSION="1.2.3"
  export OUTPUT_SUB_PATH="${OUTPUT_DIR}"
  unset SPEC_PACKAGING_BASE_IMAGE 2>/dev/null || true
}

teardown() {
  :
}

run_script() {
  run bash -c "cd '${SPECS_ROOT}' && '${SCRIPT}'"
}

# =============================================================================
# Missing required variables
# =============================================================================

@test "fails when PROJECT_NAME not set" {
  unset PROJECT_NAME
  run_script
  [ "${status}" -ne 0 ]
}

@test "fails when VERSION not set" {
  unset VERSION
  run_script
  [ "${status}" -ne 0 ]
}

@test "fails when OUTPUT_SUB_PATH not set" {
  unset OUTPUT_SUB_PATH
  run_script
  [ "${status}" -ne 0 ]
}

# =============================================================================
# Nothing to package
# =============================================================================

@test "fails when src/specs is absent and yaml dir is empty" {
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "No spec YAML files to package"
}

@test "fails when src/specs exists but has no matching files and yaml dir is empty" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "No spec YAML files to package"
}

@test "fails when src/specs has only non-matching yaml files" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/other-project.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Unexpected file"
}

# =============================================================================
# Fixed spec files from src/specs/
# =============================================================================

@test "succeeds with one matching yaml in src/specs/" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
}

@test "copies yaml file to output/specs/yaml/ with version suffix" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  [ -f "${YAML_DIR}/my-spec-1.2.3.yaml" ]
}

@test "creates json file in output/specs/json/ with version suffix" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  [ -f "${JSON_DIR}/my-spec-1.2.3.json" ]
}

@test "handles multiple matching yaml files in src/specs/" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  touch "${SPECS_ROOT}/src/specs/my-spec-layer.yaml"
  run_script
  [ "${status}" -eq 0 ]
  [ -f "${YAML_DIR}/my-spec-1.2.3.yaml" ]
  [ -f "${YAML_DIR}/my-spec-layer-1.2.3.yaml" ]
  [ -f "${JSON_DIR}/my-spec-1.2.3.json" ]
  [ -f "${JSON_DIR}/my-spec-layer-1.2.3.json" ]
}

# =============================================================================
# Hook-generated files (pre-placed in yaml dir)
# =============================================================================

@test "succeeds when yaml dir is pre-populated by hook and src/specs is absent" {
  mkdir -p "${YAML_DIR}"
  touch "${YAML_DIR}/my-spec-1.2.3.yaml"
  run_script
  [ "${status}" -eq 0 ]
}

@test "processes hook-generated yaml to json" {
  mkdir -p "${YAML_DIR}"
  touch "${YAML_DIR}/my-spec-1.2.3.yaml"
  run_script
  [ "${status}" -eq 0 ]
  [ -f "${JSON_DIR}/my-spec-1.2.3.json" ]
}

@test "succeeds with mix of hook-generated and src/specs files" {
  mkdir -p "${YAML_DIR}" "${SPECS_ROOT}/src/specs"
  touch "${YAML_DIR}/my-spec-generated-1.2.3.yaml"
  touch "${SPECS_ROOT}/src/specs/my-spec-fixed.yaml"
  run_script
  [ "${status}" -eq 0 ]
  [ -f "${YAML_DIR}/my-spec-generated-1.2.3.yaml" ]
  [ -f "${YAML_DIR}/my-spec-fixed-1.2.3.yaml" ]
}

# =============================================================================
# Unexpected files in src/specs/
# =============================================================================

@test "fails when src/specs contains a file with wrong project name prefix" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/other-project.yaml"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Unexpected file"
  assert_output_contains "other-project.yaml"
}

@test "fails when src/specs contains a non-yaml file" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.json"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Unexpected file"
  assert_output_contains "my-spec.json"
}

@test "fails when src/specs contains a README" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/README.md"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Unexpected file"
}

@test "reports all unexpected files and valid count before failing" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/README.md"
  touch "${SPECS_ROOT}/src/specs/other-project.yaml"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "README.md"
  assert_output_contains "other-project.yaml"
  assert_output_contains "1 valid file(s) found"
}

# =============================================================================
# Collision detection
# =============================================================================

@test "fails when src/specs file would overwrite hook-generated file" {
  mkdir -p "${YAML_DIR}" "${SPECS_ROOT}/src/specs"
  touch "${YAML_DIR}/my-spec-1.2.3.yaml"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Collision"
}

# =============================================================================
# Dockerfile generation
# =============================================================================

@test "generates Dockerfile in output/specs/" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/specs/Dockerfile" ]
}

@test "Dockerfile contains FROM scratch by default" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  grep -q "^FROM scratch" "${OUTPUT_DIR}/specs/Dockerfile"
}

@test "Dockerfile contains COPY lines for yaml and json files" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  grep -q "COPY yaml/my-spec-1.2.3.yaml /" "${OUTPUT_DIR}/specs/Dockerfile"
  grep -q "COPY json/my-spec-1.2.3.json /" "${OUTPUT_DIR}/specs/Dockerfile"
}

@test "Dockerfile declares build args and uses them in labels" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  grep -q 'ARG VERSION' "${OUTPUT_DIR}/specs/Dockerfile"
  grep -q 'ARG PROJECT_NAME' "${OUTPUT_DIR}/specs/Dockerfile"
  grep -q 'ARG DOCKER_IMAGE_NAME' "${OUTPUT_DIR}/specs/Dockerfile"
  grep -q 'LABEL version=${VERSION}' "${OUTPUT_DIR}/specs/Dockerfile"
  grep -q 'LABEL project.name=${PROJECT_NAME}' "${OUTPUT_DIR}/specs/Dockerfile"
  grep -q 'LABEL image.name=${DOCKER_IMAGE_NAME}' "${OUTPUT_DIR}/specs/Dockerfile"
}

@test "uses SPEC_PACKAGING_BASE_IMAGE when set" {
  export SPEC_PACKAGING_BASE_IMAGE="gcr.io/distroless/static:nonroot"
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  grep -q "^FROM gcr.io/distroless/static:nonroot" "${OUTPUT_DIR}/specs/Dockerfile"
}

# =============================================================================
# Outputs
# =============================================================================

@test "outputs SPEC_DOCKER_FILES starting with Dockerfile" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  assert_output_contains "SPEC_DOCKER_FILES=Dockerfile,"
}

@test "outputs SPEC_DOCKER_FILES with yaml and json paths" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  assert_var_equals "SPEC_DOCKER_FILES" "Dockerfile,yaml/my-spec-1.2.3.yaml,json/my-spec-1.2.3.json"
}

@test "outputs DOCKERFILE_SUB_PATH pointing to specs dir" {
  mkdir -p "${SPECS_ROOT}/src/specs"
  touch "${SPECS_ROOT}/src/specs/my-spec.yaml"
  run_script
  [ "${status}" -eq 0 ]
  assert_var_equals "DOCKERFILE_SUB_PATH" "${OUTPUT_DIR}/specs"
}
