#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-docker-package
# This script builds a Docker image containing the manifests zip.

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip in a directory
  export TEST_ZIP_DIR=$(mktemp -d)
  export TEST_ZIP_NAME="test-manifests.zip"
  echo "test content" > "$TEST_ZIP_DIR/$TEST_ZIP_NAME"
  # Create output directory
  export OUTPUT_SUB_PATH=$(mktemp -d)
}

teardown() {
  cleanup_mock_docker
  rm -f "$GITHUB_OUTPUT"
  rm -rf "$TEST_ZIP_DIR"
  rm -rf "$OUTPUT_SUB_PATH"
}

# Required env vars for most tests (using REPO_PROVIDER_* API)
set_required_env() {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_URL="ghcr.io"
  export REPO_PROVIDER_NAME="test/my-repo"
  export REPO_PROVIDER_VERSION="1.0.0-manifests"
}

@test "assembles target URI without base path" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "ghcr.io/test/my-repo:1.0.0-manifests"
}

@test "assembles target URI with base path" {
  set_required_env
  export REPO_PROVIDER_NAMESPACE="kube-kaptain"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "ghcr.io/kube-kaptain/test/my-repo:1.0.0-manifests"
}

@test "calls docker build with correct args" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_docker_called "build -t ghcr.io/test/my-repo:1.0.0-manifests"
}

@test "creates publish directory instead of temp" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  # Verify publish directory was created
  [ -d "$OUTPUT_SUB_PATH/publish/docker" ]
  [ -f "$OUTPUT_SUB_PATH/publish/docker/Dockerfile" ]
  # Zip file should be copied with original name
  [ -f "$OUTPUT_SUB_PATH/publish/docker/$TEST_ZIP_NAME" ]
}

@test "does not push (package only)" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
}

@test "fails when MANIFESTS_ZIP_SUB_PATH missing" {
  export REPO_PROVIDER_URL="ghcr.io"
  export REPO_PROVIDER_NAME="test/my-repo"
  export REPO_PROVIDER_VERSION="1.0.0-manifests"
  unset MANIFESTS_ZIP_SUB_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_SUB_PATH"
}

@test "fails when zip file not found" {
  set_required_env
  export MANIFESTS_ZIP_SUB_PATH="/nonexistent"
  export MANIFESTS_ZIP_FILE_NAME="file.zip"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}

@test "fails when REPO_PROVIDER_NAME missing" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_URL="ghcr.io"
  export REPO_PROVIDER_VERSION="1.0.0-manifests"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "REPO_PROVIDER_NAME"
}

@test "fails when REPO_PROVIDER_VERSION missing" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_URL="ghcr.io"
  export REPO_PROVIDER_NAME="test/my-repo"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "REPO_PROVIDER_VERSION"
}

@test "fails when REPO_PROVIDER_URL missing" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_NAME="test/my-repo"
  export REPO_PROVIDER_VERSION="1.0.0-manifests"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "REPO_PROVIDER_URL"
}

@test "always checks for existing image" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_docker_called "manifest inspect"
}

@test "fails when image already exists" {
  set_required_env
  # Make docker manifest inspect succeed (image exists)
  echo '#!/bin/bash
if [[ "$1" == "manifest" && "$2" == "inspect" ]]; then
  exit 0
fi
echo "$*" >> "$MOCK_DOCKER_CALLS"
exit 0' > "$MOCK_BIN_DIR/docker"
  chmod +x "$MOCK_BIN_DIR/docker"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "already exists"
}

@test "uses default pause image as base" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  # The script should output info about using pause as base
  assert_output_contains "ghcr.io/kube-kaptain/image/image-pause:3.10.2"
}

@test "allows overriding base image" {
  set_required_env
  export MANIFESTS_PACKAGING_BASE_IMAGE="custom.registry.io/my-org/custom-pause:1.0.0"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_output_contains "custom.registry.io/my-org/custom-pause:1.0.0"
}
