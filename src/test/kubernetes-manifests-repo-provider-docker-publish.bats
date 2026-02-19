#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-docker-publish
# This script is now a no-op - actual push handled by docker-push-all.
# Kept for repo provider plugin interface compatibility.

load helpers

setup() {
  setup_mock_docker
  export GITHUB_OUTPUT=$(create_test_dir "k8s-repo-docker-pub")/output
}

teardown() {
  :
}

@test "outputs pushed by docker-push-all message" {
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"
  export IS_RELEASE="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-publish"
  [ "$status" -eq 0 ]
  assert_output_contains "docker-push-all"
}

@test "does not push regardless of IS_RELEASE" {
  export MANIFESTS_URI="ghcr.io/test/my-repo:1.0.0-manifests"
  export IS_RELEASE="true"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-publish"
  [ "$status" -eq 0 ]
  assert_docker_not_called "push"
}
