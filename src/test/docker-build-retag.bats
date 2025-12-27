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
  export SOURCE_IMAGE_NAME="library/alpine"
  export SOURCE_TAG="3.21"
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_IMAGE_NAME="test/my-repo"
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

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "TARGET_IMAGE_FULL_URI" "ghcr.io/test/my-repo:1.0.0"
}

@test "assembles target URI with base path" {
  set_required_env
  export TARGET_BASE_PATH="kube-kaptain"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "TARGET_IMAGE_FULL_URI" "ghcr.io/kube-kaptain/test/my-repo:1.0.0"
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

@test "does not push (build only)" {
  set_required_env

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
}

@test "fails when SOURCE_REGISTRY missing" {
  export SOURCE_IMAGE_NAME="library/alpine"
  export SOURCE_TAG="3.21"
  export TARGET_REGISTRY="ghcr.io"
  export TARGET_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "SOURCE_REGISTRY"
}

@test "fails when TARGET_IMAGE_NAME missing" {
  export SOURCE_REGISTRY="docker.io"
  export SOURCE_IMAGE_NAME="library/alpine"
  export SOURCE_TAG="3.21"
  export TARGET_REGISTRY="ghcr.io"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "TARGET_IMAGE_NAME"
}

@test "defaults CONFIRM_IMAGE_DOESNT_EXIST to true" {
  set_required_env
  # Don't set CONFIRM_IMAGE_DOESNT_EXIST - should default to true
  # Mock docker manifest inspect to return success (image exists)
  export MOCK_DOCKER_MANIFEST_EXISTS="true"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -ne 0 ]
  assert_output_contains "already exists"
}

@test "skips confirm when CONFIRM_IMAGE_DOESNT_EXIST=false" {
  set_required_env
  export CONFIRM_IMAGE_DOESNT_EXIST="false"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
}

@test "works with custom registry and base path" {
  set_required_env
  export TARGET_REGISTRY="myregistry.example.com"
  export TARGET_BASE_PATH="docker-local"
  export CONFIRM_IMAGE_DOESNT_EXIST="false"

  run "$SCRIPTS_DIR/docker-build-retag"
  [ "$status" -eq 0 ]
  assert_var_equals "TARGET_IMAGE_FULL_URI" "myregistry.example.com/docker-local/test/my-repo:1.0.0"
}
