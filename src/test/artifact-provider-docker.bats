#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for plugins/artifact-providers/docker
# Covers reference parsing, short/prefixed/full form expansion, prefix validation,
# and version range resolution via mocked tag listing

load helpers

PROVIDER="$PLUGINS_DIR/artifact-providers/docker"

setup() {
  TEST_DIR=$(create_test_dir "artifact-provider-docker")
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"
  export IMAGE_BUILD_COMMAND="docker"

  # Mock docker for tag listing
  mkdir -p "${MOCK_BIN_DIR}"
  cat > "${MOCK_BIN_DIR}/docker" << 'MOCK'
#!/usr/bin/env bash
case "$1" in
  image)
    case "$2" in
      ls)
        # Return mock tags based on the image name
        image_ref="${4:-}"
        if [[ -n "${MOCK_TAGS:-}" ]]; then
          echo "${MOCK_TAGS}" | tr ' ' '\n'
        fi
        ;;
    esac
    ;;
esac
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

teardown() {
  :
}

# =============================================================================
# Short form - exact version
# =============================================================================

@test "short form: quality-strict:1.0 expands correctly" {
  run "$PROVIDER" "quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

@test "short form: java-web-service:2.1 extracts prefix java" {
  run "$PROVIDER" "java-web-service:2.1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/java/java-web-service:2.1" ]]
}

@test "short form: ha-deployment:3.0 extracts prefix ha" {
  run "$PROVIDER" "ha-deployment:3.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/ha/ha-deployment:3.0" ]]
}

@test "short form: docker-java-layer:1.0 extracts prefix docker" {
  run "$PROVIDER" "docker-java-layer:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/docker/docker-java-layer:1.0" ]]
}

@test "short form: multi-part version" {
  run "$PROVIDER" "quality-strict:1.2.3"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:1.2.3" ]]
}

# =============================================================================
# Prefixed form - exact version
# =============================================================================

@test "prefixed form: java/java-web-service:2.1 expands correctly" {
  run "$PROVIDER" "java/java-web-service:2.1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/java/java-web-service:2.1" ]]
}

@test "prefixed form: quality/quality-strict:1.0 expands correctly" {
  run "$PROVIDER" "quality/quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

@test "prefixed form: ha/ha-deployment:3.0 expands correctly" {
  run "$PROVIDER" "ha/ha-deployment:3.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/ha/ha-deployment:3.0" ]]
}

# =============================================================================
# Full form - exact version
# =============================================================================

@test "full form: with dot in first segment passes through" {
  run "$PROVIDER" "docker.io/account/something/something-useful:2.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "docker.io/account/something/something-useful:2.0" ]]
}

@test "full form: ghcr.io full reference passes through" {
  run "$PROVIDER" "ghcr.io/other-org/quality/quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/other-org/quality/quality-strict:1.0" ]]
}

@test "full form: private registry passes through" {
  run "$PROVIDER" "privateregistry.com/prefix/prefix-middle-suffix:1.4"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "privateregistry.com/prefix/prefix-middle-suffix:1.4" ]]
}

@test "full form: artifactory with namespace passes through" {
  run "$PROVIDER" "artifactory.example.com/some-namespace/ha/ha-deployment:3.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "artifactory.example.com/some-namespace/ha/ha-deployment:3.0" ]]
}

# =============================================================================
# Full form does not need registry/namespace env vars
# =============================================================================

@test "full form: works without DOCKER_TARGET_REGISTRY set" {
  unset DOCKER_TARGET_REGISTRY
  run "$PROVIDER" "ghcr.io/kube-kaptain/quality/quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

@test "full form: works without DOCKER_TARGET_NAMESPACE set" {
  unset DOCKER_TARGET_NAMESPACE
  run "$PROVIDER" "ghcr.io/kube-kaptain/quality/quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

# =============================================================================
# Prefix validation
# =============================================================================

@test "prefixed form: fails when prefix does not match name" {
  run "$PROVIDER" "wrong/quality-strict:1.0"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Prefix mismatch"* ]]
}

@test "full form: fails when prefix does not match name" {
  run "$PROVIDER" "docker.io/account/wrong/quality-strict:1.0"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Prefix mismatch"* ]]
}

@test "prefixed form: java prefix must match java-* name" {
  run "$PROVIDER" "java/quality-strict:1.0"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Prefix mismatch"* ]]
}

# =============================================================================
# Missing required env vars
# =============================================================================

@test "short form: fails without DOCKER_TARGET_REGISTRY" {
  unset DOCKER_TARGET_REGISTRY
  run "$PROVIDER" "quality-strict:1.0"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"DOCKER_TARGET_REGISTRY"* ]]
}

