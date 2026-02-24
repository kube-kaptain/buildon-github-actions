#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export IMAGE_BUILD_COMMAND="docker"
  local base_dir=$(create_test_dir "docker-platform-setup")
  export GITHUB_OUTPUT="$base_dir/output"
}

teardown() {
  :
}

# === Platform validation ===

@test "accepts linux/amd64" {
  export DOCKER_PLATFORM="linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/amd64"
}

@test "accepts linux/arm64" {
  export DOCKER_PLATFORM="linux/arm64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/arm64"
}

@test "accepts linux/amd64,linux/arm64" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/amd64,linux/arm64"
}

@test "accepts linux/arm64,linux/amd64" {
  export DOCKER_PLATFORM="linux/arm64,linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/arm64,linux/amd64"
}

@test "rejects windows/amd64" {
  export DOCKER_PLATFORM="windows/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value 'windows/amd64'"
}

@test "empty string defaults to linux/amd64" {
  export DOCKER_PLATFORM=""

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/amd64"
}

@test "rejects amd64 without os prefix" {
  export DOCKER_PLATFORM="amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value 'amd64'"
}

@test "rejects three platforms" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64,linux/s390x"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value"
}

@test "rejects platform with spaces" {
  export DOCKER_PLATFORM="linux/amd64, linux/arm64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value"
}

@test "defaults to linux/amd64 when not set" {
  unset DOCKER_PLATFORM

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/amd64"
}

# === QEMU install ===

@test "skips QEMU install on non-Linux" {
  export DOCKER_PLATFORM="linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Not a Linux build server"
}

# === Output messages ===

@test "outputs header with platform and build mode" {
  export DOCKER_PLATFORM="linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker Platform Setup"
  assert_output_contains "Platform: linux/amd64"
  assert_output_contains "Build mode:"
}

@test "outputs complete message" {
  export DOCKER_PLATFORM="linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker platform setup complete"
}
