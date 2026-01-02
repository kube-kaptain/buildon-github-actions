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

@test "pushes when IS_RELEASE=true" {
  export DOCKER_IMAGE_FULL_URI="ghcr.io/test/my-repo:1.0.0"
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push"
  [ "$status" -eq 0 ]
  assert_docker_called "push ghcr.io/test/my-repo:1.0.0"
  assert_var_equals "IMAGE_PUSHED" "true"
}

@test "skips push when IS_RELEASE=false" {
  export DOCKER_IMAGE_FULL_URI="ghcr.io/test/my-repo:1.0.0"
  export IS_RELEASE="false"

  run "$SCRIPTS_DIR/docker-push"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
  assert_var_equals "IMAGE_PUSHED" "false"
}

@test "defaults IS_RELEASE to false" {
  export DOCKER_IMAGE_FULL_URI="ghcr.io/test/my-repo:1.0.0"
  unset IS_RELEASE

  run "$SCRIPTS_DIR/docker-push"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
  assert_var_equals "IMAGE_PUSHED" "false"
}

@test "fails when DOCKER_IMAGE_FULL_URI missing" {
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_IMAGE_FULL_URI"
}
