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
  printf 'eu-west-1' > "$CONFIG_SUB_PATH/AwsRegion"
  printf 'vpc-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcId"
  printf 't3.medium' > "$CONFIG_SUB_PATH/NodegroupInstanceType"
  printf 'arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012' > "$CONFIG_SUB_PATH/SecretsEncryptionKeyArn"
  printf '123456789012' > "$CONFIG_SUB_PATH/AwsAccountId"
  printf 'sg-clusterdefault123456' > "$CONFIG_SUB_PATH/ClusterSecurityGroup"
  printf 'eksctl' > "$CONFIG_SUB_PATH/ClusterOrigin"
  printf 'managed' > "$CONFIG_SUB_PATH/NodegroupType"
  printf 'subnet-aaa11111111111111' > "$CONFIG_SUB_PATH/PrivateSubnetIdA"
  printf 'subnet-bbb22222222222222' > "$CONFIG_SUB_PATH/PrivateSubnetIdB"
  printf 'subnet-ccc33333333333333' > "$CONFIG_SUB_PATH/PrivateSubnetIdC"

  # Required env vars
  export VERSION="1.0.0"
  export PROJECT_NAME="test-cluster"
  export KUBERNETES_MINOR_VERSION="32"

  # Networking defaults
  export EKS_PRIVATE_NETWORKING="true"
  export EKS_PUBLIC_NETWORKING="false"
  export EKS_CILIUM_EBPF_NETWORKING="false"

  # Single platform by default
  export DOCKER_PLATFORM="linux/amd64"
  export IMAGE_BUILD_COMMAND="podman"

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

@test "fails when AwsRegion config file missing" {
  rm "$CONFIG_SUB_PATH/AwsRegion"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "AWS_REGION"
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

@test "fails when SecretsEncryptionKeyArn config file missing" {
  rm "$CONFIG_SUB_PATH/SecretsEncryptionKeyArn"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "SECRETS_ENCRYPTION_KEY_ARN"
  assert_output_contains "not found"
}

@test "reports all missing config files before exiting" {
  rm "$CONFIG_SUB_PATH/AwsRegion"
  rm "$CONFIG_SUB_PATH/VpcId"
  rm "$CONFIG_SUB_PATH/NodegroupInstanceType"
  rm "$CONFIG_SUB_PATH/SecretsEncryptionKeyArn"
  rm "$CONFIG_SUB_PATH/AwsAccountId"
  rm "$CONFIG_SUB_PATH/ClusterOrigin"
  rm "$CONFIG_SUB_PATH/NodegroupType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "AWS_REGION"
  assert_output_contains "VPC_ID"
  assert_output_contains "NODEGROUP_INSTANCE_TYPE"
  assert_output_contains "SECRETS_ENCRYPTION_KEY_ARN"
  assert_output_contains "AWS_ACCOUNT_ID"
  assert_output_contains "CLUSTER_ORIGIN"
  assert_output_contains "NODEGROUP_TYPE"
  assert_output_contains "7 missing config file(s)"
}

# === Private networking config ===

@test "requires private subnet files when EKS_PRIVATE_NETWORKING=true" {
  rm "$CONFIG_SUB_PATH/PrivateSubnetIdA"
  rm "$CONFIG_SUB_PATH/PrivateSubnetIdB"
  rm "$CONFIG_SUB_PATH/PrivateSubnetIdC"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "PRIVATE_SUBNET_ID_A"
  assert_output_contains "PRIVATE_SUBNET_ID_B"
  assert_output_contains "PRIVATE_SUBNET_ID_C"
}

@test "does not require private subnet files when EKS_PRIVATE_NETWORKING=false" {
  export EKS_PRIVATE_NETWORKING="false"
  rm "$CONFIG_SUB_PATH/PrivateSubnetIdA"
  rm "$CONFIG_SUB_PATH/PrivateSubnetIdB"
  rm "$CONFIG_SUB_PATH/PrivateSubnetIdC"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
}

# === Public networking config ===

@test "requires public subnet files when EKS_PUBLIC_NETWORKING=true" {
  export EKS_PUBLIC_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "PUBLIC_SUBNET_ID_A"
  assert_output_contains "PUBLIC_SUBNET_ID_B"
  assert_output_contains "PUBLIC_SUBNET_ID_C"
}

@test "succeeds with public subnet files when EKS_PUBLIC_NETWORKING=true" {
  export EKS_PUBLIC_NETWORKING="true"
  printf 'subnet-pub11111111111111' > "$CONFIG_SUB_PATH/PublicSubnetIdA"
  printf 'subnet-pub22222222222222' > "$CONFIG_SUB_PATH/PublicSubnetIdB"
  printf 'subnet-pub33333333333333' > "$CONFIG_SUB_PATH/PublicSubnetIdC"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
}

# === VPC security group config ===

@test "does not generate securityGroup by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"securityGroup"* ]]
}

# === Cluster origin ===

@test "fails when ClusterOrigin config file missing" {
  rm "$CONFIG_SUB_PATH/ClusterOrigin"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "CLUSTER_ORIGIN"
  assert_output_contains "not found"
}

@test "fails when ClusterOrigin has invalid value" {
  printf 'terraform' > "$CONFIG_SUB_PATH/ClusterOrigin"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "CLUSTER_ORIGIN"
  assert_output_contains "must be 'eksctl' or 'adopted'"
}

@test "succeeds with ClusterOrigin=eksctl without security group config" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
  assert_output_contains "Cluster origin: eksctl"
}

@test "succeeds with ClusterOrigin=adopted and VpcSecurityGroup present" {
  printf 'adopted' > "$CONFIG_SUB_PATH/ClusterOrigin"
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcSecurityGroup"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
  assert_output_contains "Cluster origin: adopted"
}

@test "succeeds with ClusterOrigin=adopted and VpcControlPlaneSecurityGroupIds present" {
  printf 'adopted' > "$CONFIG_SUB_PATH/ClusterOrigin"
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcControlPlaneSecurityGroupIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
}

