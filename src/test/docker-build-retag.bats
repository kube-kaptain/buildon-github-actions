#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(mktemp)
}

teardown() {
  cleanup_mock_docker
  rm -f "$GITHUB_OUTPUT"
}

# Required env vars for most tests
set_required_env() {
  export SOURCE_REGISTRY="docker.io"
  export SOURCE_BASE_PATH="library"
  export SOURCE_IMAGE_NAME="alpine"
  export SOURCE_TAG="3.21"
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_BASE_PATH="test"
  export TARGET_IMAGE_NAME="my-repo"
  export DOCKER_TAG="1.0.0"
}

@test "assembles source URI correctly" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "SOURCE_IMAGE_FULL_URI" "docker.io/library/alpine:3.21"
}

@test "assembles target URI without base path" {
  set_required_env
  unset TARGET_BASE_PATH

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "TARGET_IMAGE_FULL_URI" "ghcr.io/my-repo:1.0.0"
}

@test "assembles target URI with base path" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "TARGET_IMAGE_FULL_URI" "ghcr.io/test/my-repo:1.0.0"
}

@test "assembles source URI without base path" {
  set_required_env
  unset SOURCE_BASE_PATH

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "SOURCE_IMAGE_FULL_URI" "docker.io/alpine:3.21"
}

@test "calls docker pull with source image" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_called "pull docker.io/library/alpine:3.21"
}

@test "calls docker tag with source and target" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag docker.io/library/alpine:3.21 ghcr.io/test/my-repo:1.0.0"
}

# === Warning and stripping tests ===

@test "warns and strips path from registry" {
  set_required_env
  export SOURCE_REGISTRY="docker.io/library"
  unset SOURCE_BASE_PATH

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "SOURCE_REGISTRY contains path"
  assert_output_contains "Stripping"
  assert_var_equals "SOURCE_IMAGE_FULL_URI" "docker.io/alpine:3.21"
}

@test "warns and strips path from image name" {
  set_required_env
  export SOURCE_IMAGE_NAME="library/alpine"
  unset SOURCE_BASE_PATH

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "SOURCE_IMAGE_NAME contains path"
  assert_output_contains "Stripping"
  assert_var_equals "SOURCE_IMAGE_FULL_URI" "docker.io/alpine:3.21"
}

@test "warns and strips leading slash from base path" {
  set_required_env
  export SOURCE_BASE_PATH="/library"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "SOURCE_BASE_PATH has leading/trailing slashes"
  assert_var_equals "SOURCE_IMAGE_FULL_URI" "docker.io/library/alpine:3.21"
}

@test "warns and strips trailing slash from base path" {
  set_required_env
  export TARGET_BASE_PATH="test/"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "TARGET_BASE_PATH has leading/trailing slashes"
  assert_var_equals "TARGET_IMAGE_FULL_URI" "ghcr.io/test/my-repo:1.0.0"
}

@test "uses LOG_WARNING_PREFIX in warnings" {
  set_required_env
  export SOURCE_REGISTRY="docker.io/library"
  export LOG_WARNING_PREFIX="::warning::"
  unset SOURCE_BASE_PATH

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "::warning::SOURCE_REGISTRY contains path"
}

@test "does not push (build only)" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
}

@test "fails when SOURCE_REGISTRY missing" {
  export SOURCE_BASE_PATH="library"
  export SOURCE_IMAGE_NAME="alpine"
  export SOURCE_TAG="3.21"
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_BASE_PATH="test"
  export TARGET_IMAGE_NAME="my-repo"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "SOURCE_REGISTRY"
}

@test "fails when TARGET_IMAGE_NAME missing" {
  export SOURCE_REGISTRY="docker.io"
  export SOURCE_BASE_PATH="library"
  export SOURCE_IMAGE_NAME="alpine"
  export SOURCE_TAG="3.21"
  export TARGET_REGISTRY="ghcr.io"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "TARGET_IMAGE_NAME"
}

@test "fails when image already exists" {
  set_required_env
  # Mock docker manifest inspect to return success (image exists)
  export MOCK_DOCKER_MANIFEST_EXISTS="true"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "already exists"
}

@test "always checks for existing image" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  # Should have called manifest inspect (the mock returns non-zero by default)
  assert_docker_called "manifest inspect"
}

@test "works with custom registry and base path" {
  set_required_env
  export TARGET_REGISTRY="myregistry.example.com"
  export TARGET_BASE_PATH="docker-local"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "TARGET_IMAGE_FULL_URI" "myregistry.example.com/docker-local/my-repo:1.0.0"
}
