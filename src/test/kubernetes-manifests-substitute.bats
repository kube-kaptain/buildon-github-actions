#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-substitute (phase A: copy + token substitution).
# Assumes kubernetes-manifests-package-prepare has already run.

load helpers

setup() {
  export TEST_WORK_DIR=$(create_test_dir "manifests-sub")
  export GITHUB_OUTPUT="$TEST_WORK_DIR/output"
  cd "$TEST_WORK_DIR"
  export OUTPUT_SUB_PATH="target"
  export PROJECT_NAME="my-project"
  export VERSION="1.2.3"

  # Simulate prepare has run - create directory structure
  mkdir -p "$OUTPUT_SUB_PATH/manifests/combined"
  mkdir -p "$OUTPUT_SUB_PATH/manifests/config"
}

teardown() {
  :
}

# Create manifest in combined/ (simulating prepare has copied it)
create_combined_manifest() {
  local filename="$1"
  local content="${2:-apiVersion: v1}"
  mkdir -p "$(dirname "$OUTPUT_SUB_PATH/manifests/combined/$filename")"
  echo "$content" > "$OUTPUT_SUB_PATH/manifests/combined/$filename"
}

# Create token in config/ (simulating prepare has created it)
create_token() {
  local name="$1"
  local value="$2"
  mkdir -p "$(dirname "$OUTPUT_SUB_PATH/manifests/config/$name")"
  printf '%s' "$value" > "$OUTPUT_SUB_PATH/manifests/config/$name"
}

@test "copies combined to substituted/<project>/" {
  create_combined_manifest "deployment.yaml"
  create_token "ProjectName" "my-project"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/substituted/my-project/deployment.yaml" ]
}

@test "substitutes tokens in manifests" {
  create_combined_manifest "deployment.yaml" 'name: ${ProjectName}-app'
  create_token "ProjectName" "my-project"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -eq 0 ]
  grep -q "name: my-project-app" "$OUTPUT_SUB_PATH/manifests/substituted/my-project/deployment.yaml"
}

@test "substitutes multiple tokens" {
  create_combined_manifest "deployment.yaml" 'image: ${DockerImageName}:${DockerTag}'
  create_token "DockerImageName" "org/my-image"
  create_token "DockerTag" "1.2.3"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -eq 0 ]
  grep -q "image: org/my-image:1.2.3" "$OUTPUT_SUB_PATH/manifests/substituted/my-project/deployment.yaml"
}

@test "preserves directory structure in substituted tree" {
  create_combined_manifest "base/deployment.yaml"
  create_combined_manifest "overlays/prod/patch.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/substituted/my-project/base/deployment.yaml" ]
  [ -f "$OUTPUT_SUB_PATH/manifests/substituted/my-project/overlays/prod/patch.yaml" ]
}

@test "fails when combined directory missing" {
  rm -rf "$OUTPUT_SUB_PATH/manifests/combined"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -ne 0 ]
  assert_output_contains "Combined manifests directory not found"
  assert_output_contains "kubernetes-manifests-package-prepare"
}

@test "fails when config directory missing" {
  rm -rf "$OUTPUT_SUB_PATH/manifests/config"
  create_combined_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -ne 0 ]
  assert_output_contains "Config/tokens directory not found"
  assert_output_contains "kubernetes-manifests-package-prepare"
}

@test "fails when PROJECT_NAME missing" {
  unset PROJECT_NAME
  create_combined_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when VERSION missing" {
  unset VERSION
  create_combined_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "uses mustache token style" {
  export TOKEN_DELIMITER_STYLE="mustache"
  create_combined_manifest "deployment.yaml" 'name: {{ ProjectName }}'
  create_token "ProjectName" "my-project"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -eq 0 ]
  grep -q "name: my-project" "$OUTPUT_SUB_PATH/manifests/substituted/my-project/deployment.yaml"
}

@test "fails with unknown substitution token style" {
  export TOKEN_DELIMITER_STYLE="unknown"
  create_combined_manifest "deployment.yaml" 'name: {{ProjectName}}'
  create_token "ProjectName" "my-project"

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown token style"
}

@test "leaves unmatched tokens unchanged" {
  create_combined_manifest "deployment.yaml" 'value: ${UndefinedToken}'

  run "$SCRIPTS_DIR/kubernetes-manifests-substitute"
  [ "$status" -eq 0 ]
  grep -q 'value: ${UndefinedToken}' "$OUTPUT_SUB_PATH/manifests/substituted/my-project/deployment.yaml"
}
