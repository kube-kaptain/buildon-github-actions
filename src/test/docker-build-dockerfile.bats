#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_docker
  local base_dir=$(create_test_dir "docker-dockerfile")
  export GITHUB_OUTPUT="$base_dir/output"
  # Create a test directory with Dockerfile
  export TEST_DIR="$base_dir/src"
  mkdir -p "$TEST_DIR"
  echo "FROM alpine:3.21" > "$TEST_DIR/Dockerfile"
  # Create output directory for substitution
  export OUTPUT_DIR="$base_dir/target"
  mkdir -p "$OUTPUT_DIR"
}

teardown() {
  :
}

# Required env vars for most tests
set_required_env() {
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"
  export VERSION="1.0.0"
  export PROJECT_NAME="my-repo"
  export DOCKERFILE_SUB_PATH="$TEST_DIR"
  export OUTPUT_SUB_PATH="$OUTPUT_DIR"
  export DOCKERFILE_SQUASH="false"
  export IS_RELEASE="true"
}

@test "assembles target URI without base path" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TARGET_IMAGE_FULL_URI" "ghcr.io/test/my-repo:1.0.0"
}

@test "assembles target URI with base path" {
  set_required_env
  export DOCKER_TARGET_BASE_PATH="kube-kaptain"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TARGET_IMAGE_FULL_URI" "ghcr.io/kube-kaptain/test/my-repo:1.0.0"
}

@test "calls docker build with correct args" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Check key parts of the build command - now uses substituted path
  assert_docker_called "build -f $OUTPUT_DIR/docker/substituted/Dockerfile -t ghcr.io/test/my-repo:1.0.0"
  assert_docker_called "$OUTPUT_DIR/docker/substituted"
}

@test "does not push (build only)" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
}

@test "fails when DOCKER_TARGET_REGISTRY missing" {
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"
  export DOCKERFILE_SUB_PATH="$TEST_DIR"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_TARGET_REGISTRY"
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

@test "adds --squash when DOCKERFILE_SQUASH=true" {
  set_required_env
  export DOCKERFILE_SQUASH="true"
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

@test "defaults DOCKERFILE_SQUASH to true" {
  set_required_env
  unset DOCKERFILE_SQUASH
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

@test "uses substituted directory as context" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Context should be the substituted directory
  assert_docker_called "$OUTPUT_DIR/docker/substituted"
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
  unset DOCKERFILE_NO_CACHE

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_called "--no-cache"
}

@test "skips --no-cache when DOCKERFILE_NO_CACHE=false" {
  set_required_env
  export DOCKERFILE_NO_CACHE="false"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  assert_docker_not_called "--no-cache"
}

@test "substitutes tokens in Dockerfile" {
  set_required_env
  # Create Dockerfile with token
  echo 'FROM ${TargetRegistry}/${TargetBasePath}/base:1.0' > "$TEST_DIR/Dockerfile"
  export DOCKER_TARGET_BASE_PATH="my-org"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Check that substitution happened in the copied file
  run cat "$OUTPUT_DIR/docker/substituted/Dockerfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ghcr.io/my-org/base:1.0"* ]]
}

@test "copies all files from docker directory" {
  set_required_env
  # Add extra files
  echo "#!/bin/bash" > "$TEST_DIR/entrypoint.sh"
  echo "some config" > "$TEST_DIR/config.txt"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Check all files were copied
  [ -f "$OUTPUT_DIR/docker/substituted/Dockerfile" ]
  [ -f "$OUTPUT_DIR/docker/substituted/entrypoint.sh" ]
  [ -f "$OUTPUT_DIR/docker/substituted/config.txt" ]
}

@test "substitutes tokens in all docker files" {
  set_required_env
  export DOCKER_TARGET_BASE_PATH="my-org"
  # Create files with tokens
  echo 'FROM alpine:3.21' > "$TEST_DIR/Dockerfile"
  echo 'REGISTRY=${TargetRegistry}' > "$TEST_DIR/config.sh"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Check substitution in config file
  run cat "$OUTPUT_DIR/docker/substituted/config.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"REGISTRY=ghcr.io"* ]]
}

@test "uses user config tokens from src/config" {
  set_required_env
  # Create user config
  mkdir -p "$TEST_DIR/../config"
  echo "my-custom-value" > "$TEST_DIR/../config/MyToken"
  export CONFIG_SUB_PATH="$TEST_DIR/../config"
  # Create Dockerfile with user token
  echo 'ENV MY_VAR=${MyToken}' > "$TEST_DIR/Dockerfile"

  run "$SCRIPTS_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]
  # Check substitution happened
  run cat "$OUTPUT_DIR/docker/substituted/Dockerfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENV MY_VAR=my-custom-value"* ]]

}
