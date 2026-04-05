#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for plugins/artifact-providers/docker
# Covers reference parsing, short/prefixed/full form expansion, prefix validation,
# version range resolution, tag listing (local + remote), auth flows, and IS_RELEASE filtering

load helpers

PROVIDER="$PLUGINS_DIR/artifact-providers/docker"

setup() {
  TEST_DIR=$(create_test_dir "artifact-provider-docker")
  OUTPUT_FILE="${TEST_DIR}/resolved"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"
  export IMAGE_BUILD_COMMAND="podman"

  # Mock bin directory - prepend to PATH so mocks override real commands
  mkdir -p "${MOCK_BIN_DIR}"

  # Mock podman - returns local tags from MOCK_LOCAL_TAGS env var
  cat > "${MOCK_BIN_DIR}/podman" << 'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "image" && "$2" == "ls" ]]; then
  echo "${MOCK_LOCAL_TAGS:-}"
fi
MOCK
  chmod +x "${MOCK_BIN_DIR}/podman"

  # Mock curl - handles /v2/ challenge, token endpoint, and tags/list
  cat > "${MOCK_BIN_DIR}/curl" << 'MOCK'
#!/usr/bin/env bash
url=""
for arg in "$@"; do
  case "${arg}" in
    -*)  ;;
    *)   url="${arg}" ;;
  esac
done
if [[ "${url}" == */v2/ ]]; then
  if [[ "$*" == *"-D"* ]]; then
    echo 'HTTP/1.1 401 Unauthorized'
    echo 'www-authenticate: Bearer realm="https://mock-registry.example/token",service="mock-registry"'
    echo ''
  fi
  exit 0
fi
if [[ "${url}" == *"/token?"* ]]; then
  echo '{"token":"mock-anon-token"}'
  exit 0
fi
if [[ "${url}" == */tags/list ]]; then
  echo "${MOCK_REMOTE_TAGS_JSON:-{"tags":[]}}"
  exit 0
fi
MOCK
  chmod +x "${MOCK_BIN_DIR}/curl"

  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export MOCK_LOCAL_TAGS=""
  export MOCK_REMOTE_TAGS_JSON='{"tags":[]}'
}

teardown() {
  :
}

# =============================================================================
# Short form - exact version
# =============================================================================

@test "short form: quality-strict:1.0 expands correctly" {
  run "$PROVIDER" "quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

@test "short form: java-web-service:2.1 extracts prefix java" {
  run "$PROVIDER" "java-web-service:2.1" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/java/java-web-service:2.1" ]]
}

@test "short form: ha-deployment:3.0 extracts prefix ha" {
  run "$PROVIDER" "ha-deployment:3.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/ha/ha-deployment:3.0" ]]
}

@test "short form: docker-java-layer:1.0 extracts prefix docker" {
  run "$PROVIDER" "docker-java-layer:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/docker/docker-java-layer:1.0" ]]
}

@test "short form: multi-part version" {
  run "$PROVIDER" "quality-strict:1.2.3" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.2.3" ]]
}

# =============================================================================
# Prefixed form - exact version
# =============================================================================

@test "prefixed form: java/java-web-service:2.1 expands correctly" {
  run "$PROVIDER" "java/java-web-service:2.1" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/java/java-web-service:2.1" ]]
}

@test "prefixed form: quality/quality-strict:1.0 expands correctly" {
  run "$PROVIDER" "quality/quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

@test "prefixed form: ha/ha-deployment:3.0 expands correctly" {
  run "$PROVIDER" "ha/ha-deployment:3.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/ha/ha-deployment:3.0" ]]
}

# =============================================================================
# Full form - exact version
# =============================================================================

@test "full form: with dot in first segment passes through" {
  run "$PROVIDER" "docker.io/account/something/something-useful:2.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "docker.io/account/something/something-useful:2.0" ]]
}

@test "full form: ghcr.io full reference passes through" {
  run "$PROVIDER" "ghcr.io/other-org/quality/quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/other-org/quality/quality-strict:1.0" ]]
}

@test "full form: private registry passes through" {
  run "$PROVIDER" "privateregistry.com/prefix/prefix-middle-suffix:1.4" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "privateregistry.com/prefix/prefix-middle-suffix:1.4" ]]
}

@test "full form: artifactory with namespace passes through" {
  run "$PROVIDER" "artifactory.example.com/some-namespace/ha/ha-deployment:3.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "artifactory.example.com/some-namespace/ha/ha-deployment:3.0" ]]
}

# =============================================================================
# Full form does not need registry/namespace env vars
# =============================================================================

@test "full form: works without DOCKER_TARGET_REGISTRY set" {
  unset DOCKER_TARGET_REGISTRY
  run "$PROVIDER" "ghcr.io/kube-kaptain/quality/quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

@test "full form: works without DOCKER_TARGET_NAMESPACE set" {
  unset DOCKER_TARGET_NAMESPACE
  run "$PROVIDER" "ghcr.io/kube-kaptain/quality/quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.0" ]]
}

# =============================================================================
# Prefix validation
# =============================================================================

