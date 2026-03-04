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
  export IMAGE_BUILD_COMMAND="podman"
  export DOCKER_TAG="1.0.0"
  export DOCKER_IMAGE_NAME="test-cluster"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"

  # Token defaults
  export TOKEN_DELIMITER_STYLE="shell"
  export TOKEN_NAME_STYLE="PascalCase"

  # Single platform by default
  export DOCKER_PLATFORM="linux/amd64"

  # Create canonical value files (as written by prepare step)
  local nodegroup_prefix="ng-20260302-k-1-32-v-1-0-0"
  mkdir -p "$OUTPUT_SUB_PATH/aws-eks-cluster-management"
  printf '%s' "test-cluster" > "$OUTPUT_SUB_PATH/aws-eks-cluster-management/project-name"
  printf '%s' "eu-west-1" > "$OUTPUT_SUB_PATH/aws-eks-cluster-management/aws-region"
  printf '%s' "1.32" > "$OUTPUT_SUB_PATH/aws-eks-cluster-management/kubernetes-version"
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
      eu-west-1a:
        id: subnet-aaa11111111111111
      eu-west-1b:
        id: subnet-bbb22222222222222
      eu-west-1c:
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
    version: latest
  - name: kube-proxy
    version: latest
  - name: vpc-cni
    version: latest
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

@test "fails when metadata.name does not match canonical project-name" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.name = "wrong-cluster"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "must be exactly"
}

@test "fails when metadata.region does not match canonical aws-region" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.region = "us-east-1"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "must be exactly"
}

@test "fails when metadata.region is not a valid AWS region format" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  # Set both the canonical file and yaml to the same bad value
  printf '%s' "not-a-region" > "$OUTPUT_SUB_PATH/aws-eks-cluster-management/aws-region"
  yq -i '.metadata.region = "not-a-region"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "does not look like an AWS region"
}

# === metadata.version validation ===

@test "fails when metadata.version does not match canonical kubernetes-version" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.version = "1.31"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "must be exactly"
}

@test "fails when metadata.version minor part is less than 2 digits" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  printf '%s' "1.9" > "$OUTPUT_SUB_PATH/aws-eks-cluster-management/kubernetes-version"
  yq -i '.metadata.version = "1.9"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "minor is at least 2 digits"
}

@test "passes when metadata.version minor part has 3 digits" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  printf '%s' "1.100" > "$OUTPUT_SUB_PATH/aws-eks-cluster-management/kubernetes-version"
  yq -i '.metadata.version = "1.100"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -eq 0 ]
}

# === vpc.id validation ===

@test "fails when vpc.id does not look like a VPC ID" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.vpc.id = "not-a-vpc-id"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "does not look like a VPC ID"
}

# === subnet id validation ===

@test "fails when subnet key is not region + AZ letter" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.vpc.subnets.private.badkey = .vpc.subnets.private."eu-west-1a"' "$context_dir/cluster.yaml"
  yq -i 'del(.vpc.subnets.private."eu-west-1a")' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "must be region + single AZ letter"
}

@test "fails when subnet id does not look like a subnet ID" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.vpc.subnets.private."eu-west-1a".id = "not-a-subnet"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "does not look like a subnet ID"
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

@test "fails when kubernetes-version file is missing" {
  rm "$OUTPUT_SUB_PATH/aws-eks-cluster-management/kubernetes-version"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "kubernetes-version"
  assert_output_contains "not found"
}

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

# === Canonical value files ===

@test "fails when project-name file is missing" {
  rm "$OUTPUT_SUB_PATH/aws-eks-cluster-management/project-name"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "project-name"
  assert_output_contains "not found"
}

@test "fails when aws-region file is missing" {
  rm "$OUTPUT_SUB_PATH/aws-eks-cluster-management/aws-region"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-post-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "aws-region"
  assert_output_contains "not found"
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
    version: latest
  - name: kube-proxy
    version: latest
  - name: vpc-cni
    version: latest
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
    version: latest
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
  assert_output_contains "AWS region: eu-west-1"
  assert_output_contains "Kubernetes version: 1.32"
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
