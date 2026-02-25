#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_docker
  export IMAGE_BUILD_COMMAND="docker"
  local base_dir=$(create_test_dir "docker-retag")
  export GITHUB_OUTPUT="$base_dir/output"
  export DOCKER_PUSH_IMAGE_LIST_FILE="$base_dir/target/docker-push-all/image-uris"
  mkdir -p "$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")"
}

teardown() {
  :
}

# Required env vars for most tests
set_required_env() {
  export DOCKER_SOURCE_REGISTRY="docker.io"
  export DOCKER_SOURCE_NAMESPACE="library"
  export DOCKER_SOURCE_IMAGE_NAME="alpine"
  export DOCKER_SOURCE_TAG="3.21"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="test"
  export DOCKER_IMAGE_NAME="my-repo"
  export DOCKER_TAG="1.0.0"
}

@test "assembles source URI correctly" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_SOURCE_IMAGE_FULL_URI" "docker.io/library/alpine:3.21"
}

@test "assembles target URI without namespace" {
  set_required_env
  unset DOCKER_TARGET_NAMESPACE

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TARGET_IMAGE_FULL_URI" "ghcr.io/my-repo:1.0.0"
}

@test "assembles target URI with namespace" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TARGET_IMAGE_FULL_URI" "ghcr.io/test/my-repo:1.0.0"
}

@test "assembles source URI without namespace" {
  set_required_env
  unset DOCKER_SOURCE_NAMESPACE

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_SOURCE_IMAGE_FULL_URI" "docker.io/alpine:3.21"
}

@test "calls docker pull with platform and source image" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_called "pull --platform linux/amd64 docker.io/library/alpine:3.21"
}

@test "uses default platform linux/amd64 on pull" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_called "--platform linux/amd64"
}

@test "uses custom single platform on pull" {
  set_required_env
  export DOCKER_PLATFORM="linux/arm64"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_called "pull --platform linux/arm64"
}

@test "calls docker tag with source and target" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag docker.io/library/alpine:3.21 ghcr.io/test/my-repo:1.0.0"
}

# === Warning and stripping tests ===

@test "fails when source registry contains path" {
  set_required_env
  export DOCKER_SOURCE_REGISTRY="docker.io/library"
  unset DOCKER_SOURCE_NAMESPACE

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_SOURCE_REGISTRY cannot contain slashes"
}

@test "fails when target registry contains path" {
  set_required_env
  export DOCKER_TARGET_REGISTRY="ghcr.io/org"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_TARGET_REGISTRY cannot contain slashes"
}

@test "warns and strips leading slash from image name" {
  set_required_env
  export DOCKER_SOURCE_IMAGE_NAME="/alpine"
  unset DOCKER_SOURCE_NAMESPACE

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "DOCKER_SOURCE_IMAGE_NAME has leading/trailing slashes"
  assert_output_contains "Stripping"
  assert_var_equals "DOCKER_SOURCE_IMAGE_FULL_URI" "docker.io/alpine:3.21"
}

@test "allows internal slashes in image name" {
  set_required_env
  export DOCKER_SOURCE_IMAGE_NAME="library/alpine"
  unset DOCKER_SOURCE_NAMESPACE

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  # No warning - internal slashes are valid
  assert_var_equals "DOCKER_SOURCE_IMAGE_FULL_URI" "docker.io/library/alpine:3.21"
}

@test "warns and strips leading slash from namespace" {
  set_required_env
  export DOCKER_SOURCE_NAMESPACE="/library"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "DOCKER_SOURCE_NAMESPACE has leading/trailing slashes"
  assert_var_equals "DOCKER_SOURCE_IMAGE_FULL_URI" "docker.io/library/alpine:3.21"
}

@test "warns and strips trailing slash from namespace" {
  set_required_env
  export DOCKER_TARGET_NAMESPACE="test/"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "DOCKER_TARGET_NAMESPACE has leading/trailing slashes"
  assert_var_equals "DOCKER_TARGET_IMAGE_FULL_URI" "ghcr.io/test/my-repo:1.0.0"
}

@test "warns about leading/trailing slashes in image name" {
  set_required_env
  export DOCKER_SOURCE_IMAGE_NAME="/alpine"
  unset DOCKER_SOURCE_NAMESPACE

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_output_contains "WARNING: DOCKER_SOURCE_IMAGE_NAME has leading/trailing slashes"
}

@test "does not push (build only)" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
}

@test "fails when DOCKER_SOURCE_REGISTRY missing" {
  export DOCKER_SOURCE_NAMESPACE="library"
  export DOCKER_SOURCE_IMAGE_NAME="alpine"
  export DOCKER_SOURCE_TAG="3.21"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="test"
  export DOCKER_IMAGE_NAME="my-repo"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_SOURCE_REGISTRY"
}

@test "fails when DOCKER_IMAGE_NAME missing" {
  export DOCKER_SOURCE_REGISTRY="docker.io"
  export DOCKER_SOURCE_NAMESPACE="library"
  export DOCKER_SOURCE_IMAGE_NAME="alpine"
  export DOCKER_SOURCE_TAG="3.21"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_IMAGE_NAME"
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

@test "works with custom registry and namespace" {
  set_required_env
  export DOCKER_TARGET_REGISTRY="myregistry.example.com"
  export DOCKER_TARGET_NAMESPACE="docker-local"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TARGET_IMAGE_FULL_URI" "myregistry.example.com/docker-local/my-repo:1.0.0"
}

# === Multi-platform tests ===

@test "multi-platform pulls both architectures" {
  set_required_env
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  export OUTPUT_SUB_PATH="$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")/.."

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_called "pull --platform linux/amd64 docker.io/library/alpine:3.21"
  assert_docker_called "pull --platform linux/arm64 docker.io/library/alpine:3.21"
}

@test "multi-platform tags with arch-suffixed URIs" {
  set_required_env
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  export OUTPUT_SUB_PATH="$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")/.."

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag docker.io/library/alpine:3.21 ghcr.io/test/my-repo:1.0.0-linux-amd64"
  assert_docker_called "tag docker.io/library/alpine:3.21 ghcr.io/test/my-repo:1.0.0-linux-arm64"
}

@test "multi-platform registers arch URIs in image-uris" {
  set_required_env
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  export OUTPUT_SUB_PATH="$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")/.."

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]

  [ -f "$DOCKER_PUSH_IMAGE_LIST_FILE" ]
  run cat "$DOCKER_PUSH_IMAGE_LIST_FILE"
  [[ "$output" == *"ghcr.io/test/my-repo:1.0.0-linux-amd64"* ]]
  [[ "$output" == *"ghcr.io/test/my-repo:1.0.0-linux-arm64"* ]]
}

@test "multi-platform registers base URI in manifest-uris" {
  set_required_env
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  export OUTPUT_SUB_PATH="$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")/.."

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]

  local manifest_file="${OUTPUT_SUB_PATH}/docker-push-all/manifest-uris"
  [ -f "$manifest_file" ]
  run cat "$manifest_file"
  [[ "$output" == *"ghcr.io/test/my-repo:1.0.0"* ]]
}

@test "multi-platform outputs base URI as DOCKER_TARGET_IMAGE_FULL_URI" {
  set_required_env
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  export OUTPUT_SUB_PATH="$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")/.."

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TARGET_IMAGE_FULL_URI" "ghcr.io/test/my-repo:1.0.0"
}
