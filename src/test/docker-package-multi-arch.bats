#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_docker
  export IMAGE_BUILD_COMMAND="docker"
  export VERSION="1.0.0"
  export PROJECT_NAME="my-repo"
  local base_dir=$(create_test_dir "docker-pkg-multi-arch")
  export GITHUB_OUTPUT="$base_dir/output"
  export OUTPUT_SUB_PATH="$base_dir/target"
  export DOCKER_PUSH_IMAGE_LIST_FILE="${OUTPUT_SUB_PATH}/docker-push-all/image-uris"
  mkdir -p "$(dirname "$DOCKER_PUSH_IMAGE_LIST_FILE")"
  # Create content directory with test files
  export CONTENT_DIR="$base_dir/content"
  mkdir -p "$CONTENT_DIR"
  echo "test data" > "$CONTENT_DIR/data.yaml"
}

teardown() {
  :
}

# === Basic functionality ===

@test "builds both architectures" {
  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]
  assert_docker_called "build --platform linux/amd64 -t ghcr.io/test/my-repo:1.0.0-rcd-linux-amd64"
  assert_docker_called "build --platform linux/arm64 -t ghcr.io/test/my-repo:1.0.0-rcd-linux-arm64"
}

@test "registers arch-specific URIs in image-uris" {
  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]

  [ -f "$DOCKER_PUSH_IMAGE_LIST_FILE" ]
  run cat "$DOCKER_PUSH_IMAGE_LIST_FILE"
  [[ "$output" == *"ghcr.io/test/my-repo:1.0.0-rcd-linux-amd64"* ]]
  [[ "$output" == *"ghcr.io/test/my-repo:1.0.0-rcd-linux-arm64"* ]]
}

@test "registers base URI in manifest-uris" {
  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]

  local manifest_file="${OUTPUT_SUB_PATH}/docker-push-all/manifest-uris"
  [ -f "$manifest_file" ]
  run cat "$manifest_file"
  [[ "$output" == *"ghcr.io/test/my-repo:1.0.0-rcd"* ]]
}

# === Dockerfile generation ===

@test "generates Dockerfile with FROM scratch by default" {
  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]

  local dockerfile="${OUTPUT_SUB_PATH}/docker-package-multi-arch/content/Dockerfile"
  [ -f "$dockerfile" ]
  run cat "$dockerfile"
  [[ "$output" == *"FROM scratch"* ]]
}

@test "generates COPY entries for all content files" {
  echo "more data" > "$CONTENT_DIR/extra.txt"

  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]

  local dockerfile="${OUTPUT_SUB_PATH}/docker-package-multi-arch/content/Dockerfile"
  run cat "$dockerfile"
  [[ "$output" == *"COPY data.yaml /data.yaml"* ]]
  [[ "$output" == *"COPY extra.txt /extra.txt"* ]]
}

@test "uses custom base image when PACKAGE_BASE_IMAGE set" {
  export PACKAGE_BASE_IMAGE="alpine:3.21"

  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]

  local dockerfile="${OUTPUT_SUB_PATH}/docker-package-multi-arch/content/Dockerfile"
  run cat "$dockerfile"
  [[ "$output" == *"FROM alpine:3.21"* ]]
}

# === Labels ===

@test "adds standard labels to generated Dockerfile" {
  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]

  local dockerfile="${OUTPUT_SUB_PATH}/docker-package-multi-arch/content/Dockerfile"
  run cat "$dockerfile"
  [[ "$output" == *'LABEL version="1.0.0"'* ]]
  [[ "$output" == *'LABEL project.name="my-repo"'* ]]
  [[ "$output" == *'LABEL image.name="test/my-repo"'* ]]
  [[ "$output" == *'LABEL image.tag="1.0.0-rcd"'* ]]
  [[ "$output" == *'LABEL image.uri="ghcr.io/test/my-repo:1.0.0-rcd"'* ]]
}

# === Error handling ===

@test "fails when content directory does not exist" {
  run "$UTIL_DIR/docker-package-multi-arch" "/nonexistent/path" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -ne 0 ]
  assert_output_contains "Content directory not found"
}

@test "fails when no arguments provided" {
  run "$UTIL_DIR/docker-package-multi-arch"
  [ "$status" -ne 0 ]
}

# === Output messages ===

@test "outputs header with content dir and base URI" {
  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker Package Multi-Arch"
  assert_output_contains "Base URI: ghcr.io/test/my-repo:1.0.0-rcd"
  assert_output_contains "Base image: scratch"
}

@test "outputs completion message" {
  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker package multi-arch complete"
}

@test "outputs generated Dockerfile" {
  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]
  assert_output_contains "Generated Dockerfile:"
}

# === Podman support ===

@test "works with podman as IMAGE_BUILD_COMMAND" {
  export IMAGE_BUILD_COMMAND="podman"

  run "$UTIL_DIR/docker-package-multi-arch" "$CONTENT_DIR" "ghcr.io/test/my-repo:1.0.0-rcd"
  [ "$status" -eq 0 ]
  assert_docker_called "build --platform linux/amd64 -t ghcr.io/test/my-repo:1.0.0-rcd-linux-amd64"
}
