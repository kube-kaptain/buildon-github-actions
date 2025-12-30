#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test directory with Dockerfile
  export TEST_DIR=$(mktemp -d)
  echo "FROM alpine:3.21" > "$TEST_DIR/Dockerfile"
}

teardown() {
  cleanup_mock_docker
  rm -f "$GITHUB_OUTPUT"
  rm -rf "$TEST_DIR"
}

# Required env vars for most tests
set_required_env() {
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"
  export VERSION="1.0.0"
  export PROJECT_NAME="my-repo"
  export DOCKERFILE_SUB_PATH="$TEST_DIR"
  export SQUASH="false"
}

@test "assembles target URI without base path" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_var_equals "TARGET_IMAGE_FULL_URI" "ghcr.io/test/my-repo:1.0.0"
}

@test "assembles target URI with base path" {
  set_required_env
  export TARGET_BASE_PATH="kube-kaptain"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_var_equals "TARGET_IMAGE_FULL_URI" "ghcr.io/kube-kaptain/test/my-repo:1.0.0"
}

@test "calls docker build with correct args" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Check key parts of the build command (labels are tested separately)
  assert_docker_called "build -f $TEST_DIR/Dockerfile -t ghcr.io/test/my-repo:1.0.0"
  assert_docker_called "$TEST_DIR"
}

@test "does not push (build only)" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
}

@test "fails when TARGET_REGISTRY missing" {
  export TARGET_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"
  export DOCKERFILE_SUB_PATH="$TEST_DIR"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -ne 0 ]
  assert_output_contains "TARGET_REGISTRY"
}

@test "fails when Dockerfile directory not found" {
  set_required_env
  export DOCKERFILE_SUB_PATH="/nonexistent/path"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -ne 0 ]
  assert_output_contains "Dockerfile directory not found"
}

@test "fails when Dockerfile not in directory" {
  set_required_env
  rm "$TEST_DIR/Dockerfile"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -ne 0 ]
  assert_output_contains "Dockerfile not found"
}

@test "fails when Dockerfile has wrong case" {
  set_required_env
  rm "$TEST_DIR/Dockerfile"
  echo "FROM alpine:3.21" > "$TEST_DIR/dockerfile"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -ne 0 ]
  assert_output_contains "wrong case"
}

@test "adds standard build args" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_called "--build-arg VERSION=1.0.0"
  assert_docker_called "--build-arg PROJECT_NAME=my-repo"
}

@test "adds standard labels automatically" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_called "--label version=1.0.0"
  assert_docker_called "--label image.name=test/my-repo"
  # build.datetime label should be present with ISO 8601 UTC format
  assert_docker_called "--label build.datetime="
}

@test "adds --squash when SQUASH=true" {
  set_required_env
  export SQUASH="true"
  # Mock systemctl to avoid actual daemon restart
  mkdir -p "$MOCK_BIN_DIR"
  echo '#!/bin/bash' > "$MOCK_BIN_DIR/systemctl"
  echo 'exit 0' >> "$MOCK_BIN_DIR/systemctl"
  chmod +x "$MOCK_BIN_DIR/systemctl"
  # Mock sudo to just succeed (no-op, don't run real commands)
  echo '#!/bin/bash' > "$MOCK_BIN_DIR/sudo"
  echo 'exit 0' >> "$MOCK_BIN_DIR/sudo"
  chmod +x "$MOCK_BIN_DIR/sudo"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_called "--squash"
}

@test "defaults SQUASH to true" {
  set_required_env
  unset SQUASH
  # Mock systemctl and sudo for experimental mode
  mkdir -p "$MOCK_BIN_DIR"
  echo '#!/bin/bash' > "$MOCK_BIN_DIR/systemctl"
  echo 'exit 0' >> "$MOCK_BIN_DIR/systemctl"
  chmod +x "$MOCK_BIN_DIR/systemctl"
  echo '#!/bin/bash' > "$MOCK_BIN_DIR/sudo"
  echo 'exit 0' >> "$MOCK_BIN_DIR/sudo"
  chmod +x "$MOCK_BIN_DIR/sudo"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_called "--squash"
}

@test "uses dockerfile-path as context" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Context should be the dockerfile path
  assert_docker_called "$TEST_DIR"
}

@test "fails when image already exists" {
  set_required_env
  # Make docker manifest inspect succeed (image exists)
  echo '#!/bin/bash
if [[ "$1" == "manifest" && "$2" == "inspect" ]]; then
  exit 0
fi
if [[ "$1" == "info" ]]; then
  exit 0
fi
echo "$@" >> "$MOCK_DOCKER_CALLS"
exit 0' > "$MOCK_BIN_DIR/docker"
  chmod +x "$MOCK_BIN_DIR/docker"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -ne 0 ]
  assert_output_contains "already exists"
}

@test "always checks for existing image" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Should have called manifest inspect (the mock returns non-zero by default)
  assert_docker_called "manifest inspect"
}

@test "adds --no-cache by default" {
  set_required_env
  unset NO_CACHE

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_called "--no-cache"
}

@test "skips --no-cache when NO_CACHE=false" {
  set_required_env
  export NO_CACHE="false"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_not_called "--no-cache"
}
