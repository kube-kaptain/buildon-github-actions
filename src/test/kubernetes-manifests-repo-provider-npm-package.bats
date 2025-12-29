#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-npm-package
# This script creates an npm tarball containing the manifests zip.

load helpers

setup() {
  setup_mock_npm
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip file
  export TEST_ZIP=$(mktemp)
  echo "test content" > "$TEST_ZIP"
  export TEST_ZIP_NAME="my-project-1.0.0-manifests.zip"
  # Create output directory
  export OUTPUT_PATH=$(mktemp -d)
}

teardown() {
  cleanup_mock_npm
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
  export REGISTRY_OWNER="test-owner"
  export REGISTRY_URL="https://npm.pkg.github.com"
}

@test "creates npm tarball with correct package name" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "npm:@test-owner/my-project-manifests@1.0.0"
}

@test "creates publish directory with package.json" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_PATH/publish/npm" ]
  [ -f "$OUTPUT_PATH/publish/npm/package.json" ]
}

@test "copies manifest zip to publish directory" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_PATH/publish/npm/$TEST_ZIP_NAME" ]
}

@test "generates package.json with correct content" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -eq 0 ]

  # Check package.json content
  local pkg_json="$OUTPUT_PATH/publish/npm/package.json"
  grep -q '"name": "@test-owner/my-project-manifests"' "$pkg_json"
  grep -q '"version": "1.0.0"' "$pkg_json"
  grep -q '"registry": "https://npm.pkg.github.com"' "$pkg_json"
}

@test "lowercases owner for npm scope" {
  set_required_env
  export REGISTRY_OWNER="Test-Owner"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "npm:@test-owner/my-project-manifests@1.0.0"
}

@test "calls npm pack" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -eq 0 ]
  assert_npm_called "pack"
}

@test "outputs MANIFESTS_ARTIFACT_PATH" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -eq 0 ]
  # Check that artifact path is set (exact path depends on mock)
  echo "$output" | grep -q "MANIFESTS_ARTIFACT_PATH="
}

@test "fails when MANIFESTS_ZIP_PATH missing" {
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export REGISTRY_OWNER="test-owner"
  unset MANIFESTS_ZIP_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_PATH"
}

@test "fails when MANIFESTS_ZIP_NAME missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export REGISTRY_OWNER="test-owner"
  unset MANIFESTS_ZIP_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_NAME"
}

@test "fails when PROJECT_NAME missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export VERSION="1.0.0"
  export REGISTRY_OWNER="test-owner"
  unset PROJECT_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when VERSION missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export REGISTRY_OWNER="test-owner"
  unset VERSION

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "fails when REGISTRY_OWNER missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  unset REGISTRY_OWNER

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -ne 0 ]
  assert_output_contains "REGISTRY_OWNER"
}

@test "fails when zip file not found" {
  set_required_env
  export MANIFESTS_ZIP_PATH="/nonexistent/file.zip"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}

@test "fails when npm not available" {
  set_required_env
  cleanup_mock_npm
  # Remove npm from path
  export PATH="/usr/bin:/bin"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -ne 0 ]
  assert_output_contains "npm is required"
}

@test "uses OUTPUT_PATH for publish directory" {
  set_required_env
  export OUTPUT_PATH="$OUTPUT_PATH/custom"
  mkdir -p "$OUTPUT_PATH"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-package"
  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_PATH/publish/npm" ]
}
