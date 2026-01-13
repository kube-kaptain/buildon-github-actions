#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for the kubernetes-manifests-repo-provider-publish selector script

load helpers

setup() {
  setup_mock_docker
  local base_dir=$(create_test_dir "k8s-repo-pub")
  export GITHUB_OUTPUT="$base_dir/output"
  export TEST_ZIP_DIR="$base_dir/zip"
  mkdir -p "$TEST_ZIP_DIR"
  export TEST_ZIP_NAME="test-manifests.zip"
  echo "test content" > "$TEST_ZIP_DIR/$TEST_ZIP_NAME"
}

teardown() {
  :
}

@test "defaults to docker when MANIFESTS_REPO_PROVIDER_TYPE not set" {
  unset MANIFESTS_REPO_PROVIDER_TYPE
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: docker"
  assert_output_contains "Kubernetes Manifests Repo Provider Publish: Docker"
}

@test "fails when MANIFESTS_REPO_PROVIDER_TYPE is unknown" {
  export MANIFESTS_REPO_PROVIDER_TYPE="nonexistent"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown repo provider type: nonexistent"
  assert_output_contains "Available:"
}

@test "dispatches to docker repo provider when explicit" {
  export MANIFESTS_REPO_PROVIDER_TYPE="docker"
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: docker"
  assert_output_contains "Kubernetes Manifests Repo Provider Publish: Docker"
}

@test "lists available repo providers on error" {
  export MANIFESTS_REPO_PROVIDER_TYPE="nonexistent"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -ne 0 ]
  # Should list the available repo providers
  assert_output_contains "docker"
}