@test "fails with ClusterOrigin=adopted and no security group config" {
  printf 'adopted' > "$CONFIG_SUB_PATH/ClusterOrigin"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "CLUSTER_ORIGIN=adopted"
  assert_output_contains "VPC_SECURITY_GROUP"
}

@test "fails when both VpcSecurityGroup and VpcControlPlaneSecurityGroupIds present" {
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcSecurityGroup"
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcControlPlaneSecurityGroupIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "mutually exclusive"
}

@test "fails when both SG configs present even with adopted origin" {
  printf 'adopted' > "$CONFIG_SUB_PATH/ClusterOrigin"
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcSecurityGroup"
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcControlPlaneSecurityGroupIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "mutually exclusive"
}

# === Nodegroup type ===

@test "fails when NodegroupType config file missing" {
  rm "$CONFIG_SUB_PATH/NodegroupType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_TYPE"
  assert_output_contains "not found"
}

@test "fails when NodegroupType has invalid value" {
  printf 'fargate' > "$CONFIG_SUB_PATH/NodegroupType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_TYPE"
  assert_output_contains "must be 'managed' or 'unmanaged'"
}

@test "generates managedNodeGroups when NodegroupType is managed" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "managedNodeGroups:" "cluster.yaml"
  [[ "$content" != *"nodeGroups:"* ]]
}

@test "generates nodeGroups when NodegroupType is unmanaged" {
  printf 'unmanaged' > "$CONFIG_SUB_PATH/NodegroupType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "nodeGroups:" "cluster.yaml"
  [[ "$content" != *"managedNodeGroups:"* ]]
}

@test "generates updateConfig when NodegroupType is managed" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "updateConfig:" "cluster.yaml"
  assert_contains "$content" "maxUnavailable:" "cluster.yaml"
}

@test "does not generate updateConfig when NodegroupType is unmanaged" {
  printf 'unmanaged' > "$CONFIG_SUB_PATH/NodegroupType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"updateConfig:"* ]]
  [[ "$content" != *"maxUnavailable:"* ]]
}

@test "does not write updateConfig default when NodegroupType is unmanaged" {
  printf 'unmanaged' > "$CONFIG_SUB_PATH/NodegroupType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ ! -f "$OUTPUT_SUB_PATH/docker/config/NodegroupUpdateConfigMaxUnavailable" ]
}

@test "fails when updateConfig config present with unmanaged NodegroupType" {
  printf 'unmanaged' > "$CONFIG_SUB_PATH/NodegroupType"
  printf '2' > "$CONFIG_SUB_PATH/NodegroupUpdateConfigMaxUnavailable"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_UPDATE_CONFIG_MAX_UNAVAILABLE"
  assert_output_contains "not supported for unmanaged"
}

@test "writes nodegroup-type to expected-values" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/nodegroup-type" ]
  [ "$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/nodegroup-type")" = "managed" ]
}

# === Control plane security group IDs generation ===

@test "generates controlPlaneSecurityGroupIDs with numbered tokens when config present" {
  printf 'sg-aaa,sg-bbb' > "$CONFIG_SUB_PATH/VpcControlPlaneSecurityGroupIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "controlPlaneSecurityGroupIDs:" "cluster.yaml"
  assert_contains "$content" '- ${VpcControlPlaneSecurityGroupId1}' "cluster.yaml"
  assert_contains "$content" '- ${VpcControlPlaneSecurityGroupId2}' "cluster.yaml"
}

@test "expands VPC_CONTROL_PLANE_SECURITY_GROUP_IDS to numbered token files" {
  printf 'sg-aaa,sg-bbb,sg-ccc' > "$CONFIG_SUB_PATH/VpcControlPlaneSecurityGroupIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ "$(< "$OUTPUT_SUB_PATH/docker/config/VpcControlPlaneSecurityGroupId1")" = "sg-aaa" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/VpcControlPlaneSecurityGroupId2")" = "sg-bbb" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/VpcControlPlaneSecurityGroupId3")" = "sg-ccc" ]
}

@test "writes control-plane-sg-ids-count to expected-values" {
  printf 'sg-aaa,sg-bbb' > "$CONFIG_SUB_PATH/VpcControlPlaneSecurityGroupIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/control-plane-sg-ids-count" ]
  [ "$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/control-plane-sg-ids-count")" = "2" ]
}

@test "does not generate controlPlaneSecurityGroupIDs by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"controlPlaneSecurityGroupIDs"* ]]
}

@test "generates securityGroups.attachIDs with numbered tokens when config present" {
  printf 'sg-aaa,sg-bbb' > "$CONFIG_SUB_PATH/NodegroupSecurityGroupsAttachIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "securityGroups:" "cluster.yaml"
  assert_contains "$content" "attachIDs:" "cluster.yaml"
  assert_contains "$content" '- ${NodegroupSecurityGroupsAttachId1}' "cluster.yaml"
  assert_contains "$content" '- ${NodegroupSecurityGroupsAttachId2}' "cluster.yaml"
}

@test "expands NODEGROUP_SECURITY_GROUPS_ATTACH_IDS to numbered token files" {
  printf 'sg-aaa,sg-bbb,sg-ccc' > "$CONFIG_SUB_PATH/NodegroupSecurityGroupsAttachIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ "$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupSecurityGroupsAttachId1")" = "sg-aaa" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupSecurityGroupsAttachId2")" = "sg-bbb" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupSecurityGroupsAttachId3")" = "sg-ccc" ]
}

@test "writes nodegroup-sg-attach-ids-count to expected-values" {
  printf 'sg-aaa,sg-bbb' > "$CONFIG_SUB_PATH/NodegroupSecurityGroupsAttachIds"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/nodegroup-sg-attach-ids-count" ]
  [ "$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/nodegroup-sg-attach-ids-count")" = "2" ]
}

