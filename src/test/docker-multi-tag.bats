#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

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
  export DOCKER_IMAGE_FULL_URI="ghcr.io/test/my-repo:1.0.0"
  export DOCKER_IMAGE_NAME="my-repo"
  export DOCKER_TAG="1.0.0"
}

# === Basic functionality ===

@test "tags image to single registry" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
}

@test "tags image to multiple registries" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[
    {"registry": "docker.io"},
    {"registry": "quay.io"},
    {"registry": "gcr.io"}
  ]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/my-repo:1.0.0"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 quay.io/my-repo:1.0.0"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 gcr.io/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "3"
}

@test "includes base-path when specified" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io", "base-path": "library"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/library/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
}

@test "handles mix of targets with and without base-path" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[
    {"registry": "docker.io"},
    {"registry": "quay.io", "base-path": "myorg"}
  ]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/my-repo:1.0.0"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 quay.io/myorg/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "2"
}

@test "handles nested base-path" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": "myregistry.example.com", "base-path": "team/project"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 myregistry.example.com/team/project/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
}

@test "handles ECR registry format" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": "123456789012.dkr.ecr.us-east-1.amazonaws.com"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
}

# === Error handling ===

@test "fails when DOCKER_IMAGE_FULL_URI missing" {
  export DOCKER_IMAGE_NAME="my-repo"
  export DOCKER_TAG="1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_IMAGE_FULL_URI"
}

@test "fails when DOCKER_IMAGE_NAME missing" {
  export DOCKER_IMAGE_FULL_URI="ghcr.io/test/my-repo:1.0.0"
  export DOCKER_TAG="1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_IMAGE_NAME"
}

@test "fails when DOCKER_TAG missing" {
  export DOCKER_IMAGE_FULL_URI="ghcr.io/test/my-repo:1.0.0"
  export DOCKER_IMAGE_NAME="my-repo"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_TAG"
}

@test "fails when DOCKER_PUSH_TARGETS missing" {
  export DOCKER_IMAGE_FULL_URI="ghcr.io/test/my-repo:1.0.0"
  export DOCKER_IMAGE_NAME="my-repo"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_PUSH_TARGETS"
}

@test "fails when target missing registry field" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"base-path": "myorg"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "missing required 'registry' field"
}

@test "fails when target has null registry" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": null}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "missing required 'registry' field"
}

@test "fails on invalid JSON" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "must be a valid JSON array"
}

# === Output formatting ===

@test "outputs count to GITHUB_OUTPUT" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}, {"registry": "quay.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]

  # Check GITHUB_OUTPUT file was written
  grep -q "IMAGES_TAGGED=2" "$GITHUB_OUTPUT"
}

@test "outputs progress messages to stderr" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker Multi-Tag"
  assert_output_contains "Source image: ghcr.io/test/my-repo:1.0.0"
  assert_output_contains "Tagging:"
}
