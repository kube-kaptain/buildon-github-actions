#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

SCRIPT="$SCRIPTS_DIR/load-final-kaptainpm-yaml"

setup() {
  local base_dir
  base_dir=$(create_test_dir "load-final-kaptainpm-yaml")
  export TEST_DIR="${base_dir}"

  # Script expects kaptainpm/final/KaptainPM.yaml relative to cwd
  mkdir -p "${TEST_DIR}/kaptainpm/final"

  # Capture outputs via GITHUB_OUTPUT
  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  touch "${GITHUB_OUTPUT}"

  export BUILD_KIND="test-build"
  unset REFERENCE_SCRIPT_OUTPUT 2>/dev/null || true
}

# Write a minimal valid KaptainPM.yaml with the given kind
write_pm() {
  local kind="${1:-test-build}"
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << EOF
apiVersion: kaptain.org/1.10
kind: ${kind}
EOF
}

run_script() {
  run bash -c "cd '${TEST_DIR}' && GITHUB_OUTPUT='${GITHUB_OUTPUT}' '${SCRIPT}'"
}

# Read a value from GITHUB_OUTPUT
github_output_value() {
  grep "^${1}=" "${GITHUB_OUTPUT}" | tail -1 | cut -d= -f2-
}

# Assert a value in GITHUB_OUTPUT
assert_github_output() {
  local name="${1}"
  local expected="${2}"
  local actual
  actual=$(github_output_value "${name}")
  if [[ "${actual}" != "${expected}" ]]; then
    echo "Expected ${name}=${expected}"
    echo "Actual ${name}=${actual}"
    return 1
  fi
}

# =============================================================================
# Kind validation
# =============================================================================

@test "fails when BUILD_KIND not set" {
  write_pm
  unset BUILD_KIND
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "BUILD_KIND is required"
}

@test "fails when KaptainPM.yaml is missing" {
  rm -rf "${TEST_DIR}/kaptainpm"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Project manifest not found"
}

@test "fails when kind is missing from yaml" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
EOF
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "does not declare a kind"
}

@test "fails when kind does not match BUILD_KIND" {
  write_pm "wrong-kind"
  run_script
  [ "${status}" -ne 0 ]
  assert_output_contains "Kind mismatch"
}

@test "succeeds when kind matches BUILD_KIND" {
  write_pm "test-build"
  run_script
  [ "${status}" -eq 0 ]
  assert_output_contains "Kind matched: test-build"
}

# =============================================================================
# Default-when-absent fields
# =============================================================================

@test "OUTPUT_SUB_PATH defaults to kaptain-out when absent" {
  write_pm
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "OUTPUT_SUB_PATH" "kaptain-out"
}

@test "OUTPUT_SUB_PATH uses value from yaml when present" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  global:
    outputSubPath: custom-out
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "OUTPUT_SUB_PATH" "custom-out"
}

@test "GITHUB_RELEASE_ENABLED defaults to true when absent" {
  write_pm
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "GITHUB_RELEASE_ENABLED" "true"
}

@test "GITHUB_RELEASE_ENABLED uses string value from yaml when present" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  platform:
    githubActions:
      release:
        enabled: "false"
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "GITHUB_RELEASE_ENABLED" "false"
}

# NOTE: yq's // operator treats bare boolean false as falsy, so the script
# falls back to the default "true". This is a known quirk - use the string
# "false" in KaptainPM.yaml to disable releases.
@test "GITHUB_RELEASE_ENABLED bare boolean false falls back to default true" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  platform:
    githubActions:
      release:
        enabled: false
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "GITHUB_RELEASE_ENABLED" "true"
}

@test "KUBERNETES_WORKLOAD_TYPE defaults to deployment when absent" {
  write_pm
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "KUBERNETES_WORKLOAD_TYPE" "deployment"
}

@test "KUBERNETES_WORKLOAD_TYPE uses value from yaml when present" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    generators:
      workload:
        type: statefulset
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "KUBERNETES_WORKLOAD_TYPE" "statefulset"
}

@test "KUBERNETES_CONFIGMAP_SUB_PATH defaults to src/configmap when absent" {
  write_pm
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "KUBERNETES_CONFIGMAP_SUB_PATH" "src/configmap"
}