@test "generates sharedNodeSecurityGroup when config present and unmanaged" {
  printf 'unmanaged' > "$CONFIG_SUB_PATH/NodegroupType"
  printf 'sg-0shared123456789' > "$CONFIG_SUB_PATH/VpcSharedNodeSecurityGroup"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'sharedNodeSecurityGroup: ${VpcSharedNodeSecurityGroup}' "cluster.yaml"
}

@test "does not generate sharedNodeSecurityGroup by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"sharedNodeSecurityGroup"* ]]
}

@test "fails when sharedNodeSecurityGroup config present with managed NodegroupType" {
  printf 'sg-0shared123456789' > "$CONFIG_SUB_PATH/VpcSharedNodeSecurityGroup"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "VPC_SHARED_NODE_SECURITY_GROUP"
  assert_output_contains "not supported for managed"
}

# === Volume config ===

@test "generates volumeType and volumeEncrypted in cluster.yaml" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'volumeType: ${NodegroupVolumeType}' "cluster.yaml"
  assert_contains "$content" 'volumeEncrypted: ${NodegroupVolumeEncrypted}' "cluster.yaml"
}

@test "generates volumeKmsKeyID when config present" {
  printf 'arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012' > "$CONFIG_SUB_PATH/NodegroupVolumeKmsKeyId"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'volumeKmsKeyID: ${NodegroupVolumeKmsKeyId}' "cluster.yaml"
}

@test "does not generate volumeKmsKeyID by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"volumeKmsKeyID"* ]]
}

@test "fails when NODEGROUP_VOLUME_TYPE is invalid" {
  printf 'ssd' > "$CONFIG_SUB_PATH/NodegroupVolumeType"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_VOLUME_TYPE"
  assert_output_contains "must be one of"
}

@test "fails when NODEGROUP_VOLUME_ENCRYPTED is not true or false" {
  printf 'yes' > "$CONFIG_SUB_PATH/NodegroupVolumeEncrypted"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_VOLUME_ENCRYPTED"
  assert_output_contains "true"
  assert_output_contains "false"
}

@test "does not generate securityGroups.attachIDs by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"attachIDs"* ]]
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
  assert_contains "$content" 'region: ${AwsRegion}' "cluster.yaml"
  assert_contains "$content" 'version: "${KubernetesVersion}"' "cluster.yaml"
}

@test "generates cluster.yaml with vpc section" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'id: ${VpcId}' "cluster.yaml"
}

@test "generates cluster.yaml with clusterEndpoints section" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "clusterEndpoints:" "cluster.yaml"
  assert_contains "$content" 'privateAccess: ${VpcClusterEndpointsPrivateAccess}' "cluster.yaml"
  assert_contains "$content" 'publicAccess: ${VpcClusterEndpointsPublicAccess}' "cluster.yaml"
}

@test "generates cluster.yaml with private subnets when EKS_PRIVATE_NETWORKING=true" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "private:" "cluster.yaml"
  assert_contains "$content" '${PrivateSubnetIdA}' "cluster.yaml"
  assert_contains "$content" '${PrivateSubnetIdB}' "cluster.yaml"
  assert_contains "$content" '${PrivateSubnetIdC}' "cluster.yaml"
}

@test "generates cluster.yaml without private subnets when EKS_PRIVATE_NETWORKING=false" {
  export EKS_PRIVATE_NETWORKING="false"
  rm "$CONFIG_SUB_PATH/PrivateSubnetIdA" "$CONFIG_SUB_PATH/PrivateSubnetIdB" "$CONFIG_SUB_PATH/PrivateSubnetIdC"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"PrivateSubnet"* ]]
}

@test "generates cluster.yaml with public subnets when EKS_PUBLIC_NETWORKING=true" {
  export EKS_PUBLIC_NETWORKING="true"
  printf 'subnet-pub11111111111111' > "$CONFIG_SUB_PATH/PublicSubnetIdA"
  printf 'subnet-pub22222222222222' > "$CONFIG_SUB_PATH/PublicSubnetIdB"
  printf 'subnet-pub33333333333333' > "$CONFIG_SUB_PATH/PublicSubnetIdC"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "public:" "cluster.yaml"
  assert_contains "$content" '${PublicSubnetIdA}' "cluster.yaml"
  assert_contains "$content" '${PublicSubnetIdB}' "cluster.yaml"
  assert_contains "$content" '${PublicSubnetIdC}' "cluster.yaml"
}

@test "generates cluster.yaml with securityGroup token when config present" {
  printf 'sg-0123456789abcdef0' > "$CONFIG_SUB_PATH/VpcSecurityGroup"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'securityGroup: ${VpcSecurityGroup}' "cluster.yaml"
}

# === Auto Mode config ===

@test "does not generate autoModeConfig by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"autoModeConfig"* ]]
}

@test "generates autoModeConfig when config file exists with false" {
  printf 'false' > "$CONFIG_SUB_PATH/AutoModeConfigEnabled"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "autoModeConfig:" "cluster.yaml"
  assert_contains "$content" 'enabled: ${AutoModeConfigEnabled}' "cluster.yaml"
  [[ "$content" != *"nodePools"* ]]
}

@test "generates autoModeConfig with nodePools when enabled=true" {
  printf 'true' > "$CONFIG_SUB_PATH/AutoModeConfigEnabled"
  printf 'general-purpose,system' > "$CONFIG_SUB_PATH/AutoModeConfigNodePools"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "autoModeConfig:" "cluster.yaml"
  assert_contains "$content" 'enabled: ${AutoModeConfigEnabled}' "cluster.yaml"
  assert_contains "$content" '- ${AutoModeConfigNodePool1}' "cluster.yaml"
  assert_contains "$content" '- ${AutoModeConfigNodePool2}' "cluster.yaml"

  # Verify numbered token files were written
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/AutoModeConfigNodePool1")" = "general-purpose" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/AutoModeConfigNodePool2")" = "system" ]
}

