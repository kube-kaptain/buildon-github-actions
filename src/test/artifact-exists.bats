#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for util/artifact-exists and the docker artifact-exists provider plugin
# Covers routing, provider prefix parsing, default provider, and pass/fail
# behaviour against a mocked `docker manifest inspect`.

load helpers

SCRIPT="$UTIL_DIR/artifact-exists"

setup() {
  TEST_DIR=$(create_test_dir "artifact-exists")
  export IMAGE_BUILD_COMMAND="docker"
  setup_mock_docker
}

# =============================================================================
# Default provider routing
# =============================================================================

@test "exists: routes to docker provider by default and returns 0 when present" {
  export MOCK_DOCKER_MANIFEST_EXISTS=true
  run "$SCRIPT" "ghcr.io/kube-kaptain/quality/quality-strict:1.0.0"
  [[ "$status" -eq 0 ]]
  assert_output_contains "Exists:"
}

@test "exists: returns non-zero when manifest inspect fails" {
  export MOCK_DOCKER_MANIFEST_EXISTS=false
  run "$SCRIPT" "ghcr.io/kube-kaptain/quality/quality-strict:1.0.0"
  [[ "$status" -ne 0 ]]
  assert_output_contains "Does not exist at remote"
}

@test "exists: invokes docker manifest inspect with the reference" {
  export MOCK_DOCKER_MANIFEST_EXISTS=true
  run "$SCRIPT" "ghcr.io/kube-kaptain/quality/quality-strict:1.0.0"
  [[ "$status" -eq 0 ]]
  assert_docker_called "manifest inspect ghcr.io/kube-kaptain/quality/quality-strict:1.0.0"
}

# =============================================================================
# Explicit provider prefix
# =============================================================================

@test "exists: docker| prefix routes to docker provider" {
  export MOCK_DOCKER_MANIFEST_EXISTS=true
  run "$SCRIPT" "docker|ghcr.io/kube-kaptain/quality/quality-strict:1.0.0"
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# Unknown provider
# =============================================================================

@test "exists: fails for unknown explicit provider" {
  run "$SCRIPT" "nonexistent|ghcr.io/kube-kaptain/quality/quality-strict:1.0.0"
  [[ "$status" -ne 0 ]]
  assert_output_contains "Unknown artifact-exists provider: nonexistent"
}

# =============================================================================
# Error handling
# =============================================================================

@test "exists: fails with no arguments" {
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
}

@test "exists: docker plugin fails on reference missing version" {
  export MOCK_DOCKER_MANIFEST_EXISTS=true
  run "$SCRIPT" "ghcr.io/kube-kaptain/quality/quality-strict"
  [[ "$status" -ne 0 ]]
  assert_output_contains "missing version"
}

# =============================================================================
# Podman support via IMAGE_BUILD_COMMAND
# =============================================================================

@test "exists: respects IMAGE_BUILD_COMMAND=podman" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_DOCKER_MANIFEST_EXISTS=true
  run "$SCRIPT" "ghcr.io/kube-kaptain/quality/quality-strict:1.0.0"
  [[ "$status" -eq 0 ]]
}