@test "short form: fails without DOCKER_TARGET_NAMESPACE" {
  unset DOCKER_TARGET_NAMESPACE
  run "$PROVIDER" "quality-strict:1.0"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"DOCKER_TARGET_NAMESPACE"* ]]
}

@test "prefixed form: fails without DOCKER_TARGET_REGISTRY" {
  unset DOCKER_TARGET_REGISTRY
  run "$PROVIDER" "java/java-web-service:2.1"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"DOCKER_TARGET_REGISTRY"* ]]
}

@test "prefixed form: fails without DOCKER_TARGET_NAMESPACE" {
  unset DOCKER_TARGET_NAMESPACE
  run "$PROVIDER" "java/java-web-service:2.1"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"DOCKER_TARGET_NAMESPACE"* ]]
}

# =============================================================================
# Invalid references
# =============================================================================

@test "fails when no version (no colon)" {
  run "$PROVIDER" "quality-strict"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"missing version"* ]]
}

@test "fails when empty version after colon" {
  run "$PROVIDER" "quality-strict:"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"empty version"* ]]
}

@test "fails when no arguments" {
  run "$PROVIDER"
  [[ "$status" -ne 0 ]]
}

# =============================================================================
# Version range resolution
# =============================================================================

@test "range: resolves [1.0,2.0) against available tags" {
  # Mock skopeo for tag listing
  cat > "${MOCK_BIN_DIR}/skopeo" << 'SKOPEO'
#!/usr/bin/env bash
echo '{"Tags": ["1.0", "1.1", "1.5", "1.9", "2.0", "3.0"]}'
SKOPEO
  chmod +x "${MOCK_BIN_DIR}/skopeo"
  export MOCK_TAGS=""

  run "$PROVIDER" "quality-strict:[1.0,2.0)"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:1.9" ]]
}

@test "range: resolves [1.0,) against available tags (open upper bound)" {
  cat > "${MOCK_BIN_DIR}/skopeo" << 'SKOPEO'
#!/usr/bin/env bash
echo '{"Tags": ["1.0", "1.5", "2.0", "3.5"]}'
SKOPEO
  chmod +x "${MOCK_BIN_DIR}/skopeo"
  export MOCK_TAGS=""

  run "$PROVIDER" "quality-strict:[1.0,)"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ghcr.io/kube-kaptain/quality/quality-strict:3.5" ]]
}

@test "range: fails when no versions match" {
  cat > "${MOCK_BIN_DIR}/skopeo" << 'SKOPEO'
#!/usr/bin/env bash
echo '{"Tags": ["3.0", "4.0"]}'
SKOPEO
  chmod +x "${MOCK_BIN_DIR}/skopeo"
  export MOCK_TAGS=""

  run "$PROVIDER" "quality-strict:[1.0,2.0)"
  [[ "$status" -eq 1 ]]
}

@test "range: fails when no tags available" {
  # No skopeo, no local tags
  rm -f "${MOCK_BIN_DIR}/skopeo"
  export MOCK_TAGS=""

  run "$PROVIDER" "quality-strict:[1.0,2.0)"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unable to list tags"* ]]
}

# =============================================================================
# Different registry/namespace values
# =============================================================================

@test "short form: uses custom registry and namespace" {
  export DOCKER_TARGET_REGISTRY="docker.io"
  export DOCKER_TARGET_NAMESPACE="myorg"
  run "$PROVIDER" "quality-strict:1.0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "docker.io/myorg/quality/quality-strict:1.0" ]]
}

@test "prefixed form: uses custom registry and namespace" {
  export DOCKER_TARGET_REGISTRY="artifactory.corp.com"
  export DOCKER_TARGET_NAMESPACE="team-platform"
  run "$PROVIDER" "java/java-web-service:2.1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "artifactory.corp.com/team-platform/java/java-web-service:2.1" ]]
}
