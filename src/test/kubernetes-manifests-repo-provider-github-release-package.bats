#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-github-release-package
# This script validates the zip exists and passes through values for publish.

load helpers

setup() {
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip in a directory
  export TEST_ZIP_DIR=$(mktemp -d)
  export TEST_ZIP_NAME="my-project-1.0.0-manifests.zip"
  echo "test content" > "$TEST_ZIP_DIR/$TEST_ZIP_NAME"
}

teardown() {
  rm -f "$GITHUB_OUTPUT"
  rm -rf "$TEST_ZIP_DIR"
}

# Required env vars for most tests (using REPO_PROVIDER_* API)
set_required_env() {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_VERSION="1.0.0"
}

@test "passes through MANIFESTS_ZIP_SUB_PATH" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_SUB_PATH" "$TEST_ZIP_DIR"
}

@test "passes through MANIFESTS_ZIP_FILE_NAME" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_ZIP_FILE_NAME" "$TEST_ZIP_NAME"
}

@test "passes through VERSION from REPO_PROVIDER_VERSION" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.0"
}

@test "fails when MANIFESTS_ZIP_SUB_PATH missing" {
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_VERSION="1.0.0"
  unset MANIFESTS_ZIP_SUB_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_SUB_PATH"
}

@test "fails when MANIFESTS_ZIP_FILE_NAME missing" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export REPO_PROVIDER_VERSION="1.0.0"
  unset MANIFESTS_ZIP_FILE_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_FILE_NAME"
}

@test "fails when REPO_PROVIDER_VERSION missing" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  unset REPO_PROVIDER_VERSION

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -ne 0 ]
  assert_output_contains "REPO_PROVIDER_VERSION"
}

@test "fails when zip file not found" {
  set_required_env
  export MANIFESTS_ZIP_SUB_PATH="/nonexistent"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}
