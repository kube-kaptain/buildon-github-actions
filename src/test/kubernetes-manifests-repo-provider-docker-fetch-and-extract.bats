#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-manifests-repo-provider-docker-fetch-and-extract
# This script pulls a Docker image and extracts the manifests zip.

load helpers

setup() {
  local base_dir=$(create_test_dir "k8s-repo-docker-fetch")
  export MOCK_DOCKER_CALLS="$base_dir/docker-calls.log"
  mkdir -p "$MOCK_BIN_DIR"

  # Create test output directory (used as OUTPUT_SUB_PATH)
  export OUTPUT_SUB_PATH="$base_dir/target"
  mkdir -p "$OUTPUT_SUB_PATH"

  # Create a fake zip file that will be "extracted" from the container
  export MOCK_ZIP_DIR="$base_dir/mock-zip"
  mkdir -p "$MOCK_ZIP_DIR"
  mkdir -p "$MOCK_ZIP_DIR/manifests"
  echo "deployment.yaml content" > "$MOCK_ZIP_DIR/manifests/deployment.yaml"
  echo "service.yaml content" > "$MOCK_ZIP_DIR/manifests/service.yaml"
  (cd "$MOCK_ZIP_DIR" && zip -q -r test-manifests.zip manifests)

  # Create mock docker that simulates the full flow
  # Note: We embed the paths directly since the mock runs as a separate process
  cat > "$MOCK_BIN_DIR/docker" << MOCKDOCKER
#!/usr/bin/env bash
echo "\$*" >> "${MOCK_DOCKER_CALLS}"

if [[ "\$1" == "pull" ]]; then
  exit 0
fi

if [[ "\$1" == "create" ]]; then
  echo "abc123container"
  exit 0
fi

if [[ "\$1" == "run" && "\$*" == *"ls -1 /"* ]]; then
  echo "test-manifests.zip"
  exit 0
fi

if [[ "\$1" == "cp" ]]; then
  # \$2 is container:path, \$3 is destination
  dest="\$3"
  cp "${MOCK_ZIP_DIR}/test-manifests.zip" "\$dest"
  exit 0
fi

if [[ "\$1" == "rm" ]]; then
  exit 0
fi

exit 0
MOCKDOCKER
  chmod +x "$MOCK_BIN_DIR/docker"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

teardown() {
  :
}

@test "extracts manifests from docker image" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  # Check manifests were extracted to standard location
  [ -f "$OUTPUT_SUB_PATH/extracted-manifests/manifests/deployment.yaml" ]
  [ -f "$OUTPUT_SUB_PATH/extracted-manifests/manifests/service.yaml" ]
}

@test "stores zip in fetched-manifests directory" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/fetched-manifests/test-manifests.zip" ]
}

@test "calls docker pull with correct image" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  grep -q "pull ghcr.io/myorg/myapp-manifests:1.2.3" "$MOCK_DOCKER_CALLS"
}

@test "calls docker create to access filesystem" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  grep -q "create ghcr.io/myorg/myapp-manifests:1.2.3" "$MOCK_DOCKER_CALLS"
}

@test "calls docker cp to extract zip" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  grep -q "cp abc123container:/test-manifests.zip" "$MOCK_DOCKER_CALLS"
}

@test "cleans up container" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  grep -q "rm abc123container" "$MOCK_DOCKER_CALLS"
}

@test "fails when no arguments provided" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract"

  [ "$status" -ne 0 ]
  assert_output_contains "Missing required argument: manifests-image-uri"
}

@test "fails when docker pull fails" {
  # Override mock to fail on pull
  cat > "$MOCK_BIN_DIR/docker" << 'MOCKDOCKER'
#!/usr/bin/env bash
if [[ "$1" == "pull" ]]; then
  echo "Error: pull access denied" >&2
  exit 1
fi
exit 0
MOCKDOCKER
  chmod +x "$MOCK_BIN_DIR/docker"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -ne 0 ]
  assert_output_contains "Failed to pull image"
}

@test "fails when no zip found in image" {
  # Override mock to return no zip files
  cat > "$MOCK_BIN_DIR/docker" << 'MOCKDOCKER'
#!/usr/bin/env bash
if [[ "$1" == "pull" ]]; then
  exit 0
fi
if [[ "$1" == "create" ]]; then
  echo "abc123container"
  exit 0
fi
if [[ "$1" == "run" && "$*" == *"ls -1 /"* ]]; then
  # No zip file
  echo "some-other-file.txt"
  exit 0
fi
if [[ "$1" == "rm" ]]; then
  exit 0
fi
exit 0
MOCKDOCKER
  chmod +x "$MOCK_BIN_DIR/docker"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -ne 0 ]
  assert_output_contains "No zip file found"
}

@test "creates output directories automatically" {
  # Use a fresh subpath to verify directory creation
  export OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH}/fresh-subdir"
  mkdir -p "$OUTPUT_SUB_PATH"

  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  [ -d "$OUTPUT_SUB_PATH/fetched-manifests" ]
  [ -d "$OUTPUT_SUB_PATH/extracted-manifests" ]
  [ -f "$OUTPUT_SUB_PATH/extracted-manifests/manifests/deployment.yaml" ]
}

@test "outputs completion message" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  assert_output_contains "Fetch-and-Extract: Docker complete"
}

@test "outputs zip file location" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  assert_output_contains "fetched-manifests/test-manifests.zip"
}

@test "outputs manifests location" {
  run "$REPO_PROVIDERS_DIR/kubernetes-manifests-repo-provider-docker-fetch-and-extract" \
    "ghcr.io/myorg/myapp-manifests:1.2.3"

  [ "$status" -eq 0 ]
  assert_output_contains "extracted-manifests"
}
