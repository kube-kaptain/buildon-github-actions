#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export GITHUB_OUTPUT=$(mktemp)
  # Create test directories as relative sub-paths (script expects relative paths)
  export TEST_WORK_DIR="test-workdir-$$"
  mkdir -p "$TEST_WORK_DIR"
  export TEST_MANIFESTS="$TEST_WORK_DIR/manifests"
  export OUTPUT_SUB_PATH="$TEST_WORK_DIR/target"
  export CONFIG_DIR="$TEST_WORK_DIR/config"
  mkdir -p "$TEST_MANIFESTS" "$OUTPUT_SUB_PATH" "$CONFIG_DIR"
}

teardown() {
  rm -f "$GITHUB_OUTPUT"
  rm -rf "$TEST_WORK_DIR"
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

@test "creates zip from directory" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_FILE_NAME" "my-project-1.2.3-manifests.zip"
  [ -f "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" ]
}

@test "creates target directory structure" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_SUB_PATH/manifests/raw" ]
  [ -d "$OUTPUT_SUB_PATH/manifests/config" ]
  [ -d "$OUTPUT_SUB_PATH/manifests/substituted" ]
  [ -d "$OUTPUT_SUB_PATH/manifests/zip" ]
}

@test "writes built-in tokens as files" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  # Default style is PascalCase
  [ -f "$OUTPUT_SUB_PATH/manifests/config/ProjectName" ]
  [ -f "$OUTPUT_SUB_PATH/manifests/config/Version" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/ProjectName")" = "my-project" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/Version")" = "1.2.3" ]
}

@test "substitutes ProjectName with PascalCase style (default)" {
  set_required_env
  create_manifest "deployment.yaml" 'name: ${ProjectName}-app'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project-app"
}

@test "substitutes with kebab-case style" {
  set_required_env
  export TOKEN_NAME_STYLE="kebab-case"
  create_manifest "deployment.yaml" 'name: ${project-name}-app'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project-app"
}

@test "substitutes with UPPER_SNAKE style" {
  set_required_env
  export TOKEN_NAME_STYLE="UPPER_SNAKE"
  create_manifest "deployment.yaml" 'name: ${PROJECT_NAME}-app'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project-app"
}

@test "substitutes VERSION" {
  set_required_env
  create_manifest "deployment.yaml" 'version: ${Version}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "version: 1.2.3"
}

@test "substitutes DOCKER_TAG when provided" {
  set_required_env
  export DOCKER_TAG="1.2.3-PRERELEASE"
  create_manifest "deployment.yaml" 'image: myrepo:${DockerTag}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "image: myrepo:1.2.3-PRERELEASE"
}

@test "substitutes DOCKER_IMAGE_NAME when provided" {
  set_required_env
  export DOCKER_IMAGE_NAME="org/my-image"
  create_manifest "deployment.yaml" 'image: ${DockerImageName}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "image: org/my-image"
}

@test "copies user config tokens" {
  set_required_env
  create_manifest "deployment.yaml" 'custom: ${CustomVar}'
  create_config_token "CustomVar" "custom-value"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "custom: custom-value"
}

@test "validates user config names match token-name-style" {
  set_required_env
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_NAME_VALIDATION="MATCH"
  create_manifest "deployment.yaml" 'key: value'
  create_config_token "invalid_name" "value"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid"
}

@test "allows any name style when validation is ALL" {
  set_required_env
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_NAME_VALIDATION="ALL"
  create_manifest "deployment.yaml" 'custom: ${my_custom_var}'
  create_config_token "my_custom_var" "value"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "custom: value"
}

@test "blocks builtin override by default" {
  set_required_env
  create_manifest "deployment.yaml" 'name: ${ProjectName}'
  create_config_token "ProjectName" "overridden"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "override"
  assert_output_contains "ProjectName"
}

@test "allows builtin override when enabled" {
  set_required_env
  export ALLOW_BUILTIN_TOKEN_OVERRIDE="true"
  create_manifest "deployment.yaml" 'name: ${ProjectName}'
  create_config_token "ProjectName" "overridden-value"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: overridden-value"
}

