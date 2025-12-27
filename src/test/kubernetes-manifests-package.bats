#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test manifests directory
  export TEST_MANIFESTS=$(mktemp -d)
  export OUTPUT_PATH=$(mktemp -d)
}

teardown() {
  rm -f "$GITHUB_OUTPUT"
  rm -rf "$TEST_MANIFESTS"
  rm -rf "$OUTPUT_PATH"
}

# Create sample manifest file
create_manifest() {
  local filename="$1"
  local content="${2:-apiVersion: v1}"
  mkdir -p "$(dirname "$TEST_MANIFESTS/$filename")"
  echo "$content" > "$TEST_MANIFESTS/$filename"
}

# Required env vars for most tests
set_required_env() {
  export PROJECT_NAME="my-project"
  export VERSION="1.2.3"
  export MANIFESTS_PATH="$TEST_MANIFESTS"
}

@test "creates zip from directory" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_NAME" "my-project-1.2.3-manifests.zip"
  # Verify zip was created in output structure
  [ -f "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" ]
}

@test "creates target directory structure" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  # Verify directory structure
  [ -d "$OUTPUT_PATH/manifests/raw" ]
  [ -d "$OUTPUT_PATH/manifests/substituted" ]
  [ -d "$OUTPUT_PATH/manifests/zip" ]
}

@test "preserves raw files before substitution" {
  set_required_env
  create_manifest "deployment.yaml" 'name: ${PROJECT_NAME}-app'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  # Raw should still have variable
  grep -q '\${PROJECT_NAME}' "$OUTPUT_PATH/manifests/raw/deployment.yaml"
  # Substituted should have value
  grep -q 'my-project' "$OUTPUT_PATH/manifests/substituted/deployment.yaml"
}

@test "substitutes PROJECT_NAME in file contents" {
  set_required_env
  create_manifest "deployment.yaml" 'name: ${PROJECT_NAME}-app'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  # Extract and verify substitution
  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project-app"
}

@test "substitutes project-name variant with kebab-case style" {
  set_required_env
  export SUBSTITUTION_OUTPUT_STYLE="kebab-case"
  create_manifest "deployment.yaml" 'name: ${project-name}-app'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  # Extract and verify substitution (kebab-case)
  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project-app"
}

@test "substitutes VERSION in file contents" {
  set_required_env
  create_manifest "deployment.yaml" 'version: ${VERSION}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  # Extract and verify substitution
  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "version: 1.2.3"
}

@test "substitutes version variant with lower_snake style" {
  set_required_env
  export SUBSTITUTION_OUTPUT_STYLE="lower_snake"
  create_manifest "deployment.yaml" 'version: ${version}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  # Extract and verify substitution
  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "version: 1.2.3"
}

@test "substitutes DOCKER_TAG when provided" {
  set_required_env
  export DOCKER_TAG="1.2.3-PRERELEASE"
  create_manifest "deployment.yaml" 'image: myrepo:${DOCKER_TAG}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "image: myrepo:1.2.3-PRERELEASE"
}

@test "substitutes DOCKER_IMAGE_NAME when provided" {
  set_required_env
  export DOCKER_IMAGE_NAME="org/my-image"
  create_manifest "deployment.yaml" 'image: ${DOCKER_IMAGE_NAME}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "image: org/my-image"
}

@test "preserves directory structure" {
  set_required_env
  create_manifest "base/deployment.yaml"
  create_manifest "overlays/prod/patch.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  # Verify structure is preserved (with project wrapper)
  unzip -l "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/base/deployment.yaml"
  unzip -l "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/overlays/prod/patch.yaml"
}

@test "wraps contents in project-name directory" {
  set_required_env
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  # Verify wrapper directory
  unzip -l "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/"
  unzip -l "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" | grep -q "my-project/deployment.yaml"
}

@test "fails when manifests directory not found" {
  set_required_env
  export MANIFESTS_PATH="/nonexistent/path"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests directory not found"
}

@test "fails when manifests directory is empty" {
  set_required_env
  # TEST_MANIFESTS exists but is empty

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "directory is empty"
}

@test "fails when PROJECT_NAME missing" {
  export VERSION="1.0.0"
  export MANIFESTS_PATH="$TEST_MANIFESTS"
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when VERSION missing" {
  export PROJECT_NAME="my-project"
  export MANIFESTS_PATH="$TEST_MANIFESTS"
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "defaults MANIFESTS_PATH to src/kubernetes" {
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  unset MANIFESTS_PATH
  # Don't create test manifests - should use default path

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  # Will fail because src/kubernetes doesn't exist, but that's fine
  [ "$status" -ne 0 ]
  assert_output_contains "src/kubernetes"
}

@test "defaults OUTPUT_PATH to target" {
  set_required_env
  unset OUTPUT_PATH
  create_manifest "deployment.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Output: target"
  # Clean up
  rm -rf target/
}

@test "reports yaml file count" {
  set_required_env
  create_manifest "deployment.yaml"
  create_manifest "service.yaml"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Found 2 manifest file(s)"
}

@test "reports substitution stats" {
  set_required_env
  create_manifest "deployment.yaml" 'name: ${PROJECT_NAME}
version: ${VERSION}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Substitutions:"
  assert_output_contains "deployment.yaml:"
}

@test "substitutes with camelCase style" {
  set_required_env
  export SUBSTITUTION_OUTPUT_STYLE="camelCase"
  create_manifest "deployment.yaml" 'name: ${projectName}
version: ${dockerTag}'
  export DOCKER_TAG="1.2.3-dev"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "version: 1.2.3-dev"
}

@test "substitutes with PascalCase style" {
  set_required_env
  export SUBSTITUTION_OUTPUT_STYLE="PascalCase"
  create_manifest "deployment.yaml" 'name: ${ProjectName}
image: ${DockerImageName}'
  export DOCKER_IMAGE_NAME="org/image"

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]

  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "image: org/image"
}

@test "defaults SUBSTITUTION_OUTPUT_STYLE to UPPER_SNAKE" {
  set_required_env
  unset SUBSTITUTION_OUTPUT_STYLE
  create_manifest "deployment.yaml" 'name: ${PROJECT_NAME}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Output style: UPPER_SNAKE"

  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
}

@test "fails with unknown substitution output style" {
  set_required_env
  export SUBSTITUTION_OUTPUT_STYLE="UNKNOWN_STYLE"
  create_manifest "deployment.yaml" 'name: ${PROJECT_NAME}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown substitution output style"
}

@test "defaults SUBSTITUTION_TOKEN_STYLE to shell" {
  set_required_env
  unset SUBSTITUTION_TOKEN_STYLE
  create_manifest "deployment.yaml" 'name: ${PROJECT_NAME}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Token style: shell"
}

@test "uses shell token style explicitly" {
  set_required_env
  export SUBSTITUTION_TOKEN_STYLE="shell"
  create_manifest "deployment.yaml" 'name: ${PROJECT_NAME}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Token style: shell"

  unzip -p "$OUTPUT_PATH/manifests/zip/my-project-1.2.3-manifests.zip" my-project/deployment.yaml | grep -q "name: my-project"
}

@test "fails with unknown substitution token style" {
  set_required_env
  export SUBSTITUTION_TOKEN_STYLE="mustache"
  create_manifest "deployment.yaml" 'name: {{PROJECT_NAME}}'

  run "$SCRIPTS_DIR/kubernetes-manifests-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown substitution token style"
}
