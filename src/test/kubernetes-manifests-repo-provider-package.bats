#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for the kubernetes-manifests-repo-provider-package selector script

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(mktemp)
  export TEST_ZIP=$(mktemp)
  echo "test content" > "$TEST_ZIP"
  export OUTPUT_PATH=$(mktemp -d)
}

teardown() {
  cleanup_mock_docker
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_ZIP"
  rm -rf "$OUTPUT_PATH"
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
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0-manifests"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-package"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: docker"
  assert_output_contains "Kubernetes Manifests Repo Provider Package: Docker"
}

@test "dispatches to github-release repo provider" {
  export MANIFESTS_REPO_PROVIDER_TYPE="github-release"
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test-1.0.0-manifests.zip"
  export VERSION="1.0.0"

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
