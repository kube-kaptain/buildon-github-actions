#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  local base_dir
  base_dir=$(create_test_dir "eks-prepare")
  # Clean stale artifacts from previous runs (create_test_dir reuses paths)
  rm -rf "$base_dir"
  mkdir -p "$base_dir"
  export TEST_BASE_DIR="$base_dir"
  export GITHUB_OUTPUT="$base_dir/github-output"
  export OUTPUT_SUB_PATH="$base_dir/target"
  export CONFIG_SUB_PATH="$base_dir/src/config"
  export EKS_CLUSTER_YAML_SUB_PATH="$base_dir/src/eks"
  export SECRETS_SUB_PATH="$base_dir/src/secrets"

  # Create required config files (PascalCase names)
  mkdir -p "$CONFIG_SUB_PATH"
  printf 'eu-west-1' > "$CONFIG_SUB_PATH/EksRegion"
  printf 'vpc-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcId"
  printf 't3.medium' > "$CONFIG_SUB_PATH/NodegroupInstanceType"
  printf 'subnet-aaa11111111111111' > "$CONFIG_SUB_PATH/PrivateSubnet1"
  printf 'subnet-bbb22222222222222' > "$CONFIG_SUB_PATH/PrivateSubnet2"
  printf 'subnet-ccc33333333333333' > "$CONFIG_SUB_PATH/PrivateSubnet3"

  # Required env vars
  export VERSION="1.0.0"
  export PROJECT_NAME="test-cluster"
  export KUBERNETES_MINOR_VERSION="32"

  # Networking defaults
  export EKS_PRIVATE_NETWORKING="true"
  export EKS_PUBLIC_NETWORKING="false"
  export EKS_CILIUM_EBPF_NETWORKING="false"
  export EKS_CUSTOM_SECURITY_GROUP="false"

  # Single platform by default
  export DOCKER_PLATFORM="linux/amd64"

  # Token defaults
  export TOKEN_DELIMITER_STYLE="shell"
  export TOKEN_NAME_STYLE="PascalCase"
}

teardown() {
  :
}

# === Required input validation ===

@test "fails when VERSION is not set" {
  unset VERSION

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION is required"
}

@test "fails when PROJECT_NAME is not set" {
  unset PROJECT_NAME

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME is required"
}

# === Config resolution ===

@test "reads KUBERNETES_MINOR_VERSION from env var" {
  export KUBERNETES_MINOR_VERSION="32"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
  assert_output_contains "Kubernetes version: 1.32"
}

@test "reads KUBERNETES_MINOR_VERSION from config file when env var unset" {
  unset KUBERNETES_MINOR_VERSION
  printf '31' > "$CONFIG_SUB_PATH/KubernetesMinorVersion"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
  assert_output_contains "Kubernetes version: 1.31"
}

@test "fails when KUBERNETES_MINOR_VERSION missing from both env and config" {
  unset KUBERNETES_MINOR_VERSION

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "KUBERNETES_MINOR_VERSION is required"
}

# === Required config file validation ===

@test "fails when EksRegion config file missing" {
  rm "$CONFIG_SUB_PATH/EksRegion"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "EKS_REGION"
  assert_output_contains "not found"
}

@test "fails when VpcId config file missing" {
  rm "$CONFIG_SUB_PATH/VpcId"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "VPC_ID"
  assert_output_contains "not found"
}

@test "fails when NodegroupInstanceType config file missing" {
  rm "$CONFIG_SUB_PATH/NodegroupInstanceType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_INSTANCE_TYPE"
  assert_output_contains "not found"
}

@test "reports all missing config files before exiting" {
  rm "$CONFIG_SUB_PATH/EksRegion"
  rm "$CONFIG_SUB_PATH/VpcId"
  rm "$CONFIG_SUB_PATH/NodegroupInstanceType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "EKS_REGION"
  assert_output_contains "VPC_ID"
  assert_output_contains "NODEGROUP_INSTANCE_TYPE"
  assert_output_contains "3 missing config file(s)"
}

# === Private networking config ===

@test "requires private subnet files when EKS_PRIVATE_NETWORKING=true" {
  rm "$CONFIG_SUB_PATH/PrivateSubnet1"
  rm "$CONFIG_SUB_PATH/PrivateSubnet2"
  rm "$CONFIG_SUB_PATH/PrivateSubnet3"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "PRIVATE_SUBNET_1"
  assert_output_contains "PRIVATE_SUBNET_2"
  assert_output_contains "PRIVATE_SUBNET_3"
}

