#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for the kubernetes-manifest-transport selector script

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

@test "fails when TRANSPORT_TYPE not set" {
  unset TRANSPORT_TYPE

  run "$SCRIPTS_DIR/kubernetes-manifest-transport"
  [ "$status" -ne 0 ]
  assert_output_contains "TRANSPORT_TYPE is required"
  assert_output_contains "Available:"
}

@test "fails when TRANSPORT_TYPE is unknown" {
  export TRANSPORT_TYPE="nonexistent"

  run "$SCRIPTS_DIR/kubernetes-manifest-transport"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown transport type: nonexistent"
  assert_output_contains "Available:"
}

@test "dispatches to docker transport" {
  export TRANSPORT_TYPE="docker"
  export MANIFEST_ZIP_PATH="$TEST_ZIP"
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0-manifests"

  run "$SCRIPTS_DIR/kubernetes-manifest-transport"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: docker"
  assert_output_contains "Kubernetes Manifest Transport: Docker"
}

@test "dispatches to github-release transport" {
  export TRANSPORT_TYPE="github-release"
  export MANIFEST_ZIP_PATH="$TEST_ZIP"
  export MANIFEST_ZIP_NAME="test-1.0.0-manifests.zip"
  export VERSION="1.0.0"
  export IS_RELEASE="false"

  run "$SCRIPTS_DIR/kubernetes-manifest-transport"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: github-release"
  assert_output_contains "Kubernetes Manifest Transport: GitHub Release"
}

@test "lists available transports on error" {
  unset TRANSPORT_TYPE

  run "$SCRIPTS_DIR/kubernetes-manifest-transport"
  [ "$status" -ne 0 ]
  # Should list the available transports
  assert_output_contains "docker"
  assert_output_contains "github-release"
}
