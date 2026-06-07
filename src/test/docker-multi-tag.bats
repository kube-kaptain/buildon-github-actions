#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

bats_require_minimum_version 1.5.0

load helpers

setup() {
  setup_mock_docker
  export IMAGE_BUILD_COMMAND="docker"
  export BUILD_MODE="build_server"
  local base_dir=$(create_test_dir "docker-multi-tag")
  export GITHUB_OUTPUT="$base_dir/output"
  export OUTPUT_SUB_PATH="$base_dir/target"
  export DOCKER_PUSH_IMAGE_LIST_FILE="${OUTPUT_SUB_PATH}/docker-push-all/image-uris"
  mkdir -p "$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE=""
}

teardown() {
  dump_bats_result
  :
}

# Required env vars for most tests
set_required_env() {
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE=""
}

# Append image URIs (one per tag, using current registry/namespace/image-name)
# to the image-uris file, mirroring what real build steps do before multi-tag.
# Usage: mock_image_tags "1.0.0" "1.0.0-release-change-data"
mock_image_tags() {
  for tag in "$@"; do
    if [[ -n "${DOCKER_TARGET_NAMESPACE:-}" ]]; then
      echo "${DOCKER_TARGET_REGISTRY}/${DOCKER_TARGET_NAMESPACE}/${DOCKER_IMAGE_NAME}:${tag}"
    else
      echo "${DOCKER_TARGET_REGISTRY}/${DOCKER_IMAGE_NAME}:${tag}"
    fi
  done >> "${DOCKER_PUSH_IMAGE_LIST_FILE}"
}

# Append manifest URIs to the manifest-uris file, mirroring what a
# multi-platform build step does. Usage: mock_manifest_tags "1.0.0"
mock_manifest_tags() {
  local file="${OUTPUT_SUB_PATH}/docker-push-all/manifest-uris"
  mkdir -p "$(dirname "$file")"
  for tag in "$@"; do
    if [[ -n "${DOCKER_TARGET_NAMESPACE:-}" ]]; then
      echo "${DOCKER_TARGET_REGISTRY}/${DOCKER_TARGET_NAMESPACE}/${DOCKER_IMAGE_NAME}:${tag}"
    else
      echo "${DOCKER_TARGET_REGISTRY}/${DOCKER_IMAGE_NAME}:${tag}"
    fi
  done >> "${file}"
}

# === Retagging images ===

@test "retags single image to single registry" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/test/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
  assert_var_equals "MANIFESTS_TAGGED" "0"
}

@test "retags multiple images to single registry" {
  set_required_env
  mock_image_tags "1.0.0" "1.0.0-release-change-data" "1.0.0-manifests"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/test/my-repo:1.0.0"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0-release-change-data docker.io/test/my-repo:1.0.0-release-change-data"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0-manifests docker.io/test/my-repo:1.0.0-manifests"
  assert_var_equals "IMAGES_TAGGED" "3"
}

@test "retags multiple images to multiple registries" {
  set_required_env
  mock_image_tags "1.0.0" "1.0.0-manifests"
  export DOCKER_PUSH_TARGETS='[
    {"registry": "docker.io"},
    {"registry": "quay.io"}
  ]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/test/my-repo:1.0.0"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 quay.io/test/my-repo:1.0.0"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0-manifests docker.io/test/my-repo:1.0.0-manifests"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0-manifests quay.io/test/my-repo:1.0.0-manifests"
  assert_var_equals "IMAGES_TAGGED" "4"
}

# === Empty / missing image-uris ===

@test "fails when image-uris file is empty" {
  set_required_env
  touch "$DOCKER_PUSH_IMAGE_LIST_FILE"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "Image URIs file is empty"
}

@test "fails when image-uris file is missing" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "Image URIs file not found"
}

# === Namespace handling ===

@test "includes target namespace when specified" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io", "namespace": "library"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/library/test/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
}

@test "strips source namespace prefix correctly" {
  set_required_env
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/kube-kaptain/test/my-repo:1.0.0 docker.io/test/my-repo:1.0.0"
}