@test "prefixed form: fails when prefix does not match name" {
  run "$PROVIDER" "wrong/quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "Prefix mismatch"
}

@test "full form: fails when prefix does not match name" {
  run "$PROVIDER" "docker.io/account/wrong/quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "Prefix mismatch"
}

@test "prefixed form: java prefix must match java-* name" {
  run "$PROVIDER" "java/quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "Prefix mismatch"
}

# =============================================================================
# Missing required env vars
# =============================================================================

@test "short form: fails without DOCKER_TARGET_REGISTRY" {
  unset DOCKER_TARGET_REGISTRY
  run "$PROVIDER" "quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "DOCKER_TARGET_REGISTRY"
}

@test "short form: fails without DOCKER_TARGET_NAMESPACE" {
  unset DOCKER_TARGET_NAMESPACE
  run "$PROVIDER" "quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "DOCKER_TARGET_NAMESPACE"
}

@test "prefixed form: fails without DOCKER_TARGET_REGISTRY" {
  unset DOCKER_TARGET_REGISTRY
  run "$PROVIDER" "java/java-web-service:2.1" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "DOCKER_TARGET_REGISTRY"
}

@test "prefixed form: fails without DOCKER_TARGET_NAMESPACE" {
  unset DOCKER_TARGET_NAMESPACE
  run "$PROVIDER" "java/java-web-service:2.1" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "DOCKER_TARGET_NAMESPACE"
}

# =============================================================================
# Invalid references
# =============================================================================

@test "fails when no version (no colon)" {
  run "$PROVIDER" "quality-strict" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "missing version"
}

@test "fails when empty version after colon" {
  run "$PROVIDER" "quality-strict:" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "empty version"
}

@test "fails when no arguments" {
  run "$PROVIDER"
  [[ "$status" -ne 0 ]]
}

# =============================================================================
# Version range - local tags only
# =============================================================================

@test "range: resolves from local tags" {
  export MOCK_LOCAL_TAGS=$'1.0\n1.1\n1.2'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.2" ]]
}

@test "range: requires IMAGE_BUILD_COMMAND" {
  unset IMAGE_BUILD_COMMAND
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "IMAGE_BUILD_COMMAND is required"
}

# =============================================================================
# Version range - remote tags via skopeo
# =============================================================================

@test "range: uses skopeo when available" {
  cat > "${MOCK_BIN_DIR}/skopeo" << 'MOCK'
#!/usr/bin/env bash
echo '{"Tags":["1.0","1.3","2.0"]}'
MOCK
  chmod +x "${MOCK_BIN_DIR}/skopeo"

  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.3" ]]
}

@test "range: falls back to curl when skopeo fails" {
  cat > "${MOCK_BIN_DIR}/skopeo" << 'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
  chmod +x "${MOCK_BIN_DIR}/skopeo"

  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.4"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.4" ]]
}

# =============================================================================
# Version range - remote tags via curl (anonymous token exchange)
# =============================================================================

@test "range: fetches remote tags via anonymous token" {
  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.1","1.5"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.5" ]]
}

@test "range: combines local and remote tags" {
  export MOCK_LOCAL_TAGS=$'1.0\n1.1-PRERELEASE'
  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.1"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.1" ]]
}

@test "range: deduplicates tags across local and remote" {
  export MOCK_LOCAL_TAGS=$'1.0\n1.1'
  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.1","1.2"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.2" ]]
}

@test "range: fails when no tags found anywhere" {
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "Unable to anonymously list tags"
}

@test "range: fails when no versions match range" {
  export MOCK_REMOTE_TAGS_JSON='{"tags":["3.0","4.0"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "No version matching range"
}

# =============================================================================
# Auth - direct credentials from docker config
# =============================================================================

@test "auth: uses direct credentials from docker config" {
  export DOCKER_CONFIG="${TEST_DIR}/docker-config"
  mkdir -p "${DOCKER_CONFIG}"
  cat > "${DOCKER_CONFIG}/config.json" << 'JSON'
{"auths":{"ghcr.io":{"auth":"dXNlcjpwYXNz"}}}
JSON

  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.1"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.1" ]]
}

# =============================================================================
# Auth - per-registry credential helper (credHelpers)
# =============================================================================

@test "auth: uses per-registry credential helper" {
  export DOCKER_CONFIG="${TEST_DIR}/docker-config"
  mkdir -p "${DOCKER_CONFIG}"
  cat > "${DOCKER_CONFIG}/config.json" << 'JSON'
{"credHelpers":{"ghcr.io":"mock-helper"}}
JSON

  cat > "${MOCK_BIN_DIR}/docker-credential-mock-helper" << 'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "get" ]]; then
  registry=$(cat)
  if [[ "${registry}" == "ghcr.io" ]]; then
    echo '{"Username":"helper-user","Secret":"helper-pass"}'
  fi
fi
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker-credential-mock-helper"

  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.2"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.2" ]]
}

# =============================================================================
# Auth - default credential store (credsStore)
# =============================================================================

