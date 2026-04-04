#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for util/artifact-fetch
# Covers routing, provider prefix parsing, and pass-through to downloader plugins

load helpers

SCRIPT="$UTIL_DIR/artifact-fetch"

setup() {
  TEST_DIR=$(create_test_dir "artifact-fetch")
  export IMAGE_BUILD_COMMAND="docker"
  export DEST_DIR="${TEST_DIR}/dest"
  mkdir -p "${DEST_DIR}"

  # Mock docker for oci-scratch-extract
  mkdir -p "${MOCK_BIN_DIR}"
  cat > "${MOCK_BIN_DIR}/docker" << 'MOCK'
#!/usr/bin/env bash
echo "$*" >> "${MOCK_DOCKER_CALLS:-/dev/null}"
case "$1" in
  pull) exit 0 ;;
  create) echo "mock-container-id" ;;
  cp)
    src_path="${2#*:}"
    dest="${3}"
    mkdir -p "${dest}"
    touch "${dest}/$(basename "${src_path}")"
    ;;
  rm) exit 0 ;;
  *) exit 0 ;;
esac
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker"
  export MOCK_DOCKER_CALLS="${TEST_DIR}/calls.log"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

teardown() {
  :
}

# =============================================================================
# Default provider routing
# =============================================================================

@test "routes to docker downloader by default" {
  run "$SCRIPT" "ghcr.io/org/quality/quality-strict:1.0" "${DEST_DIR}" /KaptainPM.yaml
  [[ "$status" -eq 0 ]]
}

@test "extracts requested file to dest dir" {
  run "$SCRIPT" "ghcr.io/org/quality/quality-strict:1.0" "${DEST_DIR}" /KaptainPM.yaml
  [[ "$status" -eq 0 ]]
  [[ -f "${DEST_DIR}/KaptainPM.yaml" ]]
}

# =============================================================================
# Explicit provider prefix
# =============================================================================

@test "docker| prefix routes to docker downloader" {
  run "$SCRIPT" "docker|ghcr.io/org/quality/quality-strict:1.0" "${DEST_DIR}" /KaptainPM.yaml
  [[ "$status" -eq 0 ]]
  [[ -f "${DEST_DIR}/KaptainPM.yaml" ]]
}

@test "docker| prefix strips prefix before passing to plugin" {
  run "$SCRIPT" "docker|ghcr.io/org/quality/quality-strict:1.0" "${DEST_DIR}" /KaptainPM.yaml
  [[ "$status" -eq 0 ]]
  # Docker mock should have been called with the URI, not with docker| prefix
  grep -q "ghcr.io/org/quality/quality-strict:1.0" "${MOCK_DOCKER_CALLS}"
  ! grep -q "docker|" "${MOCK_DOCKER_CALLS}"
}

# =============================================================================
# Unknown provider
# =============================================================================

@test "fails for unknown provider" {
  run "$SCRIPT" "nonexistent|some-ref:1.0" "${DEST_DIR}" /file.yaml
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Unknown artifact downloader: nonexistent"* ]]
}

# =============================================================================
# Error handling
# =============================================================================

@test "fails with no arguments" {
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
}

@test "fails with only reference argument" {
  run "$SCRIPT" "ghcr.io/org/quality/quality-strict:1.0"
  [[ "$status" -ne 0 ]]
}

# =============================================================================
# Multiple paths
# =============================================================================

@test "passes multiple paths through to downloader" {
  run "$SCRIPT" "ghcr.io/org/img:1.0" "${DEST_DIR}" /KaptainPM.yaml /extra/config.yaml
  [[ "$status" -eq 0 ]]
  [[ -f "${DEST_DIR}/KaptainPM.yaml" ]]
}

# =============================================================================
# Creates dest dir
# =============================================================================

@test "creates dest dir if it does not exist" {
  local new_dest="${TEST_DIR}/does/not/exist"
  run "$SCRIPT" "ghcr.io/org/img:1.0" "${new_dest}" /KaptainPM.yaml
  [[ "$status" -eq 0 ]]
  [[ -d "${new_dest}" ]]
}
