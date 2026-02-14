#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_docker
  export IMAGE_BUILD_COMMAND="docker"
  TEST_DIR=$(create_test_dir "docker-push-all")
  export GITHUB_OUTPUT="${TEST_DIR}/output"
  export OUTPUT_SUB_PATH="${TEST_DIR}/target"
  export DOCKER_PUSH_IMAGE_LIST_FILE="${OUTPUT_SUB_PATH}/docker-push-all/image-uris"
  mkdir -p "${OUTPUT_SUB_PATH}/docker-push-all"
}

teardown() {
  :
}

# Helper to write image URIs file
write_uris() {
  printf '%s\n' "$@" > "${OUTPUT_SUB_PATH}/docker-push-all/image-uris"
}

# === IS_RELEASE gating ===

@test "skips push when IS_RELEASE=false" {
  write_uris "ghcr.io/test/my-repo:1.0.0"
  export IS_RELEASE="false"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
  assert_var_equals "IMAGES_PUSHED" "0"
}

@test "defaults IS_RELEASE to false" {
  write_uris "ghcr.io/test/my-repo:1.0.0"
  unset IS_RELEASE

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
  assert_var_equals "IMAGES_PUSHED" "0"
}

# === File validation ===

@test "fails when image URIs file missing" {
  rm -f "${OUTPUT_SUB_PATH}/docker-push-all/image-uris"
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -ne 0 ]
  assert_output_contains "not found"
}

@test "fails when image URIs file is empty" {
  : > "${OUTPUT_SUB_PATH}/docker-push-all/image-uris"
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -ne 0 ]
  assert_output_contains "empty"
}

# === Push functionality ===

@test "pushes single image" {
  write_uris "ghcr.io/test/my-repo:1.0.0"
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  assert_docker_called "image inspect ghcr.io/test/my-repo:1.0.0"
  assert_docker_called "push ghcr.io/test/my-repo:1.0.0"
  assert_var_equals "IMAGES_PUSHED" "1"
}

@test "pushes multiple images" {
  write_uris \
    "ghcr.io/test/my-repo:1.0.0" \
    "docker.io/test/my-repo:1.0.0" \
    "ghcr.io/test/my-repo:1.0.0-manifests"
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  assert_docker_called "push ghcr.io/test/my-repo:1.0.0"
  assert_docker_called "push docker.io/test/my-repo:1.0.0"
  assert_docker_called "push ghcr.io/test/my-repo:1.0.0-manifests"
  assert_var_equals "IMAGES_PUSHED" "3"
}

@test "skips blank lines in URIs file" {
  printf 'ghcr.io/test/my-repo:1.0.0\n\ndocker.io/test/my-repo:1.0.0\n' \
    > "${OUTPUT_SUB_PATH}/docker-push-all/image-uris"
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  assert_docker_called "push ghcr.io/test/my-repo:1.0.0"
  assert_docker_called "push docker.io/test/my-repo:1.0.0"
  assert_var_equals "IMAGES_PUSHED" "2"
}

# === Output ===

@test "outputs count to GITHUB_OUTPUT" {
  write_uris "ghcr.io/test/my-repo:1.0.0" "docker.io/test/my-repo:1.0.0"
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  grep -q "IMAGES_PUSHED=2" "$GITHUB_OUTPUT"
}

@test "outputs zero count when skipped" {
  write_uris "ghcr.io/test/my-repo:1.0.0"
  export IS_RELEASE="false"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  grep -q "IMAGES_PUSHED=0" "$GITHUB_OUTPUT"
}

@test "outputs progress messages to stderr" {
  write_uris "ghcr.io/test/my-repo:1.0.0"
  export IS_RELEASE="true"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker Push All"
  assert_output_contains "Pushing:"
}

@test "outputs skip message when not releasing" {
  write_uris "ghcr.io/test/my-repo:1.0.0"
  export IS_RELEASE="false"

  run "$SCRIPTS_DIR/docker-push-all"
  [ "$status" -eq 0 ]
  assert_output_contains "Skipping push"
}
