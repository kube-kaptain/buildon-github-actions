#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export TEST_WORK_DIR=$(create_test_dir "manifests-prep")
  export GITHUB_OUTPUT="$TEST_WORK_DIR/output"
  cd "$TEST_WORK_DIR"
  # Use relative paths from within the temp dir
  export TEST_MANIFESTS="manifests"
  export OUTPUT_SUB_PATH="target"
  export CONFIG_DIR="config"
  mkdir -p "$TEST_MANIFESTS" "$OUTPUT_SUB_PATH" "$CONFIG_DIR"
}

teardown() {
  :
}

# Create sample manifest file
create_manifest() {
  local filename="$1"
  local content="${2:-apiVersion: v1}"
  mkdir -p "$(dirname "$TEST_MANIFESTS/$filename")"
  echo "$content" > "$TEST_MANIFESTS/$filename"
}

# Create user config token
create_config_token() {
  local name="$1"
  local value="$2"
  mkdir -p "$(dirname "$CONFIG_DIR/$name")"
  printf '%s' "$value" > "$CONFIG_DIR/$name"
}

# Required env vars for most tests
set_required_env() {
  export PROJECT_NAME="my-project"
  export VERSION="1.2.3"
  export IS_RELEASE="true"
  export DOCKER_TAG="1.2.3"
  export DOCKER_IMAGE_NAME="my-project"
  export MANIFESTS_SUB_PATH="$TEST_MANIFESTS"
  export CONFIG_SUB_PATH="$CONFIG_DIR"
}

@test "creates target directory structure" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_SUB_PATH/manifests/combined" ]
  [ -d "$OUTPUT_SUB_PATH/manifests/config" ]
  [ -d "$OUTPUT_SUB_PATH/manifests/zip" ]
}

@test "writes built-in tokens as files" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]

  # Default style is PascalCase
  [ -f "$OUTPUT_SUB_PATH/manifests/config/ProjectName" ]
  [ -f "$OUTPUT_SUB_PATH/manifests/config/Version" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/ProjectName")" = "my-project" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/Version")" = "1.2.3" ]
}

@test "copies user config tokens" {
  set_required_env
  create_manifest "deployment.yaml"
  create_config_token "CustomVar" "custom-value"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/config/CustomVar" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/CustomVar")" = "custom-value" ]
}

@test "validates user config names match token-name-style" {
  set_required_env
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_NAME_VALIDATION="MATCH"
  create_manifest "deployment.yaml"
  create_config_token "invalid_name" "value"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid"
}

@test "allows any name style when validation is ALL" {
  set_required_env
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_NAME_VALIDATION="ALL"
  create_manifest "deployment.yaml"
  create_config_token "my_custom_var" "value"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/config/my_custom_var" ]
}

@test "blocks builtin override by default" {
  set_required_env
  create_manifest "deployment.yaml"
  create_config_token "ProjectName" "overridden"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "override"
  assert_output_contains "ProjectName"
}

@test "allows builtin override when enabled" {
  set_required_env
  export ALLOW_BUILTIN_TOKEN_OVERRIDE="true"
  create_manifest "deployment.yaml"
  create_config_token "ProjectName" "overridden-value"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]

  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/ProjectName")" = "overridden-value" ]
}

@test "fails when manifests directory not found and combined is empty" {
  set_required_env
  export MANIFESTS_SUB_PATH="/nonexistent/path"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "Source directory not found"
  assert_output_contains "No manifests to package"
}

@test "fails when manifests directory is empty and combined is empty" {
  set_required_env

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "Source directory empty"
  assert_output_contains "No manifests to package"
}

@test "fails when PROJECT_NAME missing" {
  export VERSION="1.0.0"
  export DOCKER_TAG="1.0.0"
  export DOCKER_IMAGE_NAME="test"
  export MANIFESTS_SUB_PATH="$TEST_MANIFESTS"
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when VERSION missing" {
  export PROJECT_NAME="my-project"
  export DOCKER_TAG="1.0.0"
  export DOCKER_IMAGE_NAME="test"
  export MANIFESTS_SUB_PATH="$TEST_MANIFESTS"
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "defaults MANIFESTS_SUB_PATH to src/kubernetes" {
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export DOCKER_TAG="1.0.0"
  export DOCKER_IMAGE_NAME="test"
  unset MANIFESTS_SUB_PATH

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "Source directory not found: src/kubernetes"
  assert_output_contains "No manifests to package"
}

@test "defaults OUTPUT_SUB_PATH to target" {
  set_required_env
  unset OUTPUT_SUB_PATH
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]
  assert_output_contains "Output: target"
}

@test "reports yaml file count" {
  set_required_env
  create_manifest "deployment.yaml"
  create_manifest "service.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]
  assert_output_contains "Found 2 manifest file(s)"
}

@test "handles nested user config tokens" {
  set_required_env
  create_manifest "deployment.yaml"
  mkdir -p "$CONFIG_DIR/Category"
  printf '%s' "nested-value" > "$CONFIG_DIR/Category/SubVar"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/config/Category/SubVar" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/Category/SubVar")" = "nested-value" ]
}

@test "succeeds with no user config directory" {
  set_required_env
  export CONFIG_SUB_PATH="/nonexistent/config"
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]
}

@test "succeeds with empty user config directory" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]
}

@test "lists all conflicting tokens" {
  set_required_env
  create_manifest "deployment.yaml"
  create_config_token "ProjectName" "override1"
  create_config_token "Version" "override2"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "ProjectName"
  assert_output_contains "Version"
}

@test "succeeds with pre-populated combined directory and no source" {
  set_required_env
  export MANIFESTS_SUB_PATH="/nonexistent/path"

  # Simulate hooks pre-populating combined/
  mkdir -p "$OUTPUT_SUB_PATH/manifests/combined"
  echo 'apiVersion: v1' > "$OUTPUT_SUB_PATH/manifests/combined/from-hook.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]
  assert_output_contains "Source directory not found"
  assert_output_contains "Found 1 manifest file(s)"
}

@test "source files override pre-populated combined files" {
  set_required_env

  # Simulate hooks pre-populating combined/
  mkdir -p "$OUTPUT_SUB_PATH/manifests/combined"
  echo 'name: from-hook' > "$OUTPUT_SUB_PATH/manifests/combined/deployment.yaml"

  # Source has same file with different content
  create_manifest "deployment.yaml" 'name: from-source'

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]

  # Source should override hook content
  grep -q "name: from-source" "$OUTPUT_SUB_PATH/manifests/combined/deployment.yaml"
}

@test "outputs MANIFESTS_ZIP_FILE_NAME" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-prepare"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_FILE_NAME" "my-project-1.2.3-manifests.zip"
}
