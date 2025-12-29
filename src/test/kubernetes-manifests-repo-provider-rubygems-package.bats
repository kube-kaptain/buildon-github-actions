#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-rubygems-package
# This script creates a .gem file containing the manifests zip.

load helpers

setup() {
  setup_mock_gem
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip file
  export TEST_ZIP=$(mktemp)
  echo "test content" > "$TEST_ZIP"
  export TEST_ZIP_NAME="my-project-1.0.0-manifests.zip"
  # Create output directory
  export OUTPUT_PATH=$(mktemp -d)
}

teardown() {
  cleanup_mock_gem
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
  # Note: rubygems-package doesn't need REGISTRY_URL, only publish does
}

@test "creates gem with correct URI" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "gem:test-owner/my-project-manifests:1.0.0"
}

@test "creates publish directory with gemspec" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_PATH/publish/rubygems" ]
  [ -f "$OUTPUT_PATH/publish/rubygems/my-project-manifests.gemspec" ]
}

@test "copies manifest zip to publish directory" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_PATH/publish/rubygems/$TEST_ZIP_NAME" ]
}

@test "generates gemspec with correct content" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -eq 0 ]

  # Check gemspec content
  local gemspec="$OUTPUT_PATH/publish/rubygems/my-project-manifests.gemspec"
  grep -q "s.name.*=.*'my-project-manifests'" "$gemspec"
  grep -q "s.version.*=.*'1.0.0'" "$gemspec"
  grep -q "s.files.*=.*\['$TEST_ZIP_NAME'\]" "$gemspec"
}

@test "calls gem build" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -eq 0 ]
  assert_gem_called "build"
}

@test "outputs MANIFESTS_ARTIFACT_PATH" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "MANIFESTS_ARTIFACT_PATH="
}

@test "fails when MANIFESTS_ZIP_PATH missing" {
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export REGISTRY_OWNER="test-owner"
  unset MANIFESTS_ZIP_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_PATH"
}

@test "fails when MANIFESTS_ZIP_NAME missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export REGISTRY_OWNER="test-owner"
  unset MANIFESTS_ZIP_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_NAME"
}

@test "fails when PROJECT_NAME missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export VERSION="1.0.0"
  export REGISTRY_OWNER="test-owner"
  unset PROJECT_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when VERSION missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export REGISTRY_OWNER="test-owner"
  unset VERSION

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "fails when REGISTRY_OWNER missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test.zip"
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  unset REGISTRY_OWNER

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -ne 0 ]
  assert_output_contains "REGISTRY_OWNER"
}

@test "fails when zip file not found" {
  set_required_env
  export MANIFESTS_ZIP_PATH="/nonexistent/file.zip"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}

# Skip: "fails when gem not available" - environment-specific, hard to mock
# The command -v check is in place and verified via code review

@test "uses OUTPUT_PATH for publish directory" {
  set_required_env
  export OUTPUT_PATH="$OUTPUT_PATH/custom"
  mkdir -p "$OUTPUT_PATH"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-package"
  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_PATH/publish/rubygems" ]
}