@test "auth: uses default credential store" {
  export DOCKER_CONFIG="${TEST_DIR}/docker-config"
  mkdir -p "${DOCKER_CONFIG}"
  cat > "${DOCKER_CONFIG}/config.json" << 'JSON'
{"credsStore":"mock-store"}
JSON

  cat > "${MOCK_BIN_DIR}/docker-credential-mock-store" << 'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "get" ]]; then
  registry=$(cat)
  if [[ "${registry}" == "ghcr.io" ]]; then
    echo '{"Username":"store-user","Secret":"store-pass"}'
  fi
fi
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker-credential-mock-store"

  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.3"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.3" ]]
}

# =============================================================================
# Auth - priority: direct > credHelper > credsStore > anonymous
# =============================================================================

@test "auth: direct auth takes priority over credHelper" {
  export DOCKER_CONFIG="${TEST_DIR}/docker-config"
  mkdir -p "${DOCKER_CONFIG}"
  cat > "${DOCKER_CONFIG}/config.json" << 'JSON'
{"auths":{"ghcr.io":{"auth":"dXNlcjpwYXNz"}},"credHelpers":{"ghcr.io":"mock-helper"}}
JSON

  # Credential helper that would fail the test if called
  cat > "${MOCK_BIN_DIR}/docker-credential-mock-helper" << 'MOCK'
#!/usr/bin/env bash
echo "SHOULD NOT BE CALLED" >&2
exit 1
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker-credential-mock-helper"

  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.1"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
}

@test "auth: falls back to anonymous with no config" {
  export DOCKER_CONFIG="${TEST_DIR}/empty-docker-config"
  mkdir -p "${DOCKER_CONFIG}"

  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.5"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.5" ]]
}

@test "auth: credential helper only returns creds for matching registry" {
  export DOCKER_CONFIG="${TEST_DIR}/docker-config"
  mkdir -p "${DOCKER_CONFIG}"
  cat > "${DOCKER_CONFIG}/config.json" << 'JSON'
{"credHelpers":{"other-registry.io":"mock-helper"}}
JSON

  # Helper that only responds to other-registry.io
  cat > "${MOCK_BIN_DIR}/docker-credential-mock-helper" << 'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "get" ]]; then
  registry=$(cat)
  if [[ "${registry}" == "other-registry.io" ]]; then
    echo '{"Username":"user","Secret":"pass"}'
  else
    echo "credentials not found" >&2
    exit 1
  fi
fi
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker-credential-mock-helper"

  # Should fall through to anonymous since no credHelper for ghcr.io
  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.0","1.1"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.1" ]]
}

# =============================================================================
# IS_RELEASE filtering
# =============================================================================

@test "IS_RELEASE=true excludes suffixed versions" {
  export IS_RELEASE="true"
  export MOCK_LOCAL_TAGS=$'1.0\n1.1-PRERELEASE\n1.1\n1.2-PRERELEASE'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.1" ]]
}

@test "IS_RELEASE=true fails when only suffixed versions available" {
  export IS_RELEASE="true"
  export MOCK_LOCAL_TAGS=$'1.1-PRERELEASE\n1.2-PRERELEASE'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 1 ]]
  assert_output_contains "No release versions available"
}

@test "IS_RELEASE=false includes suffixed versions" {
  export IS_RELEASE="false"
  export MOCK_LOCAL_TAGS=$'1.1-PRERELEASE\n1.2-PRERELEASE'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.2-PRERELEASE" ]]
}

# =============================================================================
# Suffix sorting - deterministic ordering
# =============================================================================

@test "prefers shorter suffix when all same numeric version" {
  export MOCK_LOCAL_TAGS=$'1.1-PRERELEASE-linux-arm64\n1.1-PRERELEASE\n1.1-PRERELEASE-linux-amd64'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.1-PRERELEASE" ]]
}

@test "unsuffixed wins over suffixed at same numeric" {
  export MOCK_LOCAL_TAGS=$'1.1-PRERELEASE\n1.1'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.1" ]]
}

@test "release from remote wins over local prerelease at same numeric" {
  export MOCK_LOCAL_TAGS=$'1.1-PRERELEASE\n1.1-PRERELEASE-linux-arm64'
  export MOCK_REMOTE_TAGS_JSON='{"tags":["1.1","1.1-linux-arm64"]}'
  run "$PROVIDER" "quality-strict:[1.0,2.0)" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "ghcr.io/kube-kaptain/quality/quality-strict:1.1" ]]
}

# =============================================================================
# Different registry/namespace values
# =============================================================================

@test "short form: uses custom registry and namespace" {
  export DOCKER_TARGET_REGISTRY="docker.io"
  export DOCKER_TARGET_NAMESPACE="myorg"
  run "$PROVIDER" "quality-strict:1.0" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "docker.io/myorg/quality/quality-strict:1.0" ]]
}

@test "prefixed form: uses custom registry and namespace" {
  export DOCKER_TARGET_REGISTRY="artifactory.corp.com"
  export DOCKER_TARGET_NAMESPACE="team-platform"
  run "$PROVIDER" "java/java-web-service:2.1" "${OUTPUT_FILE}"
  [[ "$status" -eq 0 ]]
  [[ "$(cat "${OUTPUT_FILE}")" == "artifactory.corp.com/team-platform/java/java-web-service:2.1" ]]
}
