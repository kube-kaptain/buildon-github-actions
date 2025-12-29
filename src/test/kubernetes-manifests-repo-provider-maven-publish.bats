#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-maven-publish
# This script publishes a zip to GitHub Packages Maven registry.

load helpers

setup() {
  setup_mock_mvn
  export GITHUB_OUTPUT=$(mktemp)
  # Create a test artifact
  local temp_base
  temp_base=$(mktemp)
  export TEST_ARTIFACT="${temp_base}.zip"
  rm -f "$temp_base"
  echo "test content" > "$TEST_ARTIFACT"
}

teardown() {
  cleanup_mock_mvn
  rm -f "$GITHUB_OUTPUT"
  rm -f "$TEST_ARTIFACT"
}

# Required env vars for most tests
set_required_env() {
  export MANIFESTS_ARTIFACT_PATH="$TEST_ARTIFACT"
  export MANIFESTS_URI="mvn:io.github.testowner:my-project-manifests:1.0.0:zip"
  export MAVEN_GROUP_ID="io.github.testowner"
  export MAVEN_ARTIFACT_ID="my-project-manifests"
  export VERSION="1.0.0"
  export REGISTRY_REPO="test-owner/my-project"
  export REGISTRY_URL="https://maven.pkg.github.com/test-owner/my-project"
  export AUTH_TOKEN="test-token"
  export AUTH_USERNAME="test-user"
  export IS_RELEASE="true"
}

@test "publishes when IS_RELEASE=true" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -eq 0 ]
  assert_mvn_called "deploy:deploy-file"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "skips publish when IS_RELEASE=false" {
  set_required_env
  export IS_RELEASE="false"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -eq 0 ]
  assert_mvn_not_called "deploy:deploy-file"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "defaults IS_RELEASE to false" {
  set_required_env
  unset IS_RELEASE

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -eq 0 ]
  assert_mvn_not_called "deploy:deploy-file"
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

@test "outputs MANIFESTS_URI" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_URI" "mvn:io.github.testowner:my-project-manifests:1.0.0:zip"
}

@test "passes correct Maven coordinates to deploy:deploy-file" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -eq 0 ]
  assert_mvn_called "-DgroupId=io.github.testowner"
  assert_mvn_called "-DartifactId=my-project-manifests"
  assert_mvn_called "-Dversion=1.0.0"
  assert_mvn_called "-Dpackaging=zip"
}

@test "uses GitHub Packages registry URL" {
  set_required_env

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -eq 0 ]
  assert_mvn_called "maven.pkg.github.com/test-owner/my-project"
}

@test "fails when MANIFESTS_ARTIFACT_PATH missing" {
  export MANIFESTS_URI="mvn:io.github.testowner:my-project-manifests:1.0.0:zip"
  export MAVEN_GROUP_ID="io.github.testowner"
  export MAVEN_ARTIFACT_ID="my-project-manifests"
  export VERSION="1.0.0"
  export REGISTRY_REPO="test-owner/my-project"
  unset MANIFESTS_ARTIFACT_PATH

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_ARTIFACT_PATH"
}

@test "fails when MANIFESTS_URI missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_ARTIFACT"
  export MAVEN_GROUP_ID="io.github.testowner"
  export MAVEN_ARTIFACT_ID="my-project-manifests"
  export VERSION="1.0.0"
  export REGISTRY_REPO="test-owner/my-project"
  unset MANIFESTS_URI

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MANIFESTS_URI"
}

@test "fails when MAVEN_GROUP_ID missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_ARTIFACT"
  export MANIFESTS_URI="mvn:io.github.testowner:my-project-manifests:1.0.0:zip"
  export MAVEN_ARTIFACT_ID="my-project-manifests"
  export VERSION="1.0.0"
  export REGISTRY_REPO="test-owner/my-project"
  unset MAVEN_GROUP_ID

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MAVEN_GROUP_ID"
}

@test "fails when MAVEN_ARTIFACT_ID missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_ARTIFACT"
  export MANIFESTS_URI="mvn:io.github.testowner:my-project-manifests:1.0.0:zip"
  export MAVEN_GROUP_ID="io.github.testowner"
  export VERSION="1.0.0"
  export REGISTRY_REPO="test-owner/my-project"
  unset MAVEN_ARTIFACT_ID

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "MAVEN_ARTIFACT_ID"
}

@test "fails when VERSION missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_ARTIFACT"
  export MANIFESTS_URI="mvn:io.github.testowner:my-project-manifests:1.0.0:zip"
  export MAVEN_GROUP_ID="io.github.testowner"
  export MAVEN_ARTIFACT_ID="my-project-manifests"
  export REGISTRY_REPO="test-owner/my-project"
  unset VERSION

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "fails when REGISTRY_REPO missing" {
  export MANIFESTS_ARTIFACT_PATH="$TEST_ARTIFACT"
  export MANIFESTS_URI="mvn:io.github.testowner:my-project-manifests:1.0.0:zip"
  export MAVEN_GROUP_ID="io.github.testowner"
  export MAVEN_ARTIFACT_ID="my-project-manifests"
  export VERSION="1.0.0"
  unset REGISTRY_REPO

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "REGISTRY_REPO"
}

@test "fails when artifact not found" {
  set_required_env
  export MANIFESTS_ARTIFACT_PATH="/nonexistent/file.zip"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "Artifact not found"
}

@test "publishes without AUTH_TOKEN using pre-configured auth" {
  set_required_env
  unset AUTH_TOKEN
  unset AUTH_USERNAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -eq 0 ]
  assert_mvn_called "deploy:deploy-file"
  assert_var_equals "MANIFESTS_PUBLISHED" "true"
}

@test "fails when AUTH_TOKEN set but AUTH_USERNAME missing" {
  set_required_env
  unset AUTH_USERNAME

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -ne 0 ]
  assert_output_contains "AUTH_USERNAME"
}

@test "does not require AUTH_TOKEN when not release" {
  set_required_env
  export IS_RELEASE="false"
  unset AUTH_TOKEN

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-maven-publish"
  [ "$status" -eq 0 ]
  assert_var_equals "MANIFESTS_PUBLISHED" "false"
}

# Skip: "fails when mvn not available" - environment-specific, hard to mock
# The command -v check is in place and verified via code review
