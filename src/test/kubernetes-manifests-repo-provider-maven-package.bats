#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-maven-package
# This script prepares manifests zip for Maven deployment.

load helpers

setup() {
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip file
  export TEST_ZIP=$(mktemp)
  echo "test content" > "$TEST_ZIP"
  export TEST_ZIP_NAME="my-project-1.0.0-manifests.zip"
  # Create output directory
  export OUTPUT_PATH=$(mktemp -d)
}

teardown() {
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_ZIP"
  rm -rf "$OUTPUT_PATH"
}

# Required env vars for most tests
set_required_env() {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="$TEST_ZIP_NAME"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export MAVEN_GROUP_ID="io.github.testowner"
}

@test "creates Maven URI with correct coordinates" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "mvn:io.github.testowner:my-project-manifests:1.0.0:zip"
}

@test "creates publish directory with artifact" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_PATH/publish/maven" ]
  [ -f "$OUTPUT_PATH/publish/maven/$TEST_ZIP_NAME" ]
}

@test "outputs MAVEN_ARTIFACT_ID" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MAVEN_ARTIFACT_ID" "my-project-manifests"
}

@test "outputs MAVEN_GROUP_ID pass-through" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MAVEN_GROUP_ID" "io.github.testowner"
}

@test "outputs MANIFESTS_ARTIFACT_PATH" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "MANIFESTS_ARTIFACT_PATH="
}

@test "fails when MANIFESTS_ZIP_PATH missing" {
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export MAVEN_GROUP_ID="io.github.testowner"
  unset MANIFESTS_ZIP_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_PATH"
}

@test "fails when MANIFESTS_ZIP_NAME missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export MAVEN_GROUP_ID="io.github.testowner"
  unset MANIFESTS_ZIP_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_NAME"
}

@test "fails when PROJECT_NAME missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export VERSION="1.0.0"
  export MAVEN_GROUP_ID="io.github.testowner"
  unset PROJECT_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when VERSION missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export MAVEN_GROUP_ID="io.github.testowner"
  unset VERSION

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "fails when MAVEN_GROUP_ID missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  unset MAVEN_GROUP_ID

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MAVEN_GROUP_ID"
}

@test "fails when zip file not found" {
  set_required_env
  export MANIFESTS_ZIP_PATH="/nonexistent/file.zip"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}

@test "uses OUTPUT_PATH for publish directory" {
  set_required_env
  export OUTPUT_PATH="$OUTPUT_PATH/custom"
  mkdir -p "$OUTPUT_PATH"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-package"
  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_PATH/publish/maven" ]
}
