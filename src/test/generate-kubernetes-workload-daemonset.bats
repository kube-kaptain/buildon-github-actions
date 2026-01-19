#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-workload-daemonset

load helpers

setup() {
  local base_dir=$(create_test_dir "gen-daemonset")
  export TEST_DIR="$base_dir/workspace"
  export OUTPUT_SUB_PATH="$base_dir/target"
  mkdir -p "$TEST_DIR" "$OUTPUT_SUB_PATH"
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"

  # Create test directory structure
  mkdir -p "${TEST_DIR}/src/kubernetes"
  mkdir -p "${TEST_DIR}/src/daemonset-env"

  cd "${TEST_DIR}"
}

teardown() {
  :
}

# Helper to read generated manifest
read_manifest() {
  cat "$OUTPUT_SUB_PATH/manifests/combined/daemonset.yaml"
}

# Helper to read suffixed manifest
read_suffixed_manifest() {
  local suffix="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/daemonset-${suffix}.yaml"
}

# Helper to read manifest with combined sub-path
read_combined_manifest() {
  local path="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/${path}/daemonset.yaml"
}

# =============================================================================
# Basic structure
# =============================================================================

@test "generates valid DaemonSet structure" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "apiVersion: apps/v1"
  assert_contains "$manifest" "kind: DaemonSet"
  assert_contains "$manifest" "name: \${ProjectName}"
}

@test "does not include replicas field" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # DaemonSets don't have replicas
  [[ "$manifest" != *"replicas:"* ]]
}

@test "does not include revisionHistoryLimit field" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # DaemonSets don't use revisionHistoryLimit
  [[ "$manifest" != *"revisionHistoryLimit:"* ]]
}

# =============================================================================
# Update strategy
# =============================================================================

@test "uses RollingUpdate strategy by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "updateStrategy:"
  assert_contains "$manifest" "type: RollingUpdate"
  assert_contains "$manifest" "maxUnavailable: 1"
}

@test "supports custom maxUnavailable in RollingUpdate" {
  export KUBERNETES_DAEMONSET_MAX_UNAVAILABLE="2"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "maxUnavailable: 2"
}

@test "supports percentage for maxUnavailable" {
  export KUBERNETES_DAEMONSET_MAX_UNAVAILABLE="10%"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "maxUnavailable: 10%"
}

@test "supports OnDelete update strategy" {
  export KUBERNETES_DAEMONSET_UPDATE_STRATEGY_TYPE="OnDelete"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "type: OnDelete"
  # OnDelete doesn't have rollingUpdate section
  [[ "$manifest" != *"maxUnavailable:"* ]]
}

@test "rejects invalid update strategy type" {
  export KUBERNETES_DAEMONSET_UPDATE_STRATEGY_TYPE="Invalid"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 4 ]
}

# =============================================================================
# Host namespace settings
# =============================================================================

@test "host network is false by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"hostNetwork: true"* ]]
}

@test "can enable host network" {
  export KUBERNETES_DAEMONSET_HOST_NETWORK="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "hostNetwork: true"
}

@test "auto-sets dnsPolicy when hostNetwork is enabled" {
  export KUBERNETES_DAEMONSET_HOST_NETWORK="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "dnsPolicy: ClusterFirstWithHostNet"
}

@test "can enable host PID namespace" {
  export KUBERNETES_DAEMONSET_HOST_PID="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "hostPID: true"
}

@test "can enable host IPC namespace" {
  export KUBERNETES_DAEMONSET_HOST_IPC="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "hostIPC: true"
}

@test "can enable all host namespaces" {
  export KUBERNETES_DAEMONSET_HOST_NETWORK="true"
  export KUBERNETES_DAEMONSET_HOST_PID="true"
  export KUBERNETES_DAEMONSET_HOST_IPC="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "hostNetwork: true"
  assert_contains "$manifest" "hostPID: true"
  assert_contains "$manifest" "hostIPC: true"
}

# =============================================================================
# DNS policy
# =============================================================================

@test "can set explicit DNS policy" {
  export KUBERNETES_DAEMONSET_DNS_POLICY="Default"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "dnsPolicy: Default"
}

@test "explicit DNS policy overrides auto-set" {
  export KUBERNETES_DAEMONSET_HOST_NETWORK="true"
  export KUBERNETES_DAEMONSET_DNS_POLICY="ClusterFirst"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "dnsPolicy: ClusterFirst"
  [[ "$manifest" != *"dnsPolicy: ClusterFirstWithHostNet"* ]]
}

@test "rejects invalid DNS policy" {
  export KUBERNETES_DAEMONSET_DNS_POLICY="Invalid"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 4 ]
}

# =============================================================================
# Security context - run as non-root
# =============================================================================

@test "runs as non-root by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "runAsNonRoot: true"
}

@test "can allow root access" {
  export KUBERNETES_DAEMONSET_RUN_AS_NON_ROOT="false"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "runAsNonRoot: false"
}