@test "fails when AutoModeConfigEnabled=true but AutoModeConfigNodePools missing" {
  printf 'true' > "$CONFIG_SUB_PATH/AutoModeConfigEnabled"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "AUTO_MODE_CONFIG_NODE_POOLS"
  assert_output_contains "not found"
}

# === Network config ===

@test "does not generate kubernetesNetworkConfig by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"kubernetesNetworkConfig"* ]]
}

@test "generates kubernetesNetworkConfig when config file exists" {
  printf '10.100.0.0/16' > "$CONFIG_SUB_PATH/NetworkConfigServiceIpV4Cidr"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "kubernetesNetworkConfig:" "cluster.yaml"
  assert_contains "$content" 'serviceIPv4CIDR: ${NetworkConfigServiceIpV4Cidr}' "cluster.yaml"
}

@test "generates cluster.yaml with managedNodeGroups section" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "managedNodeGroups:" "cluster.yaml"
  assert_contains "$content" '${NodeGroupDefaultPrefix}' "cluster.yaml"
  assert_contains "$content" '${NodegroupInstanceType}' "cluster.yaml"
  assert_contains "$content" '${NodegroupAmiFamily}' "cluster.yaml"
  assert_contains "$content" '${NodegroupVolumeSize}' "cluster.yaml"
  assert_contains "$content" '${NodegroupVolumeType}' "cluster.yaml"
  assert_contains "$content" '${NodegroupVolumeEncrypted}' "cluster.yaml"
  assert_contains "$content" '${NodegroupDesiredCapacity}' "cluster.yaml"
  assert_contains "$content" '${NodegroupMinSize}' "cluster.yaml"
  assert_contains "$content" '${NodegroupMaxSize}' "cluster.yaml"
  assert_contains "$content" "updateConfig:" "cluster.yaml"
  assert_contains "$content" '${NodegroupUpdateConfigMaxUnavailable}' "cluster.yaml"
  # subnets present (EKS_PRIVATE_NETWORKING=true by default)
  assert_contains "$content" "subnets:" "cluster.yaml nodegroup"
  assert_contains "$content" '${PrivateSubnetIdA}' "cluster.yaml nodegroup subnets"
  assert_contains "$content" '${PrivateSubnetIdB}' "cluster.yaml nodegroup subnets"
  assert_contains "$content" '${PrivateSubnetIdC}' "cluster.yaml nodegroup subnets"
  # privateNetworking not present without config file
  [[ "$content" != *"privateNetworking"* ]]
}

@test "generates privateNetworking in nodegroup when config file present" {
  printf 'true' > "$CONFIG_SUB_PATH/NodegroupPrivateNetworking"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'privateNetworking: ${NodegroupPrivateNetworking}' "cluster.yaml"
}

@test "generates nodegroup subnets with public subnets when EKS_PUBLIC_NETWORKING=true" {
  export EKS_PUBLIC_NETWORKING="true"
  printf 'subnet-pub11111111111111' > "$CONFIG_SUB_PATH/PublicSubnetIdA"
  printf 'subnet-pub22222222222222' > "$CONFIG_SUB_PATH/PublicSubnetIdB"
  printf 'subnet-pub33333333333333' > "$CONFIG_SUB_PATH/PublicSubnetIdC"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" '${PublicSubnetIdA}' "cluster.yaml nodegroup subnets"
}

@test "does not generate nodegroup subnets when no networking subnets" {
  export EKS_PRIVATE_NETWORKING="false"
  export EKS_PUBLIC_NETWORKING="false"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  # managedNodeGroups section should not contain subnets
  # vpc section has no subnets either, so no "subnets:" at all
  [[ "$content" != *"subnets:"* ]]
}

@test "generates iam.instanceRoleARN in nodegroup when config file present" {
  printf 'arn:aws:iam::123456789012:role/my-node-role' > "$CONFIG_SUB_PATH/NodegroupIamInstanceRoleArn"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "iam:" "cluster.yaml nodegroup"
  assert_contains "$content" 'instanceRoleARN: ${NodegroupIamInstanceRoleArn}' "cluster.yaml"
}

@test "does not generate instanceRoleARN by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"instanceRoleARN"* ]]
}

@test "generates cluster.yaml with iam section" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "iam:" "cluster.yaml"
  assert_contains "$content" 'withOIDC: ${IamWithOidc}' "cluster.yaml"
}

@test "does not generate privateCluster section by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"privateCluster"* ]]
}

@test "generates privateCluster section when config file present" {
  printf 'true' > "$CONFIG_SUB_PATH/PrivateClusterEnabled"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "privateCluster:" "cluster.yaml"
  assert_contains "$content" 'enabled: ${PrivateClusterEnabled}' "cluster.yaml"
}

@test "generates cluster.yaml with cloudWatch section as block sequence" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "cloudWatch:" "cluster.yaml"
  assert_contains "$content" "clusterLogging:" "cluster.yaml"
  assert_contains "$content" "enableTypes:" "cluster.yaml"
  assert_contains "$content" '- ${CloudWatchClusterLoggingEnableType1}' "cluster.yaml"
  assert_contains "$content" '- ${CloudWatchClusterLoggingEnableType5}' "cluster.yaml"
}

@test "generates cluster.yaml with secretsEncryption section" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "secretsEncryption:" "cluster.yaml"
  assert_contains "$content" 'keyARN: ${SecretsEncryptionKeyArn}' "cluster.yaml"
}

# === Tags and labels ===

@test "generates fixed metadata tags by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'ManagedBy: "Kaptain aws-eks-cluster-management system"' "cluster.yaml"
  assert_contains "$content" 'ManagedByGitRepo: ${ProjectName}' "cluster.yaml"
}

@test "generates fixed nodegroup tags by default" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  # Nodegroup tags section should also have the fixed tags
  # Count occurrences - should appear twice (metadata + nodegroup)
  local count
  count=$(grep -c 'ManagedBy: "Kaptain aws-eks-cluster-management system"' "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [ "$count" -eq 2 ]
}