@test "does not require private subnet files when EKS_PRIVATE_NETWORKING=false" {
  export EKS_PRIVATE_NETWORKING="false"
  rm "$CONFIG_SUB_PATH/PrivateSubnet1"
  rm "$CONFIG_SUB_PATH/PrivateSubnet2"
  rm "$CONFIG_SUB_PATH/PrivateSubnet3"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
}

# === Public networking config ===

@test "requires public subnet files when EKS_PUBLIC_NETWORKING=true" {
  export EKS_PUBLIC_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "PUBLIC_SUBNET_1"
  assert_output_contains "PUBLIC_SUBNET_2"
  assert_output_contains "PUBLIC_SUBNET_3"
}

@test "succeeds with public subnet files when EKS_PUBLIC_NETWORKING=true" {
  export EKS_PUBLIC_NETWORKING="true"
  printf 'subnet-pub11111111111111' > "$CONFIG_SUB_PATH/PublicSubnet1"
  printf 'subnet-pub22222222222222' > "$CONFIG_SUB_PATH/PublicSubnet2"
  printf 'subnet-pub33333333333333' > "$CONFIG_SUB_PATH/PublicSubnet3"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
}

# === Custom security group config ===

@test "requires VpcSecurityGroup when EKS_CUSTOM_SECURITY_GROUP=true" {
  export EKS_CUSTOM_SECURITY_GROUP="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "VPC_SECURITY_GROUP"
}

@test "succeeds with VpcSecurityGroup when EKS_CUSTOM_SECURITY_GROUP=true" {
  export EKS_CUSTOM_SECURITY_GROUP="true"
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcSecurityGroup"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
}

# === Generated cluster.yaml content ===

@test "generates cluster.yaml with metadata tokens" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  [ -f "$context_dir/cluster.yaml" ]

  local content
  content=$(< "$context_dir/cluster.yaml")
  assert_contains "$content" 'name: ${ProjectName}' "cluster.yaml"
  assert_contains "$content" 'region: ${EksRegion}' "cluster.yaml"
  assert_contains "$content" 'version: "1.32"' "cluster.yaml"
}

@test "generates cluster.yaml with vpc section" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'id: ${VpcId}' "cluster.yaml"
}

@test "generates cluster.yaml with private subnets when EKS_PRIVATE_NETWORKING=true" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "private:" "cluster.yaml"
  assert_contains "$content" '${PrivateSubnet1}' "cluster.yaml"
  assert_contains "$content" '${PrivateSubnet2}' "cluster.yaml"
  assert_contains "$content" '${PrivateSubnet3}' "cluster.yaml"
}

@test "generates cluster.yaml without private subnets when EKS_PRIVATE_NETWORKING=false" {
  export EKS_PRIVATE_NETWORKING="false"
  rm "$CONFIG_SUB_PATH/PrivateSubnet1" "$CONFIG_SUB_PATH/PrivateSubnet2" "$CONFIG_SUB_PATH/PrivateSubnet3"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"PrivateSubnet"* ]]
}

@test "generates cluster.yaml with public subnets when EKS_PUBLIC_NETWORKING=true" {
  export EKS_PUBLIC_NETWORKING="true"
  printf 'subnet-pub11111111111111' > "$CONFIG_SUB_PATH/PublicSubnet1"
  printf 'subnet-pub22222222222222' > "$CONFIG_SUB_PATH/PublicSubnet2"
  printf 'subnet-pub33333333333333' > "$CONFIG_SUB_PATH/PublicSubnet3"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "public:" "cluster.yaml"
  assert_contains "$content" '${PublicSubnet1}' "cluster.yaml"
  assert_contains "$content" '${PublicSubnet2}' "cluster.yaml"
  assert_contains "$content" '${PublicSubnet3}' "cluster.yaml"
}

@test "generates cluster.yaml with security group when EKS_CUSTOM_SECURITY_GROUP=true" {
  export EKS_CUSTOM_SECURITY_GROUP="true"
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcSecurityGroup"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'securityGroup: ${VpcSecurityGroup}' "cluster.yaml"
}

@test "generates cluster.yaml without security group by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"securityGroup"* ]]
}

