#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

# Create a mock docker that returns sha256sum output matching disk files
# when called with "run", and logs all calls for assertion
setup_eks_mock_docker() {
  export MOCK_DOCKER_CALLS=$(create_test_dir "mock-docker")/calls.log
  mkdir -p "$MOCK_BIN_DIR"
  cat > "$MOCK_BIN_DIR/docker" << 'MOCKDOCKER'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_DOCKER_CALLS"
if [[ "$1" == "run" ]]; then
  # Find the sha256sum command in the -c arg
  for i in $(seq 1 $#); do
    arg="${!i}"
    if [[ "$arg" == "-c" ]]; then
      next=$((i + 1))
      cmd="${!next}"
      if [[ "$cmd" == sha256sum* ]]; then
        # Extract file paths and compute checksums from disk equivalents
        for image_path in ${cmd#sha256sum}; do
          filename="${image_path##*/}"
          disk_file="${MOCK_DOCKER_CONTEXT_DIR}/${filename}"
          if [[ -f "$disk_file" ]]; then
            checksum=$(sha256sum "$disk_file" | cut -d' ' -f1)
            echo "${checksum}  ${image_path}"
          fi
        done
        exit 0
      fi
    fi
  done
  exit 0
fi
if [[ "$1" == "manifest" && "$2" == "inspect" ]]; then
  if [[ "${MOCK_DOCKER_MANIFEST_EXISTS:-false}" == "true" ]]; then
    exit 0
  else
    exit 1
  fi
fi
exit 0
MOCKDOCKER
  chmod +x "$MOCK_BIN_DIR/docker"
  cp "$MOCK_BIN_DIR/docker" "$MOCK_BIN_DIR/podman"
  chmod +x "$MOCK_BIN_DIR/podman"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

# Post-build-validate uses yq and docker - skip all tests if yq not available
setup() {
  if ! command -v yq &>/dev/null; then
    skip "yq not installed"
  fi

  local base_dir
  base_dir=$(create_test_dir "eks-post-validate")
  # Clean stale artifacts from previous runs (create_test_dir reuses paths)
  rm -rf "$base_dir"
  mkdir -p "$base_dir"
  export TEST_BASE_DIR="$base_dir"
  export GITHUB_OUTPUT="$base_dir/github-output"
  export OUTPUT_SUB_PATH="$base_dir/target"
  export CONFIG_SUB_PATH="$base_dir/src/config"

  # Required env vars
  export PROJECT_NAME="test-cluster"
  export IMAGE_BUILD_COMMAND="docker"
  export DOCKER_TAG="1.0.0"
  export DOCKER_IMAGE_NAME="test-cluster"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"

  # Token defaults
  export TOKEN_DELIMITER_STYLE="shell"
  export TOKEN_NAME_STYLE="PascalCase"

  # Single platform by default
  export DOCKER_PLATFORM="linux/amd64"

  # Create nodegroup prefix file (as written by prepare step)
  local nodegroup_prefix="ng-20260302-k-1-32-v-1-0-0"
  mkdir -p "$OUTPUT_SUB_PATH/aws-eks-cluster-management"
  printf '%s' "$nodegroup_prefix" > "$OUTPUT_SUB_PATH/aws-eks-cluster-management/nodegroup-prefix"

  # Create context dir with substituted cluster.yaml (tokens already replaced)
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  mkdir -p "$context_dir"
  export MOCK_DOCKER_CONTEXT_DIR="$context_dir"

  cat > "$context_dir/cluster.yaml" << YAML
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: test-cluster
  region: eu-west-1
  version: "1.32"

vpc:
  id: vpc-0123456789abcdef0
  subnets:
    private:
      az1:
        id: subnet-aaa11111111111111
      az2:
        id: subnet-bbb22222222222222
      az3:
        id: subnet-ccc33333333333333

privateCluster:
  enabled: true

managedNodeGroups:
  - name: ${nodegroup_prefix}
    instanceType: t3.medium
    privateNetworking: true
    desiredCapacity: 1
    minSize: 3
    maxSize: 12

addons:
  - name: coredns
  - name: kube-proxy
  - name: vpc-cni
YAML

  # Mock docker that returns matching sha256sum output for image integrity checks
  setup_eks_mock_docker
}

teardown() {
  :
}

# === Phase 1: Substituted file validation ===

@test "passes validation with correctly substituted cluster.yaml" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -eq 0 ]
  assert_output_contains "all checks passed"
}

@test "fails when unsubstituted tokens remain" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.name = "${ProjectName}"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "unsubstituted tokens found"
}

@test "fails when metadata.name does not contain PROJECT_NAME" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.name = "wrong-cluster"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "does not contain project name"
}

@test "fails when metadata.region is not a valid AWS region" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.region = "not-a-region"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "does not look like an AWS region"
}

@test "accepts valid AWS region formats" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"

  yq -i '.metadata.region = "us-east-1"' "$context_dir/cluster.yaml"
  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -eq 0 ]
}

@test "fails when nodegroup name does not start with computed prefix" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.managedNodeGroups[0].name = "wrong-prefix-name"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "does not start with nodegroup prefix"
}

@test "fails with duplicate nodegroup names in substituted yaml" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  local prefix
  prefix=$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/nodegroup-prefix")
  yq -i ".managedNodeGroups += [{\"name\": \"${prefix}\", \"instanceType\": \"g5.xlarge\"}]" "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "duplicate nodegroup names"
}

@test "fails when cluster.yaml not found" {
  rm "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "file not found"
}

# === Nodegroup prefix file ===

@test "fails when nodegroup-prefix file is missing" {
  rm "$OUTPUT_SUB_PATH/aws-eks-cluster-management/nodegroup-prefix"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "nodegroup-prefix"
  assert_output_contains "not found"
}

# === Phase 2: Image integrity ===

@test "runs image integrity check with mock docker" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -eq 0 ]
  assert_output_contains "Validating image integrity"
  assert_output_contains "image checksum matches disk"
}

@test "calls docker run for image integrity check" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"

  # Mock docker logs all calls - check it was called with run
  assert_docker_called "run"
}

# === Required inputs ===

@test "fails when PROJECT_NAME is not set" {
  unset PROJECT_NAME

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME is required"
}

# === Controlplane-only yaml validation ===

@test "validates controlplane-only yaml when present" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"

  cat > "$context_dir/cluster-controlplane-only.yaml" << 'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: test-cluster
  region: eu-west-1
  version: "1.32"

vpc:
  id: vpc-0123456789abcdef0

privateCluster:
  enabled: true

addons:
  - name: coredns
  - name: kube-proxy
  - name: vpc-cni
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -eq 0 ]
}

@test "fails when controlplane-only yaml has unsubstituted tokens" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"

  cat > "$context_dir/cluster-controlplane-only.yaml" << 'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${ProjectName}
  region: eu-west-1
  version: "1.32"

addons:
  - name: coredns
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "unsubstituted tokens found"
}

# === Output messages ===

@test "outputs post-build validate header" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"

  assert_output_contains "EKS Cluster Management Post-Build Validate"
  assert_output_contains "Project name: test-cluster"
}

# === Fail-complete behavior ===

@test "reports multiple validation errors before exiting" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.name = "wrong-name"' "$context_dir/cluster.yaml"
  yq -i '.metadata.region = "not-valid"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "metadata.name"
  assert_output_contains "metadata.region"
}