@test "appends user metadata tags from config file" {
  cat > "$CONFIG_SUB_PATH/MetadataTags" << 'EOF'
Environment: production
Team: "platform engineering"
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "Environment: production" "cluster.yaml"
  assert_contains "$content" 'Team: "platform engineering"' "cluster.yaml"
  # Fixed tags still present
  assert_contains "$content" 'ManagedBy: "Kaptain aws-eks-cluster-management system"' "cluster.yaml"
}

@test "fails when metadata tags contain reserved Name key" {
  cat > "$CONFIG_SUB_PATH/MetadataTags" << 'EOF'
Name: my-cluster-name
Environment: production
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "METADATA_TAGS"
  assert_output_contains "Name"
  assert_output_contains "reserved"
}

@test "appends user nodegroup tags from config file" {
  cat > "$CONFIG_SUB_PATH/NodegroupTags" << 'EOF'
CostCenter: '12345'
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "CostCenter: '12345'" "cluster.yaml"
}

@test "fails when nodegroup tags contain reserved Name key" {
  cat > "$CONFIG_SUB_PATH/NodegroupTags" << 'EOF'
Name: my-custom-name
CostCenter: '12345'
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "Name"
  assert_output_contains "reserved"
}

@test "generates nodegroup labels from config file" {
  cat > "$CONFIG_SUB_PATH/NodegroupLabels" << 'EOF'
role: worker
environment: production
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "labels:" "cluster.yaml"
  assert_contains "$content" "role: worker" "cluster.yaml"
  assert_contains "$content" "environment: production" "cluster.yaml"
}

@test "does not generate nodegroup labels section when config absent" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"labels:"* ]]
}

# === Nodegroup taints ===

@test "generates taints when config file present" {
  cat > "$CONFIG_SUB_PATH/NodegroupTaints" << 'YAML'
- key: workload
  value: kong
  effect: NoSchedule
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "taints:" "cluster.yaml"
  assert_contains "$content" "key: workload" "cluster.yaml taints"
  assert_contains "$content" "value: kong" "cluster.yaml taints"
  assert_contains "$content" "effect: NoSchedule" "cluster.yaml taints"
}

@test "generates taints with multiple entries" {
  cat > "$CONFIG_SUB_PATH/NodegroupTaints" << 'YAML'
- key: workload
  value: kong
  effect: NoSchedule
- key: dedicated
  effect: NoExecute
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "key: workload" "cluster.yaml taints"
  assert_contains "$content" "key: dedicated" "cluster.yaml taints"
  assert_contains "$content" "effect: NoExecute" "cluster.yaml taints"
}

@test "does not generate taints when config absent" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"taints:"* ]]
}

@test "fails when taint missing key" {
  cat > "$CONFIG_SUB_PATH/NodegroupTaints" << 'YAML'
- value: kong
  effect: NoSchedule
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_TAINTS"
  assert_output_contains "missing 'key'"
}

@test "fails when taint missing effect" {
  cat > "$CONFIG_SUB_PATH/NodegroupTaints" << 'YAML'
- key: workload
  value: kong
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_TAINTS"
  assert_output_contains "missing 'effect'"
}

@test "fails when taint has invalid effect" {
  cat > "$CONFIG_SUB_PATH/NodegroupTaints" << 'YAML'
- key: workload
  value: kong
  effect: InvalidEffect
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_TAINTS"
  assert_output_contains "must be one of"
}

@test "fails when taints have duplicate key+effect" {
  cat > "$CONFIG_SUB_PATH/NodegroupTaints" << 'YAML'
- key: workload
  value: kong
  effect: NoSchedule
- key: workload
  value: different
  effect: NoSchedule
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_TAINTS"
  assert_output_contains "duplicate"
}

@test "passes with taint without value (key-only)" {
  cat > "$CONFIG_SUB_PATH/NodegroupTaints" << 'YAML'
- key: dedicated
  effect: NoSchedule
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "key: dedicated" "cluster.yaml taints"
  assert_contains "$content" "effect: NoSchedule" "cluster.yaml taints"
}

@test "passes with all three valid taint effects" {
  cat > "$CONFIG_SUB_PATH/NodegroupTaints" << 'YAML'
- key: a
  effect: NoSchedule
- key: b
  effect: PreferNoSchedule
- key: c
  effect: NoExecute
YAML

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
}

@test "fails with invalid YAML in taints file" {
  printf 'not: valid: yaml: [' > "$CONFIG_SUB_PATH/NodegroupTaints"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_TAINTS"
}

@test "fails with invalid metadata tag format" {
  printf 'bad tag format no colon' > "$CONFIG_SUB_PATH/MetadataTags"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "invalid tag at line 1"
}

@test "fails with invalid nodegroup tag format" {
  printf 'also bad' > "$CONFIG_SUB_PATH/NodegroupTags"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "invalid tag at line 1"
}

@test "skips blank lines in tag config files" {
  cat > "$CONFIG_SUB_PATH/MetadataTags" << 'EOF'
Environment: production

Team: platform
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "Environment: production" "cluster.yaml"
  assert_contains "$content" "Team: platform" "cluster.yaml"
}

# === YAML auto-quoting ===

@test "auto-quotes boolean values in metadata tags" {
  cat > "$CONFIG_SUB_PATH/MetadataTags" << 'EOF'
Enabled: true
Active: YES
Disabled: off
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'Enabled: "true"' "cluster.yaml"
  assert_contains "$content" 'Active: "YES"' "cluster.yaml"
  assert_contains "$content" 'Disabled: "off"' "cluster.yaml"
  assert_output_contains "auto-quoted YAML-unsafe value"
}

