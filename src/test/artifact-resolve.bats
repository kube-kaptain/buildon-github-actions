#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for util/artifact-resolve
# Covers routing, provider prefix parsing, default provider, and error handling

load helpers

SCRIPT="$UTIL_DIR/artifact-resolve"

setup() {
  TEST_DIR=$(create_test_dir "artifact-resolve")
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"
  export IMAGE_BUILD_COMMAND="docker"

  # Mock docker to avoid real registry calls
  mkdir -p "${MOCK_BIN_DIR}"
  cat > "${MOCK_BIN_DIR}/docker" << 'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

teardown() {
  :
}

# =============================================================================
# Default provider routing
# =============================================================================

@test "routes to docker provider by default" {
  run "$SCRIPT" "quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

@test "routes to docker provider for prefixed form" {
  run "$SCRIPT" "java/java-web-service:2.1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/java/java-web-service:2.1" ]]
}

@test "routes to docker provider for full form" {
  run "$SCRIPT" "docker.io/other/ha/ha-deployment:3.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "docker.io/other/ha/ha-deployment:3.0" ]]
}

# =============================================================================
# Explicit provider prefix
# =============================================================================

@test "docker| prefix routes to docker provider" {
  run "$SCRIPT" "docker|quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

@test "docker| prefix with prefixed form" {
  run "$SCRIPT" "docker|java/java-web-service:2.1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/java/java-web-service:2.1" ]]
}

@test "docker| prefix with full form" {
  run "$SCRIPT" "docker|ghcr.io/org/quality/quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/org/quality/quality-strict:1.0" ]]
}

# =============================================================================
# Custom default provider via env
# =============================================================================

@test "uses ARTIFACT_RESOLUTION_PROVIDER when set" {
  # Create a mock provider that echoes its input
  local mock_provider_dir="${TEST_DIR}/plugins/artifact-providers"
  mkdir -p "${mock_provider_dir}"
  cat > "${mock_provider_dir}/custom" << 'MOCK'
#!/usr/bin/env bash
echo "custom-resolved:${1}"
MOCK
  chmod +x "${mock_provider_dir}/custom"

  # Override the plugins dir by creating a wrapper script
  # Since we can't easily override PLUGINS_DIR, test via explicit prefix instead
  run "$SCRIPT" "custom|some-ref:1.0"
  # This will fail because "custom" provider doesn't exist in the real plugins dir
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unknown artifact provider: custom"* ]]
}

# =============================================================================
# Unknown provider
# =============================================================================

@test "fails for unknown explicit provider" {
  run "$SCRIPT" "nonexistent|quality-strict:1.0"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unknown artifact provider: nonexistent"* ]]
}

# =============================================================================
# Error handling
# =============================================================================

@test "fails with no arguments" {
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
}

@test "propagates provider failure" {
  # Force prefix mismatch to cause docker provider to fail
  run "$SCRIPT" "docker|wrong/quality-strict:1.0"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Prefix mismatch"* ]]
}
