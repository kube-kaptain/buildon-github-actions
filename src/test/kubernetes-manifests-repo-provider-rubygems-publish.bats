#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-rubygems-publish
# This script publishes a .gem to GitHub Packages.

load helpers

setup() {
  setup_mock_gem
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test gem file
  local temp_base
  temp_base=$(mktemp)
  export TEST_GEM="${temp_base}.gem"
  rm -f "$temp_base"
  echo "test content" > "$TEST_GEM"
}

teardown() {
  cleanup_mock_gem
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_GEM"
}

# Required env vars for most tests
set_required_env() {
  export MANIFESTS_ARTIFACT_PATH="$TEST_GEM"
  export MANIFESTS_URI="gem:test-owner/my-project-manifests:1.0.0"
  export REGISTRY_OWNER="test-owner"
  export REGISTRY_URL="https://rubygems.pkg.github.com/test-owner"
  export AUTH_TOKEN="test-token"
  export IS_RELEASE="true"
}

@test "publishes when IS_RELEASE=true" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -eq 0 ]
  assert_gem_called "push"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "skips publish when IS_RELEASE=false" {
  set_required_env
  export IS_RELEASE="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -eq 0 ]
  assert_gem_not_called "push"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "defaults IS_RELEASE to false" {
  set_required_env
  unset IS_RELEASE

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -eq 0 ]
  assert_gem_not_called "push"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "outputs MANIFESTS_URI" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "gem:test-owner/my-project-manifests:1.0.0"
}

@test "passes gem path and host to gem push" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -eq 0 ]
  assert_gem_called "$TEST_GEM"
  assert_gem_called "--host"
  assert_gem_called "rubygems.pkg.github.com"
}

@test "fails when MANIFESTS_ARTIFACT_PATH missing" {
  export MANIFESTS_URI="gem:test-owner/my-project-manifests:1.0.0"
  export REGISTRY_OWNER="test-owner"
  unset MANIFESTS_ARTIFACT_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ARTIFACT_PATH"
}

@test "fails when MANIFESTS_URI missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_GEM"
  export REGISTRY_OWNER="test-owner"
  unset MANIFESTS_URI

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_URI"
}

@test "fails when REGISTRY_OWNER missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_GEM"
  export MANIFESTS_URI="gem:test-owner/my-project-manifests:1.0.0"
  unset REGISTRY_OWNER

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "REGISTRY_OWNER"
}

@test "fails when gem file not found" {
  set_required_env
  export MANIFESTS_ARTIFACT_PATH="/nonexistent/package.gem"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "gem file not found"
}

@test "publishes without AUTH_TOKEN using pre-configured auth" {
  set_required_env
  unset AUTH_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -eq 0 ]
  assert_gem_called "push"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "does not require AUTH_TOKEN when not release" {
  set_required_env
  export IS_RELEASE="false"
  unset AUTH_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-rubygems-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

# Skip: "fails when gem not available" - environment-specific, hard to mock
# The command -v check is in place and verified via code review
