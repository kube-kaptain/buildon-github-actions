#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export TEST_WORK_DIR=$(create_test_dir "manifests-override")
  export GITHUB_OUTPUT="$TEST_WORK_DIR/output"
  cd "$TEST_WORK_DIR"
  export OUTPUT_SUB_PATH="target"

  # Create config directory with default tokens (simulating prepare has run)
  mkdir -p "$OUTPUT_SUB_PATH/manifests/config"
  printf '%s' "original-image" > "$OUTPUT_SUB_PATH/manifests/config/DockerImageName"
  printf '%s' "original-tag" > "$OUTPUT_SUB_PATH/manifests/config/DockerTag"
}

teardown() {
  :
}

@test "overwrites image name token when override provided" {
  export DOCKER_IMAGE_NAME_OVERRIDE="my-org/my-image"
  export DOCKER_TAG_OVERRIDE=""

  run "$SCRIPTS_DIR/kubernetes-manifests-package-only-token-override"
  [ "$status" -eq 0 ]

  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/DockerImageName")" = "my-org/my-image" ]
  # Tag token should be removed (empty override)
  [ ! -f "$OUTPUT_SUB_PATH/manifests/config/DockerTag" ]
}

@test "overwrites tag token when override provided" {
  export DOCKER_IMAGE_NAME_OVERRIDE=""
  export DOCKER_TAG_OVERRIDE="2.0.0"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-only-token-override"
  [ "$status" -eq 0 ]

  # Image name token should be removed (empty override)
  [ ! -f "$OUTPUT_SUB_PATH/manifests/config/DockerImageName" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/DockerTag")" = "2.0.0" ]
}

@test "overwrites both tokens when both overrides provided" {
  export DOCKER_IMAGE_NAME_OVERRIDE="new-org/new-image"
  export DOCKER_TAG_OVERRIDE="3.0.0"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-only-token-override"
  [ "$status" -eq 0 ]

  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/DockerImageName")" = "new-org/new-image" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/DockerTag")" = "3.0.0" ]
}

@test "removes both tokens when both overrides empty" {
  export DOCKER_IMAGE_NAME_OVERRIDE=""
  export DOCKER_TAG_OVERRIDE=""

  run "$SCRIPTS_DIR/kubernetes-manifests-package-only-token-override"
  [ "$status" -eq 0 ]

  [ ! -f "$OUTPUT_SUB_PATH/manifests/config/DockerImageName" ]
  [ ! -f "$OUTPUT_SUB_PATH/manifests/config/DockerTag" ]
}

@test "fails when config directory does not exist" {
  rm -rf "$OUTPUT_SUB_PATH/manifests/config"
  export DOCKER_IMAGE_NAME_OVERRIDE="test"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-only-token-override"
  [ "$status" -ne 0 ]
  assert_output_contains "Config directory not found"
  assert_output_contains "kubernetes-manifests-package-prepare"
}

@test "respects lower-kebab token name style" {
  export TOKEN_NAME_STYLE="lower-kebab"
  export DOCKER_IMAGE_NAME_OVERRIDE="kebab-image"
  export DOCKER_TAG_OVERRIDE="kebab-tag"

  # Create tokens with lower-kebab names
  printf '%s' "original" > "$OUTPUT_SUB_PATH/manifests/config/docker-image-name"
  printf '%s' "original" > "$OUTPUT_SUB_PATH/manifests/config/docker-tag"

  run "$SCRIPTS_DIR/kubernetes-manifests-package-only-token-override"
  [ "$status" -eq 0 ]

  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/docker-image-name")" = "kebab-image" ]
  [ "$(cat "$OUTPUT_SUB_PATH/manifests/config/docker-tag")" = "kebab-tag" ]
}

@test "outputs progress messages" {
  export DOCKER_IMAGE_NAME_OVERRIDE="test-image"
  export DOCKER_TAG_OVERRIDE=""

  run "$SCRIPTS_DIR/kubernetes-manifests-package-only-token-override"
  [ "$status" -eq 0 ]
  assert_output_contains "Overwriting DockerImageName"
  assert_output_contains "Removing DockerTag"
}
