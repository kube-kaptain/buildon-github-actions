#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_docker
  local base_dir=$(create_test_dir "rcd-oci")
  export GITHUB_OUTPUT="$base_dir/output"
  export OUTPUT_SUB_PATH="$base_dir/target"
  export DOCKER_PUSH_IMAGE_LIST_FILE="${OUTPUT_SUB_PATH}/docker-push-all/image-uris"
  mkdir -p "$OUTPUT_SUB_PATH/release-change-data/docker-context"
  mkdir -p "$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")"
  # Create versioned YAML file (normally produced by release-change-data-generate)
  echo "change:" > "$OUTPUT_SUB_PATH/release-change-data/docker-context/release-change-data-1.0.1.yaml"
}

teardown() {
  :
}

set_required_env() {
  export VERSION="1.0.1"
  export DOCKER_TAG="1.0.1"
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export IMAGE_BUILD_COMMAND="docker"
}

@test "builds OCI image with correct URI" {
  set_required_env

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -eq 0 ]
  assert_docker_called "build -t ghcr.io/test/my-repo:1.0.1-release-change-data"
}

@test "uses -release-change-data tag suffix" {
  set_required_env

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -eq 0 ]
  assert_var_equals "RELEASE_CHANGE_DATA_IMAGE_URI" "ghcr.io/test/my-repo:1.0.1-release-change-data"
}

@test "includes namespace in URI when set" {
  set_required_env
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -eq 0 ]
  assert_var_equals "RELEASE_CHANGE_DATA_IMAGE_URI" "ghcr.io/kube-kaptain/test/my-repo:1.0.1-release-change-data"
}

@test "registers image URI for docker-push-all" {
  set_required_env

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -eq 0 ]

  local push_file="$DOCKER_PUSH_IMAGE_LIST_FILE"
  [ -f "$push_file" ]
  run cat "$push_file"
  [[ "$output" == *"ghcr.io/test/my-repo:1.0.1-release-change-data"* ]]
}

@test "generates Dockerfile in context directory" {
  set_required_env

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -eq 0 ]

  local dockerfile="$OUTPUT_SUB_PATH/release-change-data/docker-context/Dockerfile"
  [ -f "$dockerfile" ]
  run cat "$dockerfile"
  [[ "$output" == *"FROM scratch"* ]]
  [[ "$output" == *"release-change-data-1.0.1.yaml"* ]]
}

@test "fails when versioned YAML not found" {
  set_required_env
  rm "$OUTPUT_SUB_PATH/release-change-data/docker-context/release-change-data-1.0.1.yaml"

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -ne 0 ]
  assert_output_contains "Versioned YAML not found"
}

@test "fails when VERSION not set" {
  set_required_env
  unset VERSION

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "fails when DOCKER_TAG not set" {
  set_required_env
  unset DOCKER_TAG

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_TAG"
}

@test "fails when DOCKER_TARGET_REGISTRY not set" {
  set_required_env
  unset DOCKER_TARGET_REGISTRY

  run "$SCRIPTS_DIR/release-change-data-oci-package"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_TARGET_REGISTRY"
}
