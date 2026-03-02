#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

# Pre-build-validate uses yq to parse cluster yaml - skip all tests if not available
setup() {
  if ! command -v yq &>/dev/null; then
    skip "yq not installed"
  fi

  local base_dir
  base_dir=$(create_test_dir "eks-pre-validate")
  # Clean stale artifacts from previous runs (create_test_dir reuses paths)
  rm -rf "$base_dir"
  mkdir -p "$base_dir"
  export TEST_BASE_DIR="$base_dir"
  export GITHUB_OUTPUT="$base_dir/github-output"
  export OUTPUT_SUB_PATH="$base_dir/target"
  export CONFIG_SUB_PATH="$base_dir/src/config"

  # Create minimal required config files
  mkdir -p "$CONFIG_SUB_PATH"
  printf 'eu-west-1' > "$CONFIG_SUB_PATH/EksRegion"
  printf 'vpc-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcId"
  printf 't3.medium' > "$CONFIG_SUB_PATH/NodegroupInstanceType"
  printf 'subnet-aaa11111111111111' > "$CONFIG_SUB_PATH/PrivateSubnet1"
  printf 'subnet-bbb22222222222222' > "$CONFIG_SUB_PATH/PrivateSubnet2"
  printf 'subnet-ccc33333333333333' > "$CONFIG_SUB_PATH/PrivateSubnet3"

  # Token defaults
  export TOKEN_DELIMITER_STYLE="shell"
  export TOKEN_NAME_STYLE="PascalCase"

  # Single platform by default
  export DOCKER_PLATFORM="linux/amd64"

  # Create context dir with a valid cluster.yaml containing tokens
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  mkdir -p "$context_dir"

  cat > "$context_dir/cluster.yaml" << 'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${ProjectName}
  region: ${EksRegion}
  version: "1.32"

vpc:
  id: ${VpcId}
  subnets:
    private:
      az1:
        id: ${PrivateSubnet1}
      az2:
        id: ${PrivateSubnet2}
      az3:
        id: ${PrivateSubnet3}

privateCluster:
  enabled: true

managedNodeGroups:
  - name: ${NodeGroupDefaultPrefix}
    instanceType: ${NodegroupInstanceType}
    privateNetworking: true
    desiredCapacity: ${NodegroupDesiredCapacity}
    minSize: ${NodegroupMinSize}
    maxSize: ${NodegroupMaxSize}

addons:
  - name: coredns
  - name: kube-proxy
  - name: vpc-cni
YAML
}

teardown() {
  :
}

# === Valid cluster yaml passes ===

@test "passes validation with correct token placement" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -eq 0 ]
  assert_output_contains "all token checks passed"
}

# === metadata.name validation ===

@test "fails when metadata.name is missing" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  # Remove metadata.name
  yq -i 'del(.metadata.name)' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "metadata.name is missing"
}

@test "fails when metadata.name is not the PROJECT_NAME token" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.name = "hardcoded-name"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "must be exactly"
  assert_output_contains '${ProjectName}'
}

# === metadata.region validation ===

@test "fails when metadata.region is missing" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i 'del(.metadata.region)' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "metadata.region is missing"
}

@test "fails when metadata.region is not the EKS_REGION token" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.region = "eu-west-1"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "must be exactly"
  assert_output_contains '${EksRegion}'
}

# === nodegroup name validation ===

@test "fails when nodegroup name does not start with prefix token" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.managedNodeGroups[0].name = "bad-nodegroup-name"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "does not start with NODE_GROUP_DEFAULT_PREFIX"
}

@test "passes when nodegroup name starts with prefix token" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -eq 0 ]
}

@test "fails when nodegroup name is missing" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i 'del(.managedNodeGroups[0].name)' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "name is missing"
}

# === Multiple nodegroups ===

@test "passes with multiple uniquely-named nodegroups" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.managedNodeGroups += [{"name": "${NodeGroupDefaultPrefix}-gpu", "instanceType": "g5.xlarge"}]' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -eq 0 ]
}

@test "fails with duplicate nodegroup names" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.managedNodeGroups += [{"name": "${NodeGroupDefaultPrefix}", "instanceType": "g5.xlarge"}]' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "duplicate nodegroup names"
}

# === Missing cluster.yaml ===

@test "fails when cluster.yaml not found in context dir" {
  rm "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "file not found"
}

# === Controlplane-only yaml validation ===

@test "validates controlplane-only yaml when present" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  cat > "$context_dir/cluster-controlplane-only.yaml" << 'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${ProjectName}
  region: ${EksRegion}
  version: "1.32"

vpc:
  id: ${VpcId}

privateCluster:
  enabled: true

addons:
  - name: coredns
  - name: kube-proxy
  - name: vpc-cni
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -eq 0 ]
}

@test "fails when controlplane-only yaml has wrong metadata.name" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  cat > "$context_dir/cluster-controlplane-only.yaml" << 'YAML'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: wrong-name
  region: ${EksRegion}
  version: "1.32"

vpc:
  id: ${VpcId}

addons:
  - name: coredns
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "must be exactly"
}

# === Multi-platform validation ===

@test "validates both platform context dirs when multi-platform" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"

  # Copy the valid cluster.yaml to both context dirs
  local amd_dir="$OUTPUT_SUB_PATH/docker-linux-amd64/substituted"
  local arm_dir="$OUTPUT_SUB_PATH/docker-linux-arm64/substituted"
  mkdir -p "$amd_dir" "$arm_dir"
  cp "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml" "$amd_dir/cluster.yaml"
  cp "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml" "$arm_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -eq 0 ]
}

# === Output messages ===

@test "outputs pre-build validate header" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -eq 0 ]
  assert_output_contains "EKS Cluster Management Pre-Build Validate"
}

@test "outputs expected token strings" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -eq 0 ]
  assert_output_contains 'Expected PROJECT_NAME token: ${ProjectName}'
  assert_output_contains 'Expected EKS_REGION token: ${EksRegion}'
}

# === Fail-complete behavior ===

@test "reports multiple validation errors before exiting" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  yq -i '.metadata.name = "wrong"' "$context_dir/cluster.yaml"
  yq -i '.metadata.region = "wrong"' "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-pre-build-validate"
  [ "$status" -ne 0 ]
  assert_output_contains "metadata.name"
  assert_output_contains "metadata.region"
  assert_output_contains "2 error(s)"
}