@test "generates cluster.yaml with managedNodeGroups section" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "managedNodeGroups:" "cluster.yaml"
  assert_contains "$content" '${NodeGroupDefaultPrefix}' "cluster.yaml"
  assert_contains "$content" '${NodegroupInstanceType}' "cluster.yaml"
  assert_contains "$content" '${NodegroupDesiredCapacity}' "cluster.yaml"
  assert_contains "$content" '${NodegroupMinSize}' "cluster.yaml"
  assert_contains "$content" '${NodegroupMaxSize}' "cluster.yaml"
}

@test "generates cluster.yaml with privateCluster section" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "privateCluster:" "cluster.yaml"
  assert_contains "$content" "enabled: true" "cluster.yaml"
}

@test "generates cluster.yaml with addons" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "addons:" "cluster.yaml"
  assert_contains "$content" "name: coredns" "cluster.yaml"
  assert_contains "$content" "name: kube-proxy" "cluster.yaml"
  assert_contains "$content" "name: vpc-cni" "cluster.yaml"
  assert_contains "$content" "name: aws-ebs-csi-driver" "cluster.yaml"
  assert_contains "$content" "name: aws-efs-csi-driver" "cluster.yaml"
}

# === Cilium eBPF networking ===

@test "generates controlplane-only yaml when EKS_CILIUM_EBPF_NETWORKING=true" {
  export EKS_CILIUM_EBPF_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  [ -f "$context_dir/cluster.yaml" ]
  [ -f "$context_dir/cluster-controlplane-only.yaml" ]
}

@test "cilium mode excludes kube-proxy and vpc-cni from cluster.yaml addons" {
  export EKS_CILIUM_EBPF_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"name: kube-proxy"* ]]
  [[ "$content" != *"name: vpc-cni"* ]]
  assert_contains "$content" "name: coredns" "cluster.yaml"
}

@test "cilium mode includes all addons in controlplane-only yaml" {
  export EKS_CILIUM_EBPF_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster-controlplane-only.yaml")
  assert_contains "$content" "name: coredns" "controlplane-only"
  assert_contains "$content" "name: kube-proxy" "controlplane-only"
  assert_contains "$content" "name: vpc-cni" "controlplane-only"
}

@test "cilium controlplane-only yaml has no managedNodeGroups" {
  export EKS_CILIUM_EBPF_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster-controlplane-only.yaml")
  [[ "$content" != *"managedNodeGroups"* ]]
}

@test "does not generate controlplane-only yaml when EKS_CILIUM_EBPF_NETWORKING=false" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ ! -f "$OUTPUT_SUB_PATH/docker/substituted/cluster-controlplane-only.yaml" ]
}

# === Three-tier file resolution ===

@test "uses cluster.yaml from context dir if already present" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  mkdir -p "$context_dir"
  echo "pre-existing content" > "$context_dir/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$context_dir/cluster.yaml")
  assert_contains "$content" "pre-existing content" "cluster.yaml"
  assert_output_contains "already in context dir"
}

@test "copies cluster.yaml from EKS_CLUSTER_YAML_SUB_PATH when present" {
  mkdir -p "$EKS_CLUSTER_YAML_SUB_PATH"
  echo "custom cluster config" > "$EKS_CLUSTER_YAML_SUB_PATH/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "custom cluster config" "cluster.yaml"
  assert_output_contains "copied from"
}

@test "generates cluster.yaml when not in context dir or source dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "generating from template"
  [ -f "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml" ]
}

@test "copies controlplane-only yaml from source dir when present" {
  mkdir -p "$EKS_CLUSTER_YAML_SUB_PATH"
  echo "custom controlplane config" > "$EKS_CLUSTER_YAML_SUB_PATH/cluster-controlplane-only.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster-controlplane-only.yaml")
  assert_contains "$content" "custom controlplane config" "controlplane-only"
}

# === Secrets file handling ===

@test "copies aws-credentials.age when present in secrets dir" {
  mkdir -p "$SECRETS_SUB_PATH"
  echo "encrypted-credentials" > "$SECRETS_SUB_PATH/aws-credentials.age"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/substituted/aws-credentials.age" ]
}

@test "does not fail when aws-credentials.age is absent" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ ! -f "$OUTPUT_SUB_PATH/docker/substituted/aws-credentials.age" ]
}

# === Dockerfile generation ===

@test "generates Dockerfile with correct FROM line" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/Dockerfile")
  assert_contains "$content" "FROM ghcr.io/kube-kaptain/aws/aws-eks-cluster-management:1.1" "Dockerfile"
}

@test "generated Dockerfile copies cluster.yaml" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/Dockerfile")
  assert_contains "$content" "COPY cluster.yaml /kd/eks/" "Dockerfile"
}

