#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-run-deploy-image-validate. Docker is mocked; the
# image's own validate-environment is not under test.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-run-deploy-image-validate"

setup() {
  setup_mock_docker
  export IMAGE_BUILD_COMMAND="docker"
  export RUN_DEPLOY_IMAGE_URI="registry.example.com/team/run-env-test:1.0.0"
}

teardown() {
  dump_bats_result
}

@test "runs the image's validate-environment in echo-only notification mode" {
  export DOCKER_PLATFORM="linux/amd64"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_docker_called "run --rm registry.example.com/team/run-env-test:1.0.0 validate-environment --notify-echo-only"
}

@test "multi-arch validates one per-arch tag, still in echo-only mode" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_docker_called "registry.example.com/team/run-env-test:1.0.0-linux-.* validate-environment --notify-echo-only"
}
