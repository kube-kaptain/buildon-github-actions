#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for the kubernetes-manifests-repo-provider-publish selector script

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(mktemp)
  export TEST_ZIP=$(mktemp)
  echo "test content" > "$TEST_ZIP"
  # Set up mock gh CLI
  export MOCK_GH_CALLS=$(mktemp)
  mkdir -p "$MOCK_BIN_DIR"
  cat > "$MOCK_BIN_DIR/gh" << 'MOCKGH'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_GH_CALLS"
if [[ "$1" == "release" && "$2" == "view" ]]; then
  if [[ "$4" == "--json" ]]; then
    echo "https://github.com/test/repo/releases/tag/1.0.0"
  fi
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
  cleanup_mock_docker
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_ZIP"
  rm -f "$MOCK_GH_CALLS"
}

@test "fails when MANIFESTS_REPO_PROVIDER_TYPE not set" {
  unset MANIFESTS_REPO_PROVIDER_TYPE

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_REPO_PROVIDER_TYPE is required"
  assert_output_contains "Available:"
}

@test "fails when MANIFESTS_REPO_PROVIDER_TYPE is unknown" {
  export MANIFESTS_REPO_PROVIDER_TYPE="nonexistent"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown repo provider type: nonexistent"
  assert_output_contains "Available:"
}

@test "dispatches to docker repo provider" {
  export MANIFESTS_REPO_PROVIDER_TYPE="docker"
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: docker"
  assert_output_contains "Kubernetes Manifests Repo Provider Publish: Docker"
}

@test "dispatches to github-release repo provider" {
  export MANIFESTS_REPO_PROVIDER_TYPE="github-release"
  export MANIFESTS_ZIP_PATH="$TEST_ZIP"
  export MANIFESTS_ZIP_NAME="test-1.0.0-manifests.zip"
  export VERSION="1.0.0"
  export GITHUB_TOKEN="test-token"

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -eq 0 ]
  assert_output_contains "Selected repo provider: github-release"
  assert_output_contains "Kubernetes Manifests Repo Provider Publish: GitHub Release"
}

@test "lists available repo providers on error" {
  unset MANIFESTS_REPO_PROVIDER_TYPE

  run "$SCRIPTS_DIR/kubernetes-manifests-repo-provider-publish"
  [ "$status" -ne 0 ]
  # Should list the available repo providers
  assert_output_contains "docker"
  assert_output_contains "github-release"
}
