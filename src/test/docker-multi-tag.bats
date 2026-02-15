#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_docker
  export IMAGE_BUILD_COMMAND="docker"
  local base_dir=$(create_test_dir "docker-multi-tag")
  export GITHUB_OUTPUT="$base_dir/output"
  export DOCKER_PUSH_IMAGE_LIST_FILE="$base_dir/target/docker-push-all/image-uris"
  mkdir -p "$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE=""
}

teardown() {
  :
}

# Required env vars for most tests
set_required_env() {
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE=""
}

# Set up mock docker to return specific tags from images --filter
# Usage: mock_image_tags "1.0.0" "1.0.0-release-change-data" "1.0.0-manifests"
mock_image_tags() {
  local tags_output=""
  for tag in "$@"; do
    tags_output+="${tag}"$'\n'
  done
  # Remove trailing newline
  tags_output="${tags_output%$'\n'}"

  cat > "$MOCK_BIN_DIR/docker" << MOCKDOCKER
#!/usr/bin/env bash
echo "\$*" >> "\$MOCK_DOCKER_CALLS"
if [[ "\$1" == "images" ]]; then
  cat << 'TAGS'
${tags_output}
TAGS
  exit 0
fi
exit 0
MOCKDOCKER
  chmod +x "$MOCK_BIN_DIR/docker"
  cp "$MOCK_BIN_DIR/docker" "$MOCK_BIN_DIR/podman"
  chmod +x "$MOCK_BIN_DIR/podman"
}

# === Discovery ===

@test "discovers and retags single image to single registry" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "tag ghcr.io/test/my-repo:1.0.0 docker.io/test/my-repo:1.0.0"
  assert_var_equals "IMAGES_TAGGED" "1"
}

@test "discovers and retags multiple images to single registry" {
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

@test "discovers and retags multiple images to multiple registries" {
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

# === No images found ===

@test "exits 0 with zero tagged when no images found" {
  set_required_env
  mock_image_tags
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "IMAGES_TAGGED" "0"
  assert_output_contains "No images found"
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

@test "handles source namespace in filter" {
  set_required_env
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "images --filter reference=ghcr.io/kube-kaptain/test/my-repo:1.0.0*"
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
  [[ "$output" == *"docker.io/test/my-repo:1.0.0"* ]]
  [[ "$output" == *"docker.io/test/my-repo:1.0.0-manifests"* ]]
}

# === Error handling ===

@test "fails when DOCKER_IMAGE_NAME missing" {
  export DOCKER_TAG="1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_IMAGE_NAME"
}

@test "fails when DOCKER_TAG missing" {
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_TAG"
}

@test "fails when DOCKER_PUSH_TARGETS missing" {
  export DOCKER_IMAGE_NAME="test/my-repo"
  export DOCKER_TAG="1.0.0"

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_PUSH_TARGETS"
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
}

@test "outputs progress messages to stderr" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker Multi-Tag"
  assert_output_contains "Image name: test/my-repo"
  assert_output_contains "Tagging:"
}

# === Filter construction ===

@test "constructs correct filter without namespace" {
  set_required_env
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "images --filter reference=ghcr.io/test/my-repo:1.0.0*"
}

@test "constructs correct filter with namespace" {
  set_required_env
  export DOCKER_TARGET_NAMESPACE="myorg"
  mock_image_tags "1.0.0"
  export DOCKER_PUSH_TARGETS='[{"registry": "docker.io"}]'

  run "$SCRIPTS_DIR/docker-multi-tag"
  [ "$status" -eq 0 ]
  assert_docker_called "images --filter reference=ghcr.io/myorg/test/my-repo:1.0.0*"
}
