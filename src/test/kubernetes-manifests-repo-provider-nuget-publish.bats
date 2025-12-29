#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-nuget-publish
# This script publishes a .nupkg to GitHub Packages.

load helpers

setup() {
  setup_mock_nuget
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test nupkg file
  local temp_base
  temp_base=$(mktemp)
  export TEST_NUPKG="${temp_base}.nupkg"
  rm -f "$temp_base"
  echo "test content" > "$TEST_NUPKG"
}

teardown() {
  cleanup_mock_nuget
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_NUPKG"
}

# Required env vars for most tests
set_required_env() {
  export MANIFESTS_ARTIFACT_PATH="$TEST_NUPKG"
  export MANIFESTS_URI="nuget:TestOwner.MyProject.Manifests:1.0.0"
  export REGISTRY_OWNER="test-owner"
  export REGISTRY_URL="https://nuget.pkg.github.com/test-owner/index.json"
  export AUTH_TOKEN="test-token"
  export IS_RELEASE="true"
}

@test "publishes when IS_RELEASE=true" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -eq 0 ]
  assert_nuget_called "nuget push"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "skips publish when IS_RELEASE=false" {
  set_required_env
  export IS_RELEASE="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -eq 0 ]
  assert_nuget_not_called "push"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "defaults IS_RELEASE to false" {
  set_required_env
  unset IS_RELEASE

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -eq 0 ]
  assert_nuget_not_called "push"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "outputs MANIFESTS_URI" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "nuget:TestOwner.MyProject.Manifests:1.0.0"
}

@test "passes package path and source to dotnet nuget push" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -eq 0 ]
  assert_nuget_called "$TEST_NUPKG"
  assert_nuget_called "--source"
  assert_nuget_called "nuget.pkg.github.com"
}

@test "uses GitHub Packages registry URL" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -eq 0 ]
  assert_nuget_called "nuget.pkg.github.com/test-owner"
}

@test "fails when MANIFESTS_ARTIFACT_PATH missing" {
  export MANIFESTS_URI="nuget:TestOwner.MyProject.Manifests:1.0.0"
  export REGISTRY_OWNER="test-owner"
  unset MANIFESTS_ARTIFACT_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ARTIFACT_PATH"
}

@test "fails when MANIFESTS_URI missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_NUPKG"
  export REGISTRY_OWNER="test-owner"
  unset MANIFESTS_URI

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_URI"
}

@test "fails when REGISTRY_OWNER missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_NUPKG"
  export MANIFESTS_URI="nuget:TestOwner.MyProject.Manifests:1.0.0"
  unset REGISTRY_OWNER

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "REGISTRY_OWNER"
}

@test "fails when package not found" {
  set_required_env
  export MANIFESTS_ARTIFACT_PATH="/nonexistent/package.nupkg"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "NuGet package not found"
}

@test "publishes without AUTH_TOKEN using pre-configured auth" {
  set_required_env
  unset AUTH_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -eq 0 ]
  assert_nuget_called "nuget push"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "does not require AUTH_TOKEN when not release" {
  set_required_env
  export IS_RELEASE="false"
  unset AUTH_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-nuget-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

# Skip: "fails when dotnet not available" - environment-specific, hard to mock
# The command -v check is in place and verified via code review