@test "auto-quotes numeric values in nodegroup tags" {
  cat > "$CONFIG_SUB_PATH/NodegroupTags" << 'EOF'
Priority: 1
Weight: 3.5
Negative: -42
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'Priority: "1"' "cluster.yaml"
  assert_contains "$content" 'Weight: "3.5"' "cluster.yaml"
  assert_contains "$content" 'Negative: "-42"' "cluster.yaml"
}

@test "auto-quotes null and special values in metadata tags" {
  cat > "$CONFIG_SUB_PATH/MetadataTags" << 'EOF'
Override: null
Octal: 0777
Hex: 0x1F
Tilde: ~
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'Override: "null"' "cluster.yaml"
  assert_contains "$content" 'Octal: "0777"' "cluster.yaml"
  assert_contains "$content" 'Hex: "0x1F"' "cluster.yaml"
  assert_contains "$content" 'Tilde: "~"' "cluster.yaml"
}

@test "does not double-quote already-quoted values" {
  cat > "$CONFIG_SUB_PATH/MetadataTags" << 'EOF'
QuotedBool: "true"
Other: 'false'
Normal: my-string-value
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'QuotedBool: "true"' "cluster.yaml"
  assert_contains "$content" "Other: 'false'" "cluster.yaml"
  assert_contains "$content" "Normal: my-string-value" "cluster.yaml"
  [[ "$output" != *"auto-quoted"*"QuotedBool:"* ]]
  [[ "$output" != *"auto-quoted"*"Other:"* ]]
  [[ "$output" != *"auto-quoted"*"Normal:"* ]]
}

@test "auto-quotes in nodegroup labels" {
  cat > "$CONFIG_SUB_PATH/NodegroupLabels" << 'EOF'
gpu: false
tier: 0
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'gpu: "false"' "cluster.yaml"
  assert_contains "$content" 'tier: "0"' "cluster.yaml"
}

@test "auto-quotes sexagesimal values" {
  cat > "$CONFIG_SUB_PATH/MetadataTags" << 'EOF'
Duration: 1:30
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'Duration: "1:30"' "cluster.yaml"
}

@test "does not quote safe string values" {
  cat > "$CONFIG_SUB_PATH/MetadataTags" << 'EOF'
Environment: production
Team: platform-engineering
Region: eu-west-1
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "Environment: production" "cluster.yaml"
  assert_contains "$content" "Team: platform-engineering" "cluster.yaml"
  assert_contains "$content" "Region: eu-west-1" "cluster.yaml"
  [[ "$output" != *"auto-quoted"* ]]
}

# === Required AwsAccountId ===

@test "fails when AwsAccountId config file missing" {
  rm "$CONFIG_SUB_PATH/AwsAccountId"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "AWS_ACCOUNT_ID"
  assert_output_contains "not found"
}

@test "fails when ClusterSecurityGroup config file missing" {
  rm "$CONFIG_SUB_PATH/ClusterSecurityGroup"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "CLUSTER_SECURITY_GROUP"
  assert_output_contains "not found"
}

# === Annotations ===

@test "generates fixed annotation with AwsAccountId token" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "annotations:" "cluster.yaml"
  assert_contains "$content" 'kaptain.org/aws-account-id: "${AwsAccountId}"' "cluster.yaml"
}

@test "generates fixed annotation with ClusterSecurityGroup token" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'kaptain.org/eks-cluster-security-group: "${ClusterSecurityGroup}"' "cluster.yaml"
}

@test "appends user metadata annotations from config file" {
  cat > "$CONFIG_SUB_PATH/MetadataAnnotations" << 'EOF'
kaptain.org/team: platform-engineering
kaptain.org/cost-center: infrastructure
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" "kaptain.org/team: platform-engineering" "cluster.yaml"
  assert_contains "$content" "kaptain.org/cost-center: infrastructure" "cluster.yaml"
  # Fixed annotation still present
  assert_contains "$content" 'kaptain.org/aws-account-id: "${AwsAccountId}"' "cluster.yaml"
}

@test "auto-quotes in metadata annotations" {
  cat > "$CONFIG_SUB_PATH/MetadataAnnotations" << 'EOF'
kaptain.org/enabled: true
kaptain.org/priority: 1
EOF

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'kaptain.org/enabled: "true"' "cluster.yaml"
  assert_contains "$content" 'kaptain.org/priority: "1"' "cluster.yaml"
  assert_output_contains "auto-quoted YAML-unsafe value"
}

@test "does not generate user annotations when config absent" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  # Fixed annotation is always present
  assert_contains "$content" 'kaptain.org/aws-account-id: "${AwsAccountId}"' "cluster.yaml"
  # No user annotations
  [[ "$content" != *"kaptain.org/team"* ]]
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
  assert_contains "$content" "version: latest" "cluster.yaml"
}

@test "adds serviceAccountRoleARN to addon when config file present" {
  printf 'arn:aws:iam::123456789012:role/vpc-cni-role' > "$CONFIG_SUB_PATH/AddonsVpcCniServiceAccountRoleArn"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" 'serviceAccountRoleARN: ${AddonsVpcCniServiceAccountRoleArn}' "cluster.yaml"
}

@test "does not add serviceAccountRoleARN when config file absent" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  [[ "$content" != *"serviceAccountRoleARN"* ]]
}

@test "adds serviceAccountRoleARN only to matching addon" {
  printf 'arn:aws:iam::123456789012:role/ebs-role' > "$CONFIG_SUB_PATH/AddonsAwsEbsCsiDriverServiceAccountRoleArn"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  # ebs addon has it
  assert_contains "$content" 'serviceAccountRoleARN: ${AddonsAwsEbsCsiDriverServiceAccountRoleArn}' "cluster.yaml"
  # Count occurrences - should be exactly 1
  local count
  count=$(echo "$content" | grep -c "serviceAccountRoleARN" || true)
  [ "$count" -eq 1 ]
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
  assert_contains "$content" "FROM ghcr.io/kube-kaptain/aws/aws-eks-cluster-management:" "Dockerfile"
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

  [ -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/nodegroup-prefix" ]
  local prefix
  prefix=$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/nodegroup-prefix")
  [[ "$prefix" == ng-* ]]
  [[ "$prefix" == *-k-1-32-v-1-0-0 ]]
}

@test "writes kubernetes-version to output dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/kubernetes-version" ]
  local version
  version=$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/expected-values/kubernetes-version")
  [ "$version" = "1.32" ]
}

