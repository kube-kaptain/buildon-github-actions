#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for the kubernetes-manifests-repo-provider-package selector script

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(mktemp)
  export TEST_ZIP_DIR=$(mktemp -d)
  export TEST_ZIP_NAME="test-manifests.zip"
  echo "test content" > "$TEST_ZIP_DIR/$TEST_ZIP_NAME"
  export OUTPUT_SUB_PATH=$(mktemp -d)
}

teardown() {
  cleanup_mock_docker
  rm -f "$GITHUB_OUTPUT"
  rm -rf "$TEST_ZIP_DIR"
  rm -rf "$OUTPUT_SUB_PATH"
}

@test "fails when MANIFESTS_REPO_PROVIDER_TYPE not set" {
  unset MANIFESTS_REPO_PROVIDER_TYPE

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_REPO_PROVIDER_TYPE is required"
  assert_output_contains "Available:"
}

@test "fails when MANIFESTS_REPO_PROVIDER_TYPE is unknown" {
  export MANIFESTS_REPO_PROVIDER_TYPE="nonexistent"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown repo provider type: nonexistent"
  assert_output_contains "Available:"
}

@test "dispatches to docker repo provider" {
  export MANIFESTS_REPO_PROVIDER_TYPE="docker"
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_URL="ghcr.io"
  export REPO_PROVIDER_NAME="test/my-repo"
  export REPO_PROVIDER_VERSION="1.0.0-manifests"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: docker"
  assert_output_contains "Kubernetes Manifests Repo Provider Package: Docker"
}

@test "dispatches to github-release repo provider" {
  export MANIFESTS_REPO_PROVIDER_TYPE="github-release"
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_VERSION="1.0.0"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: github-release"
  assert_output_contains "Kubernetes Manifests Repo Provider Package: GitHub Release"
}

@test "lists available repo providers on error" {
  unset MANIFESTS_REPO_PROVIDER_TYPE

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-package"
  [ "$status" -ne 0 ]
  # Should list the available repo providers
  assert_output_contains "docker"
  assert_output_contains "github-release"
}
