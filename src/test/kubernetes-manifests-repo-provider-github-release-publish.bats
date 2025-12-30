#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-github-release-publish
# This script uploads a zip to a GitHub release. The if: condition
# on the step skips this entirely on non-release branches.

load helpers

setup() {
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip in a directory
  export TEST_ZIP_DIR=$(mktemp -d)
  export TEST_ZIP_NAME="my-project-1.0.0-manifests.zip"
  echo "test content" > "$TEST_ZIP_DIR/$TEST_ZIP_NAME"
  # Set up mock gh CLI
  export MOCK_GH_CALLS=$(mktemp)
  mkdir -p "$MOCK_BIN_DIR"
  cat > "$MOCK_BIN_DIR/gh" << 'MOCKGH'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_GH_CALLS"
if [[ "$1" == "release" && "$2" == "view" ]]; then
  # Check if we already created a release (file marker)
  if [[ "${MOCK_RELEASE_EXISTS:-false}" == "true" ]] || [[ -f "$MOCK_GH_CALLS.created" ]]; then
    if [[ "$4" == "--json" ]]; then
      echo "https://github.com/test/repo/releases/tag/1.0.0"
    fi
    exit 0
  else
    exit 1
  fi
fi
if [[ "$1" == "release" && "$2" == "create" ]]; then
  # Mark that release was created
  touch "$MOCK_GH_CALLS.created"
  exit 0
fi
if [[ "$1" == "release" && "$2" == "upload" ]]; then
  exit 0
fi
exit 0
MOCKGH
  chmod +x "$MOCK_BIN_DIR/gh"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  rm -f "$GITHUB_OUTPUT"
  rm -rf "$TEST_ZIP_DIR"
  rm -f "$MOCK_GH_CALLS"
  rm -f "$MOCK_GH_CALLS.created"
  rm -f "$MOCK_BIN_DIR/gh"
}

# Assert gh was called with specific args
assert_gh_called() {
  local expected="$1"
  # Use -- to prevent patterns starting with - from being interpreted as grep options
  if ! grep -q -- "$expected" "$MOCK_GH_CALLS" 2>/dev/null; then
    echo "Expected gh to be called with: $expected"
    echo "Actual calls:"
    cat "$MOCK_GH_CALLS" 2>/dev/null || echo "(none)"
    return 1
  fi
}

# Assert gh was NOT called with specific args
assert_gh_not_called() {
  local unexpected="$1"
  if grep -q "$unexpected" "$MOCK_GH_CALLS" 2>/dev/null; then
    echo "Expected gh NOT to be called with: $unexpected"
    echo "Actual calls:"
    cat "$MOCK_GH_CALLS"
    return 1
  fi
}

# Required env vars for most tests (using REPO_PROVIDER_* API)
set_required_env() {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_VERSION="1.0.0"
  export REPO_PROVIDER_AUTH_TOKEN="test-token"
  export IS_RELEASE="true"
}

@test "uploads when all required vars set" {
  set_required_env
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_called "release upload 1.0.0"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "creates release if not exists" {
  set_required_env
  export MOCK_RELEASE_EXISTS="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_called "release create 1.0.0"
  assert_gh_called "release upload 1.0.0"
}

@test "uses existing release if exists" {
  set_required_env
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_not_called "release create"
  assert_gh_called "release upload"
}

@test "fails when MANIFESTS_ZIP_SUB_PATH missing" {
  export MANIFESTS_ZIP_FILE_NAME="my-project-1.0.0-manifests.zip"
  export REPO_PROVIDER_VERSION="1.0.0"
  unset MANIFESTS_ZIP_SUB_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_SUB_PATH"
}

@test "fails when MANIFESTS_ZIP_FILE_NAME missing" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export REPO_PROVIDER_VERSION="1.0.0"
  unset MANIFESTS_ZIP_FILE_NAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_FILE_NAME"
}

@test "fails when REPO_PROVIDER_VERSION missing" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  unset REPO_PROVIDER_VERSION

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "REPO_PROVIDER_VERSION"
}

@test "fails when zip file not found" {
  set_required_env
  export MANIFESTS_ZIP_SUB_PATH="/nonexistent"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}

@test "fails when REPO_PROVIDER_AUTH_TOKEN missing and GITHUB_TOKEN not pre-configured" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_VERSION="1.0.0"
  export IS_RELEASE="true"
  unset REPO_PROVIDER_AUTH_TOKEN
  unset GITHUB_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "REPO_PROVIDER_AUTH_TOKEN"
}

@test "works with pre-configured GITHUB_TOKEN (no REPO_PROVIDER_AUTH_TOKEN needed)" {
  export MANIFESTS_ZIP_SUB_PATH="$TEST_ZIP_DIR"
  export MANIFESTS_ZIP_FILE_NAME="$TEST_ZIP_NAME"
  export REPO_PROVIDER_VERSION="1.0.0"
  export IS_RELEASE="true"
  export GITHUB_TOKEN="pre-configured-token"
  export MOCK_RELEASE_EXISTS="true"
  unset REPO_PROVIDER_AUTH_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_called "release upload"
}

@test "uses clobber flag on upload" {
  set_required_env
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_called "--clobber"
}

@test "outputs MANIFESTS_URI with release URL" {
  set_required_env
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
  # The mock returns a URL, check it's in the output
  assert_output_contains "https://github.com/test/repo/releases/tag/1.0.0"
}

@test "skips upload when IS_RELEASE=false" {
  set_required_env
  export IS_RELEASE="false"
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_not_called "release upload"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "defaults IS_RELEASE to false" {
  set_required_env
  unset IS_RELEASE
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_not_called "release upload"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}
