#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-github-release-package
# This script validates the zip exists and passes through values for publish.

load helpers

setup() {
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip file
  export TEST_ZIP=$(mktemp)
  echo "test content" > "$TEST_ZIP"
}

teardown() {
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_ZIP"
}

# Required env vars for most tests
set_required_env() {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="my-project-1.0.0-manifests.zip"
  export VERSION="1.0.0"
}

@test "passes through MANIFESTS_ZIP_PATH" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_PATH" "$TEST_ZIP"
}

@test "passes through MANIFESTS_ZIP_NAME" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_NAME" "my-project-1.0.0-manifests.zip"
}

@test "passes through VERSION" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.0"
}

@test "fails when MANIFESTS_ZIP_PATH missing" {
  export MANIFESTS_ZIP_NAME="my-project-1.0.0-manifests.zip"
  export VERSION="1.0.0"
  unset MANIFESTS_ZIP_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_PATH"
}

@test "fails when MANIFESTS_ZIP_NAME missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export VERSION="1.0.0"
  unset MANIFESTS_ZIP_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_NAME"
}

@test "fails when VERSION missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="my-project-1.0.0-manifests.zip"
  unset VERSION

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "fails when zip file not found" {
  set_required_env
  export MANIFESTS_ZIP_PATH="/nonexistent/file.zip"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}