@test "KUBERNETES_SECRET_TEMPLATE_SUB_PATH defaults to src/secret.template when absent" {
  write_pm
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "KUBERNETES_SECRET_TEMPLATE_SUB_PATH" "src/secret.template"
}

# =============================================================================
# JSON extraction fields
# =============================================================================

@test "DOCKER_REGISTRY_LOGINS exported as JSON when present" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    docker:
      logins:
        - registry: ghcr.io
          username: user
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_output_contains "DOCKER_REGISTRY_LOGINS"
  local value
  value=$(github_output_value "DOCKER_REGISTRY_LOGINS")
  [[ -n "${value}" ]]
  [[ "${value}" == *"ghcr.io"* ]]
}

@test "DOCKER_REGISTRY_LOGINS not exported when absent" {
  write_pm
  run_script
  [ "${status}" -eq 0 ]
  assert_output_not_contains "DOCKER_REGISTRY_LOGINS"
}

@test "VENDOR_HELM_RENDERED_MOVE_FILES exported as JSON when present" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    vendorHelmRendered:
      moveFiles:
        - from: a.yaml
          to: b.yaml
EOF
  run_script
  [ "${status}" -eq 0 ]
  local value
  value=$(github_output_value "VENDOR_HELM_RENDERED_MOVE_FILES")
  [[ -n "${value}" ]]
  [[ "${value}" == *"a.yaml"* ]]
}

@test "VENDOR_HELM_RENDERED_SED_REPLACE exported as JSON when present" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    vendorHelmRendered:
      sedReplace:
        - pattern: foo
          replacement: bar
          file: test.yaml
EOF
  run_script
  [ "${status}" -eq 0 ]
  local value
  value=$(github_output_value "VENDOR_HELM_RENDERED_SED_REPLACE")
  [[ -n "${value}" ]]
  [[ "${value}" == *"foo"* ]]
}

@test "VENDOR_HELM_RENDERED_YQ_TRANSFORM exported as JSON when present" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    vendorHelmRendered:
      yqTransform:
        - expression: ".foo = \"bar\""
          file: test.yaml
EOF
  run_script
  [ "${status}" -eq 0 ]
  local value
  value=$(github_output_value "VENDOR_HELM_RENDERED_YQ_TRANSFORM")
  [[ -n "${value}" ]]
}

@test "VENDOR_HELM_RENDERED_IMAGE_RETAGS exported as JSON when present" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    vendorHelmRendered:
      imageRetags:
        - sourceImage: foo:1.0
          targetImage: bar:1.0
EOF
  run_script
  [ "${status}" -eq 0 ]
  local value
  value=$(github_output_value "VENDOR_HELM_RENDERED_IMAGE_RETAGS")
  [[ -n "${value}" ]]
  [[ "${value}" == *"foo:1.0"* ]]
}

# =============================================================================
# Mapping loop - spot check a few fields
# =============================================================================

@test "exports TOKEN_DELIMITER_STYLE from yaml" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  global:
    tokens:
      delimiterStyle: "@@"
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "TOKEN_DELIMITER_STYLE" "@@"
}

@test "exports DOCKER_PLATFORM from yaml" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    docker:
      platform: linux/amd64,linux/arm64
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "DOCKER_PLATFORM" "linux/amd64,linux/arm64"
}

@test "exports LAYER_TOKEN_SUBSTITUTION string false from yaml" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    layer:
      tokenSubstitution: "false"
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "LAYER_TOKEN_SUBSTITUTION" "false"
}

@test "LAYER_TOKEN_SUBSTITUTION bare boolean false is skipped by mapping loop" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    layer:
      tokenSubstitution: false
EOF
  run_script
  [ "${status}" -eq 0 ]
  # bare false treated as falsy by yq //, so not exported
  local value
  value=$(github_output_value "LAYER_TOKEN_SUBSTITUTION")
  [[ -z "${value}" ]]
}

@test "exports LAYER_PACKAGING_BASE_IMAGE from yaml" {
  cat > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.10
kind: test-build
spec:
  main:
    layer:
      packagingBaseImage: alpine:3.19
EOF
  run_script
  [ "${status}" -eq 0 ]
  assert_github_output "LAYER_PACKAGING_BASE_IMAGE" "alpine:3.19"
}
