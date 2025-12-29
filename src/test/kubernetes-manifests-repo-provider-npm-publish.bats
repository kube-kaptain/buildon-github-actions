#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-npm-publish
# This script publishes an npm tarball to GitHub Packages.

load helpers

setup() {
  setup_mock_npm
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test tarball (use .tgz extension for npm)
  local temp_base
  temp_base=$(mktemp)
  export TEST_TARBALL="${temp_base}.tgz"
  rm -f "$temp_base"  # Remove the original temp file
  echo "test content" > "$TEST_TARBALL"
}

teardown() {
  cleanup_mock_npm
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_TARBALL"
}

# Required env vars for most tests
set_required_env() {
  export MANIFESTS_ARTIFACT_PATH="$TEST_TARBALL"
  export MANIFESTS_URI="npm:@test-owner/my-project-manifests@1.0.0"
  export REGISTRY_OWNER="test-owner"
  export REGISTRY_URL="https://npm.pkg.github.com"
  export AUTH_TOKEN="test-token"
  export IS_RELEASE="true"
}

@test "publishes when IS_RELEASE=true" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -eq 0 ]
  assert_npm_called "publish"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "skips publish when IS_RELEASE=false" {
  set_required_env
  export IS_RELEASE="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -eq 0 ]
  assert_npm_not_called "publish"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "defaults IS_RELEASE to false" {
  set_required_env
  unset IS_RELEASE

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -eq 0 ]
  assert_npm_not_called "publish"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "outputs MANIFESTS_URI" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "npm:@test-owner/my-project-manifests@1.0.0"
}

@test "passes tarball path to npm publish" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -eq 0 ]
  assert_npm_called "$TEST_TARBALL"
}

@test "fails when MANIFESTS_ARTIFACT_PATH missing" {
  export MANIFESTS_URI="npm:@test-owner/my-project-manifests@1.0.0"
  export GITHUB_REPOSITORY_OWNER="test-owner"
  unset MANIFESTS_ARTIFACT_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ARTIFACT_PATH"
}

@test "fails when MANIFESTS_URI missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_TARBALL"
  export GITHUB_REPOSITORY_OWNER="test-owner"
  unset MANIFESTS_URI

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_URI"
}

@test "fails when REGISTRY_OWNER missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_TARBALL"
  export MANIFESTS_URI="npm:@test-owner/my-project-manifests@1.0.0"
  unset REGISTRY_OWNER

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "REGISTRY_OWNER"
}

@test "fails when tarball not found" {
  set_required_env
  export MANIFESTS_ARTIFACT_PATH="/nonexistent/package.tgz"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "npm tarball not found"
}

@test "publishes without AUTH_TOKEN using pre-configured auth" {
  set_required_env
  unset AUTH_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -eq 0 ]
  assert_npm_called "publish"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "does not require AUTH_TOKEN when not release" {
  set_required_env
  export IS_RELEASE="false"
  unset AUTH_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "fails when npm not available" {
  set_required_env
  cleanup_mock_npm
  export PATH="/usr/bin:/bin"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "npm is required"
}

@test "lowercases owner for npm registry config" {
  set_required_env
  export REGISTRY_OWNER="Test-Owner"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-npm-publish"
  [ "$status" -eq 0 ]
  # The publish should succeed (mock doesn't verify config content)
  assert_npm_called "publish"
}
