#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-docker-package
# This script builds a Docker image containing the manifests zip.

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip file
  export TEST_ZIP=$(mktemp)
  echo "test content" > "$TEST_ZIP"
  # Create output directory
  export OUTPUT_PATH=$(mktemp -d)
}

teardown() {
  cleanup_mock_docker
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_ZIP"
  rm -rf "$OUTPUT_PATH"
}

# Required env vars for most tests
set_required_env() {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0-manifests"
}

@test "assembles target URI without base path" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "ghcr.io/test/my-repo:1.0.0-manifests"
}

@test "assembles target URI with base path" {
  set_required_env
  export TARGET_BASE_PATH="kube-kaptain"

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
  [ -d "$OUTPUT_PATH/publish/docker" ]
  [ -f "$OUTPUT_PATH/publish/docker/Dockerfile" ]
  # Zip file should be copied with original name (basename of TEST_ZIP)
  local zip_name
  zip_name=$(basename "$TEST_ZIP")
  [ -f "$OUTPUT_PATH/publish/docker/$zip_name" ]
}

@test "does not push (package only)" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
}

@test "fails when MANIFESTS_ZIP_PATH missing" {
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0-manifests"
  unset MANIFESTS_ZIP_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_PATH"
}

@test "fails when zip file not found" {
  set_required_env
  export MANIFESTS_ZIP_PATH="/nonexistent/file.zip"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}

@test "fails when TARGET_IMAGE_NAME missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export TARGET_REGISTRY="ghcr.io"
  export DOCKER_TAG="1.0.0-manifests"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "TARGET_IMAGE_NAME"
}

@test "fails when DOCKER_TAG missing" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_IMAGE_NAME="test/my-repo"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_TAG"
}

@test "defaults TARGET_REGISTRY to ghcr.io" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export TARGET_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0-manifests"
  unset TARGET_REGISTRY

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "ghcr.io/test/my-repo:1.0.0-manifests"
}

@test "defaults CONFIRM_IMAGE_DOESNT_EXIST to true" {
  set_required_env
  unset CONFIRM_IMAGE_DOESNT_EXIST

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_docker_called "manifest inspect"
}

@test "skips confirm when CONFIRM_IMAGE_DOESNT_EXIST=false" {
  set_required_env
  export CONFIRM_IMAGE_DOESNT_EXIST="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  assert_docker_not_called "manifest"
}

@test "fails when image already exists and confirm enabled" {
  set_required_env
  export CONFIRM_IMAGE_DOESNT_EXIST="true"
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

@test "uses pause image as base" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-package"
  [ "$status" -eq 0 ]
  # The script should output info about using pause as base
  assert_output_contains "registry.k8s.io/pause:3.10.1"
}