@test "handles mix of targets with and without namespace" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[
    {"registry": "docker.io"},
    {"registry": "quay.io", "namespace": "myorg"}
  ]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/test/my-repo:1.0.0"
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 quay.io/myorg/test/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "2"
}

@test "handles nested namespace" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "myregistry.example.com", "namespace": "team/project"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 myregistry.example.com/team/project/test/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
}

@test "handles ECR registry format" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "123456789012.dkr.ecr.us-east-1.amazonaws.com"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 123456789012.dkr.ecr.us-east-1.amazonaws.com/test/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
}

# === Push registration ===

@test "registers all tagged images for docker-push-all" {
  set_required_env
  mock_image_tags "1.0.0" "1.0.0-manifests"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]

  local push_file="$DOCKER_PUSH_IMAGE_LIST_FILE"
  [ -f "$push_file" ]
  run cat "$push_file"
  [[ "$output" == *"docker.io/test/my-repo:1.0.0"* ]] || return 1
  [[ "$output" == *"docker.io/test/my-repo:1.0.0-manifests"* ]] || return 1
}

# === Skip / error handling ===

@test "skips when DOCKER_PUSH_TARGETS missing" {
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_output_contains "skipping multi-tag"
}

@test "skips when DOCKER_PUSH_TARGETS is empty array" {
  set_required_env
  export DOCKER_PUSH_TARGETS='[]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_output_contains "empty array"
}

@test "fails when DOCKER_TARGET_REGISTRY missing" {
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'
  unset DOCKER_TARGET_REGISTRY

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_TARGET_REGISTRY"
}

@test "fails when target missing registry field" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"namespace": "myorg"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "missing required 'registry' field"
}

@test "fails when target has null registry" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": null}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "missing required 'registry' field"
}

@test "fails on invalid JSON" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "must be a valid JSON array"
}

# === Output formatting ===

@test "outputs count to GITHUB_OUTPUT" {
  set_required_env
  mock_image_tags "1.0.0" "1.0.0-release-change-data"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]

  grep -q "IMAGES_TAGGED=2" "$GITHUB_OUTPUT"
  grep -q "MANIFESTS_TAGGED=0" "$GITHUB_OUTPUT"
}

@test "outputs progress messages to stderr" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker Multi-Tag"
  assert_output_contains "Source prefix:"
  assert_output_contains "Tagging image:"
}

# === Manifest list handling ===

@test "retags manifest list to additional registry" {
  set_required_env
  mock_image_tags "1.0.0-linux-amd64" "1.0.0-linux-arm64"
  mock_manifest_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]

  local manifest_file="${OUTPUT_SUB_PATH}/docker-push-all/manifest-uris"
  [ -f "$manifest_file" ]
  run cat "$manifest_file"
  [[ "$output" == *"docker.io/test/my-repo:1.0.0"* ]] || return 1
}

@test "retags manifest list to multiple registries with counts" {
  set_required_env
  mock_image_tags "1.0.0-linux-amd64" "1.0.0-linux-arm64"
  mock_manifest_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[
    {"registry": "docker.io"},
    {"registry": "quay.io", "namespace": "myorg"}
  ]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]

  # Counts: 2 arch images × 2 targets = 4 image retags; 1 manifest × 2 targets = 2
  assert_var_equals "IMAGES_TAGGED" "4"
  assert_var_equals "MANIFESTS_TAGGED" "2"

  local manifest_file="${OUTPUT_SUB_PATH}/docker-push-all/manifest-uris"
  [ -f "$manifest_file" ]
  run cat "$manifest_file"
  [[ "$output" == *"docker.io/test/my-repo:1.0.0"* ]] || return 1
  [[ "$output" == *"quay.io/myorg/test/my-repo:1.0.0"* ]] || return 1
}

@test "does not write manifest-uris when no manifests seeded" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]

  local manifest_file="${OUTPUT_SUB_PATH}/docker-push-all/manifest-uris"
  [ ! -f "$manifest_file" ]
  assert_var_equals "MANIFESTS_TAGGED" "0"
}