@test "preserves directory structure" {
  set_required_env
  create_manifest "base/deployment.yaml"
  create_manifest "overlays/prod/patch.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -l "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/base/deployment.yaml"
  unzip -l "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/overlays/prod/patch.yaml"
}

@test "wraps contents in project-name directory" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -l "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/"
  unzip -l "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/deployment.yaml"
}

@test "fails when manifests directory not found" {
  set_required_env
  export MANIFESTS_SUB_PATH="/nonexistent/path"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests directory not found"
}

@test "fails when manifests directory is empty" {
  set_required_env

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "directory is empty"
}

@test "fails when PROJECT_NAME missing" {
  export VERSION="1.0.0"
  export MANIFESTS_SUB_PATH="$TEST_MANIFESTS"
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when VERSION missing" {
  export PROJECT_NAME="my-project"
  export MANIFESTS_SUB_PATH="$TEST_MANIFESTS"
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "defaults MANIFESTS_SUB_PATH to src/kubernetes" {
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  unset MANIFESTS_SUB_PATH

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "src/kubernetes"
}

@test "defaults OUTPUT_SUB_PATH to target" {
  set_required_env
  unset OUTPUT_SUB_PATH
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Output: target"
  rm -rf target/
}

@test "defaults TOKEN_NAME_STYLE to PascalCase" {
  set_required_env
  unset TOKEN_NAME_STYLE
  create_manifest "deployment.yaml" 'name: ${ProjectName}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Name style: PascalCase"

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
}

@test "reports yaml file count" {
  set_required_env
  create_manifest "deployment.yaml"
  create_manifest "service.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Found 2 manifest file(s)"
}

@test "substitutes with lower.dot style" {
  set_required_env
  export TOKEN_NAME_STYLE="lower.dot"
  create_manifest "deployment.yaml" 'name: ${project.name}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
}

@test "substitutes with UPPER.DOT style" {
  set_required_env
  export TOKEN_NAME_STYLE="UPPER.DOT"
  create_manifest "deployment.yaml" 'name: ${PROJECT.NAME}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
}

@test "fails with unknown token name style" {
  set_required_env
  export TOKEN_NAME_STYLE="UNKNOWN_STYLE"
  create_manifest "deployment.yaml" 'name: ${ProjectName}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown token name style"
}

@test "defaults SUBSTITUTION_TOKEN_STYLE to shell" {
  set_required_env
  unset SUBSTITUTION_TOKEN_STYLE
  create_manifest "deployment.yaml" 'name: ${ProjectName}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Token style: shell"
}

@test "uses mustache token style" {
  set_required_env
  export SUBSTITUTION_TOKEN_STYLE="mustache"
  create_manifest "deployment.yaml" 'name: {{ ProjectName }}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
}

@test "fails with unknown substitution token style" {
  set_required_env
  export SUBSTITUTION_TOKEN_STYLE="unknown"
  create_manifest "deployment.yaml" 'name: {{ProjectName}}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown token style"
}

@test "handles nested user config tokens" {
  set_required_env
  create_manifest "deployment.yaml" 'value: ${Category/SubVar}'
  mkdir -p "$CONFIG_DIR/Category"
  printf '%s' "nested-value" > "$CONFIG_DIR/Category/SubVar"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "value: nested-value"
}

@test "succeeds with no user config directory" {
  set_required_env
  export CONFIG_SUB_PATH="/nonexistent/config"
  create_manifest "deployment.yaml" 'name: ${ProjectName}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
}

@test "succeeds with empty user config directory" {
  set_required_env
  create_manifest "deployment.yaml" 'name: ${ProjectName}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_SUB_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
}

@test "lists all conflicting tokens" {
  set_required_env
  create_manifest "deployment.yaml" 'key: value'
  create_config_token "ProjectName" "override1"
  create_config_token "Version" "override2"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "ProjectName"
  assert_output_contains "Version"
}