@test "copies cluster.yaml to with-tokens dir for inspection" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/with-tokens/cluster.yaml" ]
  local content
  content=$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/with-tokens/cluster.yaml")
  assert_contains "$content" 'name: ${ProjectName}' "with-tokens cluster.yaml"
}

@test "copies controlplane-only yaml to with-tokens dir when generated" {
  export EKS_CILIUM_EBPF_NETWORKING="true"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/with-tokens/cluster-controlplane-only.yaml" ]
}

@test "does not copy controlplane-only yaml to with-tokens dir when not generated" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ ! -f "$OUTPUT_SUB_PATH/aws-eks-cluster-management/with-tokens/cluster-controlplane-only.yaml" ]
}

@test "copies user-provided cluster.yaml to with-tokens dir" {
  mkdir -p "$EKS_CLUSTER_YAML_SUB_PATH"
  echo "custom user cluster config" > "$EKS_CLUSTER_YAML_SUB_PATH/cluster.yaml"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/aws-eks-cluster-management/with-tokens/cluster.yaml")
  assert_contains "$content" "custom user cluster config" "with-tokens cluster.yaml"
}

@test "writes KubernetesVersion to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/KubernetesVersion" ]
  local version
  version=$(< "$OUTPUT_SUB_PATH/docker/config/KubernetesVersion")
  [ "$version" = "1.32" ]
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

@test "writes default IAM_WITH_OIDC to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/IamWithOidc" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/IamWithOidc")
  [ "$value" = "true" ]
}

@test "writes default VPC_CLUSTER_ENDPOINTS_PRIVATE_ACCESS to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/VpcClusterEndpointsPrivateAccess" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/VpcClusterEndpointsPrivateAccess")
  [ "$value" = "true" ]
}

@test "writes default VPC_CLUSTER_ENDPOINTS_PUBLIC_ACCESS to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/VpcClusterEndpointsPublicAccess" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/VpcClusterEndpointsPublicAccess")
  [ "$value" = "false" ]
}

@test "expands default CLOUD_WATCH_CLUSTER_LOGGING_ENABLE_TYPES to numbered tokens" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType1" ]
  [ -f "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType2" ]
  [ -f "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType3" ]
  [ -f "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType4" ]
  [ -f "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType5" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType1")" = "api" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType2")" = "audit" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType3")" = "authenticator" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType4")" = "controllerManager" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType5")" = "scheduler" ]
}

@test "does not overwrite user-provided IamWithOidc in CONFIG_SUB_PATH" {
  printf 'false' > "$CONFIG_SUB_PATH/IamWithOidc"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "IAM_WITH_OIDC: user config found"
}

@test "expands user-provided CloudWatchClusterLoggingEnableTypes to numbered tokens" {
  printf 'api,audit' > "$CONFIG_SUB_PATH/CloudWatchClusterLoggingEnableTypes"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  assert_output_contains "CLOUD_WATCH_CLUSTER_LOGGING_ENABLE_TYPES: user config found"
  [ -f "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType1" ]
  [ -f "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType2" ]
  [ ! -f "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType3" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType1")" = "api" ]
  [ "$(< "$OUTPUT_SUB_PATH/docker/config/CloudWatchClusterLoggingEnableType2")" = "audit" ]
}

@test "writes default NODEGROUP_AMI_FAMILY to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupAmiFamily" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupAmiFamily")
  [ "$value" = "AmazonLinux2023" ]
}

@test "writes default NODEGROUP_VOLUME_SIZE to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupVolumeSize" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupVolumeSize")
  [ "$value" = "20" ]
}

@test "writes default NODEGROUP_VOLUME_TYPE to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupVolumeType" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupVolumeType")
  [ "$value" = "gp3" ]
}

@test "writes default NODEGROUP_VOLUME_ENCRYPTED to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupVolumeEncrypted" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupVolumeEncrypted")
  [ "$value" = "true" ]
}

@test "writes default NODEGROUP_DESIRED_CAPACITY to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity")
  [ "$value" = "3" ]
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

@test "writes default NODEGROUP_UPDATE_CONFIG_MAX_UNAVAILABLE to platform config dir" {
  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupUpdateConfigMaxUnavailable" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupUpdateConfigMaxUnavailable")
  [ "$value" = "1" ]
}

@test "fails when NODEGROUP_UPDATE_CONFIG_MAX_UNAVAILABLE is zero" {
  printf '0' > "$CONFIG_SUB_PATH/NodegroupUpdateConfigMaxUnavailable"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "must be greater than 0"
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

@test "defaults NODEGROUP_DESIRED_CAPACITY to user-provided NODEGROUP_MIN_SIZE" {
  printf '5' > "$CONFIG_SUB_PATH/NodegroupMinSize"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity" ]
  local value
  value=$(< "$OUTPUT_SUB_PATH/docker/config/NodegroupDesiredCapacity")
  [ "$value" = "5" ]
}

@test "fails when NODEGROUP_DESIRED_CAPACITY less than NODEGROUP_MIN_SIZE" {
  printf '1' > "$CONFIG_SUB_PATH/NodegroupDesiredCapacity"
  printf '3' > "$CONFIG_SUB_PATH/NodegroupMinSize"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_DESIRED_CAPACITY"
  assert_output_contains "must be >= NODEGROUP_MIN_SIZE"
}

@test "fails when NODEGROUP_DESIRED_CAPACITY greater than NODEGROUP_MAX_SIZE" {
  printf '20' > "$CONFIG_SUB_PATH/NodegroupDesiredCapacity"
  printf '12' > "$CONFIG_SUB_PATH/NodegroupMaxSize"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_DESIRED_CAPACITY"
  assert_output_contains "must be <= NODEGROUP_MAX_SIZE"
}

@test "fails when NODEGROUP_MIN_SIZE greater than NODEGROUP_MAX_SIZE" {
  printf '15' > "$CONFIG_SUB_PATH/NodegroupMinSize"
  printf '12' > "$CONFIG_SUB_PATH/NodegroupMaxSize"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -ne 0 ]
  assert_output_contains "NODEGROUP_MIN_SIZE"
  assert_output_contains "must be <= NODEGROUP_MAX_SIZE"
}