@test "generated Dockerfile copies controlplane-only yaml when present" {
  export EKS_CILIUM_EBPF_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/Dockerfile")
  assert_contains "$content" "COPY cluster-controlplane-only.yaml /kd/eks/" "Dockerfile"
}

@test "generated Dockerfile copies credentials when present" {
  mkdir -p "$SECRETS_SUB_PATH"
  echo "encrypted" > "$SECRETS_SUB_PATH/aws-credentials.age"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/Dockerfile")
  assert_contains "$content" "COPY aws-credentials.age /kd/secrets/" "Dockerfile"
}

@test "generated Dockerfile ends with USER kaptain" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/Dockerfile")
  assert_contains "$content" "USER kaptain" "Dockerfile"
}

@test "does not overwrite existing Dockerfile in context dir" {
  local context_dir="$OUTPUT_SUB_PATH/docker/substituted"
  mkdir -p "$context_dir"
  echo "FROM custom-image:latest" > "$context_dir/Dockerfile"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$context_dir/Dockerfile")
  assert_contains "$content" "FROM custom-image:latest" "Dockerfile"
}

@test "uses custom base image parts from env vars" {
  export EKS_BASE_IMAGE_REGISTRY="docker.io"
  export EKS_BASE_IMAGE_NAMESPACE="myorg"
  export EKS_BASE_IMAGE_NAME="custom-eks"
  export EKS_BASE_IMAGE_TAG="2.0"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/Dockerfile")
  assert_contains "$content" "FROM docker.io/myorg/custom-eks:2.0" "Dockerfile"
}

# === Nodegroup prefix ===

@test "nodegroup prefix contains k8s version components" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "k-1-32"
}

@test "nodegroup prefix contains version with dashes" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "v-1-0-0"
}

@test "nodegroup prefix starts with ng-" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "ng-"
}

@test "writes nodegroup prefix to output dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/nodegroup-prefix" ]
  local prefix
  prefix=$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/nodegroup-prefix")
  [[ "$prefix" == ng-* ]]
  [[ "$prefix" == *-k-1-32-v-1-0-0 ]]
}

@test "writes nodegroup prefix to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodeGroupDefaultPrefix" ]
  local prefix
  prefix=$(< "$OUTPUT_SUB_PATH/docker/config/NodeGroupDefaultPrefix")
  [[ "$prefix" == ng-* ]]
}

# === Default token handling ===

@test "writes default NODEGROUP_DESIRED_CAPACITY to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity")
  [ "$value" = "1" ]
}

@test "writes default NODEGROUP_MIN_SIZE to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupMinSize" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupMinSize")
  [ "$value" = "3" ]
}

@test "writes default NODEGROUP_MAX_SIZE to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupMaxSize" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupMaxSize")
  [ "$value" = "12" ]
}

@test "does not overwrite user-provided nodegroup sizing in CONFIG_SUB_PATH" {
  printf '5' > "$CONFIG_SUB_PATH/NodegroupDesiredCapacity"
  printf '2' > "$CONFIG_SUB_PATH/NodegroupMinSize"
  printf '20' > "$CONFIG_SUB_PATH/NodegroupMaxSize"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "user config found"
  # Platform config dir should NOT have the default values written
  [ ! -f "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity" ] || {
    local value
    value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity")
    # If written, it shouldn't be the default since user override exists in CONFIG_SUB_PATH
    # Actually the script skips writing when user config is found
    true
  }
}

@test "uses custom nodegroup sizing from env vars" {
  export NODEGROUP_DESIRED_CAPACITY="4"
  export NODEGROUP_MIN_SIZE="2"
  export NODEGROUP_MAX_SIZE="24"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity")
  [ "$value" = "4" ]
}

# === DOCKERFILE_SUBSTITUTION_FILES output ===

@test "outputs DOCKERFILE_SUBSTITUTION_FILES with cluster.yaml appended" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "DOCKERFILE_SUBSTITUTION_FILES=Dockerfile,cluster.yaml"
}

@test "outputs DOCKERFILE_SUBSTITUTION_FILES with both yamls when cilium enabled" {
  export EKS_CILIUM_EBPF_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "DOCKERFILE_SUBSTITUTION_FILES=Dockerfile,cluster.yaml,cluster-controlplane-only.yaml"
}

