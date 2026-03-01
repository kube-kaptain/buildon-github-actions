#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# aws-eks-cluster-management.bash - Defaults for EKS cluster management image preparation
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Base image parts (FROM line)
EKS_BASE_IMAGE_REGISTRY="${EKS_BASE_IMAGE_REGISTRY:-ghcr.io}"
EKS_BASE_IMAGE_NAMESPACE="${EKS_BASE_IMAGE_NAMESPACE:-kube-kaptain}"
EKS_BASE_IMAGE_NAME="${EKS_BASE_IMAGE_NAME:-aws/aws-eks-cluster-management}"
EKS_BASE_IMAGE_TAG="${EKS_BASE_IMAGE_TAG:-1.1}"

# Cluster config
KUBERNETES_MAJOR_VERSION="${KUBERNETES_MAJOR_VERSION:-1}"
# KUBERNETES_MINOR_VERSION - required, no default (validated by prepare script)

# Networking
EKS_PRIVATE_NETWORKING="${EKS_PRIVATE_NETWORKING:-true}"
EKS_PUBLIC_NETWORKING="${EKS_PUBLIC_NETWORKING:-false}"
EKS_CILIUM_EBPF_NETWORKING="${EKS_CILIUM_EBPF_NETWORKING:-false}"
EKS_CUSTOM_SECURITY_GROUP="${EKS_CUSTOM_SECURITY_GROUP:-false}"

# Nodegroup token defaults (written to platform config dir if not in CONFIG_SUB_PATH)
# NODEGROUP_INSTANCE_TYPE - required token from CONFIG_SUB_PATH, no default
NODEGROUP_DESIRED_CAPACITY="${NODEGROUP_DESIRED_CAPACITY:-1}" # start with 1 faster completion of upgrade/creation - let it scale up as workloads migrate
NODEGROUP_MIN_SIZE="${NODEGROUP_MIN_SIZE:-3}"
NODEGROUP_MAX_SIZE="${NODEGROUP_MAX_SIZE:-12}"

# Addons (comma-separated, no versions ever)
EKS_ADDONS_LIST="${EKS_ADDONS_LIST:-coredns,kube-proxy,vpc-cni,aws-ebs-csi-driver,aws-efs-csi-driver}"

# Override buildon default platform (amd64 only) with both architectures
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64,linux/arm64}"

# Source locations in consuming repo
EKS_CLUSTER_YAML_SUB_PATH="${EKS_CLUSTER_YAML_SUB_PATH:-src/eks}"
SECRETS_SUB_PATH="${SECRETS_SUB_PATH:-src/secrets}"