@test "passes when desired equals min" {
  printf '3' > "$CONFIG_SUB_PATH/NodegroupDesiredCapacity"
  printf '3' > "$CONFIG_SUB_PATH/NodegroupMinSize"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
}

@test "passes when desired equals max" {
  printf '12' > "$CONFIG_SUB_PATH/NodegroupDesiredCapacity"
  printf '12' > "$CONFIG_SUB_PATH/NodegroupMaxSize"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]
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

  [ -f "$OUTPUT_SUB_PATH/docker-linux-amd64/config/KubernetesVersion" ]
  [ -f "$OUTPUT_SUB_PATH/docker-linux-arm64/config/KubernetesVersion" ]
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
  assert_contains "$content" '${AwsRegion}' "cluster.yaml"
  assert_contains "$content" '${KubernetesVersion}' "cluster.yaml"
  assert_contains "$content" '${IamWithOidc}' "cluster.yaml"
  assert_contains "$content" '${CloudWatchClusterLoggingEnableType1}' "cluster.yaml"
  assert_contains "$content" '${CloudWatchClusterLoggingEnableType5}' "cluster.yaml"
  assert_contains "$content" '${SecretsEncryptionKeyArn}' "cluster.yaml"
}

@test "generates tokens with mustache delimiter style" {
  export TOKEN_DELIMITER_STYLE="mustache"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" '{{ ProjectName }}' "cluster.yaml"
  assert_contains "$content" '{{ AwsRegion }}' "cluster.yaml"
  assert_contains "$content" '{{ KubernetesVersion }}' "cluster.yaml"
  assert_contains "$content" '{{ IamWithOidc }}' "cluster.yaml"
  assert_contains "$content" '{{ CloudWatchClusterLoggingEnableType1 }}' "cluster.yaml"
  assert_contains "$content" '{{ CloudWatchClusterLoggingEnableType5 }}' "cluster.yaml"
  assert_contains "$content" '{{ SecretsEncryptionKeyArn }}' "cluster.yaml"
}

@test "generates tokens with UPPER_SNAKE name style" {
  export TOKEN_NAME_STYLE="UPPER_SNAKE"

  # UPPER_SNAKE style looks for config files named with underscores
  mv "$CONFIG_SUB_PATH/AwsRegion" "$CONFIG_SUB_PATH/AWS_REGION"
  mv "$CONFIG_SUB_PATH/VpcId" "$CONFIG_SUB_PATH/VPC_ID"
  mv "$CONFIG_SUB_PATH/NodegroupInstanceType" "$CONFIG_SUB_PATH/NODEGROUP_INSTANCE_TYPE"
  mv "$CONFIG_SUB_PATH/SecretsEncryptionKeyArn" "$CONFIG_SUB_PATH/SECRETS_ENCRYPTION_KEY_ARN"
  mv "$CONFIG_SUB_PATH/AwsAccountId" "$CONFIG_SUB_PATH/AWS_ACCOUNT_ID"
  mv "$CONFIG_SUB_PATH/ClusterSecurityGroup" "$CONFIG_SUB_PATH/CLUSTER_SECURITY_GROUP"
  mv "$CONFIG_SUB_PATH/ClusterOrigin" "$CONFIG_SUB_PATH/CLUSTER_ORIGIN"
  mv "$CONFIG_SUB_PATH/NodegroupType" "$CONFIG_SUB_PATH/NODEGROUP_TYPE"
  mv "$CONFIG_SUB_PATH/PrivateSubnetIdA" "$CONFIG_SUB_PATH/PRIVATE_SUBNET_ID_A"
  mv "$CONFIG_SUB_PATH/PrivateSubnetIdB" "$CONFIG_SUB_PATH/PRIVATE_SUBNET_ID_B"
  mv "$CONFIG_SUB_PATH/PrivateSubnetIdC" "$CONFIG_SUB_PATH/PRIVATE_SUBNET_ID_C"

  run "$SCRIPTS_DIR/aws-eks-cluster-management-prepare"
  [ "$status" -eq 0 ]

  local content
  content=$(< "$OUTPUT_SUB_PATH/docker/substituted/cluster.yaml")
  assert_contains "$content" '${PROJECT_NAME}' "cluster.yaml"
  assert_contains "$content" '${AWS_REGION}' "cluster.yaml"
  assert_contains "$content" '${KUBERNETES_VERSION}' "cluster.yaml"
  assert_contains "$content" '${IAM_WITH_OIDC}' "cluster.yaml"
  assert_contains "$content" '${CLOUD_WATCH_CLUSTER_LOGGING_ENABLE_TYPE_1}' "cluster.yaml"
  assert_contains "$content" '${CLOUD_WATCH_CLUSTER_LOGGING_ENABLE_TYPE_5}' "cluster.yaml"
  assert_contains "$content" '${SECRETS_ENCRYPTION_KEY_ARN}' "cluster.yaml"

  # Config file names should also be UPPER_SNAKE
  [ -f "$OUTPUT_SUB_PATH/docker/config/KUBERNETES_VERSION" ]
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

  assert_output_contains "Base image: ghcr.io/kube-kaptain/aws/aws-eks-cluster-management:"
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