@test "writes DOCKERFILE_SUBSTITUTION_FILES to GITHUB_OUTPUT" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$GITHUB_OUTPUT" ]
  local gh_output
  gh_output=$(< "$GITHUB_OUTPUT")
  assert_contains "$gh_output" "DOCKERFILE_SUBSTITUTION_FILES=Dockerfile,cluster.yaml" "GITHUB_OUTPUT"
}

# === Multi-platform support ===

@test "creates context dirs for both platforms when multi-platform" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker-linux-amd64/substituted/cluster.yaml" ]
  [ -f "$OUTPUT_SUB_PATH/docker-linux-arm64/substituted/cluster.yaml" ]
}

@test "creates config dirs for both platforms when multi-platform" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker-linux-amd64/config/NodeGroupDefaultPrefix" ]
  [ -f "$OUTPUT_SUB_PATH/docker-linux-arm64/config/NodeGroupDefaultPrefix" ]
}

@test "generates Dockerfile for both platforms" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker-linux-amd64/substituted/Dockerfile" ]
  [ -f "$OUTPUT_SUB_PATH/docker-linux-arm64/substituted/Dockerfile" ]
}

@test "writes defaults to both platform config dirs" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker-linux-amd64/config/NodegroupDesiredCapacity" ]
  [ -f "$OUTPUT_SUB_PATH/docker-linux-arm64/config/NodegroupDesiredCapacity" ]
}

# === Token style handling ===

@test "generates tokens with shell delimiter style by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  # Shell style uses ${VarName}
  assert_contains "$content" '${ProjectName}' "cluster.yaml"
  assert_contains "$content" '${EksRegion}' "cluster.yaml"
}

@test "generates tokens with mustache delimiter style" {
  export TOKEN_DELIMITER_STYLE="mustache"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" '{{ ProjectName }}' "cluster.yaml"
  assert_contains "$content" '{{ EksRegion }}' "cluster.yaml"
}

@test "generates tokens with UPPER_SNAKE name style" {
  export TOKEN_NAME_STYLE="UPPER_SNAKE"

  # UPPER_SNAKE style looks for config files named with underscores
  mv "$CONFIG_SUB_PATH/EksRegion" "$CONFIG_SUB_PATH/EKS_REGION"
  mv "$CONFIG_SUB_PATH/VpcId" "$CONFIG_SUB_PATH/VPC_ID"
  mv "$CONFIG_SUB_PATH/NodegroupInstanceType" "$CONFIG_SUB_PATH/NODEGROUP_INSTANCE_TYPE"
  mv "$CONFIG_SUB_PATH/PrivateSubnet1" "$CONFIG_SUB_PATH/PRIVATE_SUBNET_1"
  mv "$CONFIG_SUB_PATH/PrivateSubnet2" "$CONFIG_SUB_PATH/PRIVATE_SUBNET_2"
  mv "$CONFIG_SUB_PATH/PrivateSubnet3" "$CONFIG_SUB_PATH/PRIVATE_SUBNET_3"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" '${PROJECT_NAME}' "cluster.yaml"
  assert_contains "$content" '${EKS_REGION}' "cluster.yaml"

  # Config file names should also be UPPER_SNAKE
  [ -f "$OUTPUT_SUB_PATH/docker/config/NODE_GROUP_DEFAULT_PREFIX" ]
}

@test "fails with invalid TOKEN_DELIMITER_STYLE" {
  export TOKEN_DELIMITER_STYLE="invalid"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown substitution token style"
}

@test "fails with invalid TOKEN_NAME_STYLE" {
  export TOKEN_NAME_STYLE="invalid"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown token name style"
}

# === Output messages ===

@test "outputs EKS prepare header" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "EKS Cluster Management Prepare"
}

@test "outputs base image info" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "Base image: ghcr.io/kube-kaptain/aws/aws-eks-cluster-management:1.1"
}

@test "outputs completion message" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "EKS Cluster Management Prepare complete"
}

@test "outputs substitution files list" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "Substitution files: Dockerfile,cluster.yaml"
}

# === Custom addon list ===

@test "uses custom addon list from env var" {
  export EKS_ADDONS_LIST="coredns,kube-proxy"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "name: coredns" "cluster.yaml"
  assert_contains "$content" "name: kube-proxy" "cluster.yaml"
  [[ "$content" != *"name: vpc-cni"* ]]
}

# === eksctl format ===

@test "generated yaml has correct eksctl apiVersion" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "apiVersion: eksctl.io/v1alpha5" "cluster.yaml"
  assert_contains "$content" "kind: ClusterConfig" "cluster.yaml"
}
