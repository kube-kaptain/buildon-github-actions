#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test zip file
  export TEST_ZIP=$(mktemp)
  echo "test content" > "$TEST_ZIP"
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
  rm -f "$TEST_ZIP"
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

# Required env vars for most tests
set_required_env() {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="my-project-1.0.0-manifests.zip"
  export VERSION="1.0.0"
  export GITHUB_TOKEN="test-token"
}

@test "skips upload when IS_RELEASE=false" {
  set_required_env
  export IS_RELEASE="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
  assert_gh_not_called "upload"
}

@test "uploads when IS_RELEASE=true" {
  set_required_env
  export IS_RELEASE="true"
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_called "release upload 1.0.0"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "creates release if not exists" {
  set_required_env
  export IS_RELEASE="true"
  export MOCK_RELEASE_EXISTS="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_called "release create 1.0.0"
  assert_gh_called "release upload 1.0.0"
}

@test "uses existing release if exists" {
  set_required_env
  export IS_RELEASE="true"
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_not_called "release create"
  assert_gh_called "release upload"
}

@test "fails when MANIFESTS_ZIP_PATH missing" {
  export MANIFESTS_ZIP_NAME="my-project-1.0.0-manifests.zip"
  export VERSION="1.0.0"
  unset MANIFESTS_ZIP_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ZIP_PATH"
}

@test "fails when zip file not found" {
  set_required_env
  export IS_RELEASE="true"
  export MANIFESTS_ZIP_PATH="/nonexistent/file.zip"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "Manifests zip not found"
}

@test "fails when GITHUB_TOKEN missing and IS_RELEASE=true" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="my-project-1.0.0-manifests.zip"
  export VERSION="1.0.0"
  export IS_RELEASE="true"
  unset GITHUB_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "GITHUB_TOKEN"
}

@test "does not require GITHUB_TOKEN when IS_RELEASE=false" {
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="my-project-1.0.0-manifests.zip"
  export VERSION="1.0.0"
  export IS_RELEASE="false"
  unset GITHUB_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "defaults IS_RELEASE to false" {
  set_required_env
  unset IS_RELEASE

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "uses clobber flag on upload" {
  set_required_env
  export IS_RELEASE="true"
  export MOCK_RELEASE_EXISTS="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-github-release-publish"
  [ "$status" -eq 0 ]
  assert_gh_called "--clobber"
}
