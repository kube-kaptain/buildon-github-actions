#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-package (phase B: zip the substituted tree).
# Assumes kubernetes-manifests-substitute has already run.

load helpers

setup() {
  export TEST_WORK_DIR=$(create_test_dir "manifests-pkg")
  export GITHUB_OUTPUT="$TEST_WORK_DIR/output"
  cd "$TEST_WORK_DIR"
  export OUTPUT_SUB_PATH="target"
  export PROJECT_NAME="my-project"
  export VERSION="1.2.3"

  # Simulate substitute has run - create the substituted/<project>/ tree
  mkdir -p "$OUTPUT_SUB_PATH/manifests/substituted/$PROJECT_NAME"
}

teardown() {
  dump_bats_result
  :
}

# Create manifest in substituted/<project>/ (simulating substitute has produced it)
create_substituted_manifest() {
  local filename="$1"
  local content="${2:-apiVersion: v1}"
  mkdir -p "$(dirname "$OUTPUT_SUB_PATH/manifests/substituted/$PROJECT_NAME/$filename")"
  echo "$content" > "$OUTPUT_SUB_PATH/manifests/substituted/$PROJECT_NAME/$filename"
}

@test "creates zip from substituted manifests" {
  create_substituted_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_FILE_NAME" "my-project-1.2.3-manifests.zip"
  [ -f "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" ]
}

@test "preserves directory structure in zip" {
  create_substituted_manifest "base/deployment.yaml"
  create_substituted_manifest "overlays/prod/patch.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -l "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/base/deployment.yaml"
  unzip -l "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/overlays/prod/patch.yaml"
}

@test "wraps contents in project-name directory" {
  create_substituted_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -l "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/"
  unzip -l "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/deployment.yaml"
}

@test "fails when substituted directory missing" {
  rm -rf "$OUTPUT_SUB_PATH/manifests/substituted"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Substituted manifests directory not found"
  assert_output_contains "kubernetes-manifests-substitute"
}

@test "fails when PROJECT_NAME missing" {
  unset PROJECT_NAME
  create_substituted_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when VERSION missing" {
  unset VERSION
  create_substituted_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "outputs zip path and filename" {
  create_substituted_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_SUB_PATH" "target/manifests/zip"
  assert_var_equals "MANIFESTS_ZIP_FILE_NAME" "my-project-1.2.3-manifests.zip"
}
