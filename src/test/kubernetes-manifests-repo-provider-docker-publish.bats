#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-docker-publish
# This script ONLY pushes a pre-built image - it does not build.

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(mktemp)
}

teardown() {
  cleanup_mock_docker
  rm -f "$GITHUB_OUTPUT"
}

@test "pushes image when IS_RELEASE=true" {
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"
  export IS_RELEASE="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-publish"
  [ "$status" -eq 0 ]
  assert_docker_called "push ghcr.io/test/my-repo:1.0.0-manifests"
  assert_var_equals "MANIFESTS_URI" "ghcr.io/test/my-repo:1.0.0-manifests"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "fails when MANIFESTS_URI missing" {
  unset MANIFESTS_URI

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_URI"
}

@test "fails when image not found locally" {
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"
  # Make docker image inspect fail
  echo '#!/bin/bash
if [[ "$1" == "image" && "$2" == "inspect" ]]; then
  exit 1
fi
echo "$*" >> "$MOCK_DOCKER_CALLS"
exit 0' > "$MOCK_BIN_DIR/docker"
  chmod +x "$MOCK_BIN_DIR/docker"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "Image not found locally"
}

@test "outputs correct values on success" {
  export MANIFESTS_URI="ghcr.io/kube-kaptain/my-app:2.0.0-manifests"
  export IS_RELEASE="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "ghcr.io/kube-kaptain/my-app:2.0.0-manifests"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "skips push when IS_RELEASE=false" {
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"
  export IS_RELEASE="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-publish"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "defaults IS_RELEASE to false" {
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"
  unset IS_RELEASE

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-publish"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}