@test "drops capabilities when running as non-root" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "capabilities:"
  assert_contains "$manifest" "drop:"
  assert_contains "$manifest" "- ALL"
}

@test "does not drop capabilities when root allowed" {
  export KUBERNETES_DAEMONSET_RUN_AS_NON_ROOT="false"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # Capabilities are not dropped when root is allowed (may need them)
  [[ "$manifest" != *"drop:"* ]]
}

# =============================================================================
# Security context - privileged mode
# =============================================================================

@test "is not privileged by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"privileged: true"* ]]
  assert_contains "$manifest" "allowPrivilegeEscalation: false"
}

@test "can enable privileged mode" {
  export KUBERNETES_DAEMONSET_PRIVILEGED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "privileged: true"
  # When privileged, allowPrivilegeEscalation is implicit
  [[ "$manifest" != *"allowPrivilegeEscalation:"* ]]
}

# =============================================================================
# Node selector
# =============================================================================

@test "no node selector by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"nodeSelector:"* ]]
}

@test "supports single node selector" {
  export KUBERNETES_DAEMONSET_NODE_SELECTOR="node-role.kubernetes.io/worker=true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "nodeSelector:"
  assert_contains "$manifest" "node-role.kubernetes.io/worker:"
}

@test "supports multiple node selectors" {
  export KUBERNETES_DAEMONSET_NODE_SELECTOR="node-role.kubernetes.io/worker=true,disk=ssd"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "nodeSelector:"
  assert_contains "$manifest" "node-role.kubernetes.io/worker:"
  assert_contains "$manifest" "disk:"
}

# =============================================================================
# Tolerations
# =============================================================================

@test "no tolerations by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"tolerations:"* ]]
}

@test "supports tolerations JSON" {
  export KUBERNETES_DAEMONSET_TOLERATIONS='[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]'

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "tolerations:"
  assert_contains "$manifest" "key: node-role.kubernetes.io/control-plane"
  assert_contains "$manifest" "operator: Exists"
  assert_contains "$manifest" "effect: NoSchedule"
}

# =============================================================================
# Min ready seconds
# =============================================================================

@test "does not include minReadySeconds when 0" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"minReadySeconds:"* ]]
}

@test "includes minReadySeconds when non-zero" {
  export KUBERNETES_DAEMONSET_MIN_READY_SECONDS="30"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "minReadySeconds: 30"
}

# =============================================================================
# Labels with suffix and path
# =============================================================================

@test "labels use full resource name with suffix" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="agent"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_suffixed_manifest "agent")
  assert_contains "$manifest" "app: \${ProjectName}-agent"
  assert_contains "$manifest" "app.kubernetes.io/name: \${ProjectName}-agent"
}

@test "labels use full resource name with combined sub-path" {
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="monitoring/node"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_combined_manifest "monitoring/node")
  assert_contains "$manifest" "app: \${ProjectName}-monitoring-node"
  assert_contains "$manifest" "app.kubernetes.io/name: \${ProjectName}-monitoring-node"
}

@test "selector uses full resource name with suffix" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="agent"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_suffixed_manifest "agent")
  assert_contains "$manifest" "matchLabels:"
  [[ "$manifest" == *"selector:"*"matchLabels:"*"app: \${ProjectName}-agent"* ]]
}

# =============================================================================
# ConfigMap and Secret detection
# =============================================================================

@test "mounts configmap when detected" {
  cat > "${TEST_DIR}/src/kubernetes/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
data:
  KEY: value
EOF

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "- name: configmap"
  assert_contains "$manifest" "mountPath: /configmap"
}

@test "mounts secret when detected" {
  cat > "${TEST_DIR}/src/kubernetes/secret.template.yaml" << 'EOF'
apiVersion: v1
kind: Secret
stringData:
  SECRET: value
EOF

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "- name: secret"
  assert_contains "$manifest" "mountPath: /secret"
}

# =============================================================================
# Token styles
# =============================================================================

@test "uses mustache token style" {
  export TOKEN_DELIMITER_STYLE="mustache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # Mustache style uses spaces: {{ name }}
  assert_contains "$manifest" "name: {{ ProjectName }}"
}

@test "uses kebab-case token names" {
  export TOKEN_NAME_STYLE="lower-kebab"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "name: \${project-name}"
}

# =============================================================================
# Validation errors
# =============================================================================

@test "rejects invalid boolean for host network" {
  export KUBERNETES_DAEMONSET_HOST_NETWORK="yes"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 4 ]
}

@test "rejects invalid boolean for run as non-root" {
  export KUBERNETES_DAEMONSET_RUN_AS_NON_ROOT="yes"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 4 ]
}

@test "rejects invalid boolean for privileged" {
  export KUBERNETES_DAEMONSET_PRIVILEGED="1"

  run "$GENERATORS_DIR/generate-kubernetes-workload-daemonset"
  [ "$status" -eq 4 ]
}
