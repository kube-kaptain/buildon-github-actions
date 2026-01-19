#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-workload-statefulset

load helpers

setup() {
  local base_dir=$(create_test_dir "gen-statefulset")
  export TEST_DIR="$base_dir/workspace"
  export OUTPUT_SUB_PATH="$base_dir/target"
  mkdir -p "$TEST_DIR" "$OUTPUT_SUB_PATH"
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"

  # Create test directory structure
  mkdir -p "${TEST_DIR}/src/kubernetes"
  mkdir -p "${TEST_DIR}/src/statefulset-env"

  cd "${TEST_DIR}"
}

teardown() {
  :
}

# Helper to read generated manifest
read_manifest() {
  cat "$OUTPUT_SUB_PATH/manifests/combined/statefulset.yaml"
}

# Helper to read suffixed manifest
read_suffixed_manifest() {
  local suffix="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/statefulset-${suffix}.yaml"
}

# Helper to read manifest with combined sub-path
read_combined_manifest() {
  local path="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/${path}/statefulset.yaml"
}

# Helper to read manifest with combined sub-path and suffix
read_combined_suffixed_manifest() {
  local path="$1"
  local suffix="$2"
  cat "$OUTPUT_SUB_PATH/manifests/combined/${path}/statefulset-${suffix}.yaml"
}

# =============================================================================
# Basic structure
# =============================================================================

@test "generates valid StatefulSet structure" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "apiVersion: apps/v1"
  assert_contains "$manifest" "kind: StatefulSet"
  assert_contains "$manifest" "name: \${ProjectName}"
}

@test "generates headless service" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/combined/service-headless.yaml" ]
  service=$(cat "$OUTPUT_SUB_PATH/manifests/combined/service-headless.yaml")
  assert_contains "$service" "clusterIP: None"
}

@test "statefulset references headless service" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "serviceName: \${ProjectName}-headless"
}

# =============================================================================
# Labels and selectors with suffix/path - THESE SHOULD FAIL UNTIL FIXED
# =============================================================================

@test "labels use full resource name with suffix" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_suffixed_manifest "cache")
  # Labels should include the suffix
  assert_contains "$manifest" "app: \${ProjectName}-cache"
  assert_contains "$manifest" "app.kubernetes.io/name: \${ProjectName}-cache"
}

@test "labels use full resource name with combined sub-path" {
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="backend/redis"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_combined_manifest "backend/redis")
  # Labels should include the path
  assert_contains "$manifest" "app: \${ProjectName}-backend-redis"
  assert_contains "$manifest" "app.kubernetes.io/name: \${ProjectName}-backend-redis"
}

@test "labels use full resource name with suffix and combined sub-path" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="backend/redis"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_combined_suffixed_manifest "backend/redis" "cache")
  # Labels should include both path and suffix
  assert_contains "$manifest" "app: \${ProjectName}-backend-redis-cache"
  assert_contains "$manifest" "app.kubernetes.io/name: \${ProjectName}-backend-redis-cache"
}

@test "selector uses full resource name with suffix" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_suffixed_manifest "cache")
  # Selector matchLabels should use full name
  assert_contains "$manifest" "matchLabels:"
  # The selector's app label should match the full resource name
  # Check for the pattern in selector context
  [[ "$manifest" == *"selector:"*"matchLabels:"*"app: \${ProjectName}-cache"* ]]
}

@test "kaptain/project-name annotation uses only project name" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="backend/redis"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_combined_suffixed_manifest "backend/redis" "cache")
  # kaptain/project-name should NOT include suffix/path
  assert_contains "$manifest" "kaptain/project-name: \${ProjectName}"
  # But should NOT contain the full path in this annotation
  [[ "$manifest" != *"kaptain/project-name: \${ProjectName}-backend"* ]]
}

# =============================================================================
# Affinity with suffix/path - SHOULD FAIL UNTIL FIXED
# =============================================================================

@test "affinity uses full resource name with suffix" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_suffixed_manifest "cache")
  # Affinity matchLabels should use full name
  assert_contains "$manifest" "podAntiAffinity:"
  # The affinity's app label should match the full resource name
  [[ "$manifest" == *"affinity:"*"matchLabels:"*"app: \${ProjectName}-cache"* ]]
}

# =============================================================================
# PVC volume mount - SHOULD FAIL UNTIL FIXED
# =============================================================================

@test "PVC volume mount is inside volumeMounts section without configmap/secret" {
  # No configmap or secret, just PVC
  export KUBERNETES_STATEFULSET_PVC_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # Volume mount should be properly indented inside volumeMounts
  # The pattern should show volumeMounts: followed by the PVC mount entry
  assert_contains "$manifest" "volumeMounts:"
  # Check that the mount appears AFTER volumeMounts header with proper indentation
  # This regex checks for volumeMounts followed eventually by the data mount
  [[ "$manifest" == *"volumeMounts:"*"- name: \${ProjectName}-data"*"mountPath: /data"* ]]
}

@test "PVC volume mount appears with configmap and secret mounts" {
  # Create configmap and secret
  cat > "${TEST_DIR}/src/kubernetes/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
data:
  KEY: value
EOF
  cat > "${TEST_DIR}/src/kubernetes/secret.template.yaml" << 'EOF'
apiVersion: v1
kind: Secret
stringData:
  SECRET: value
EOF

  export KUBERNETES_STATEFULSET_PVC_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # All three mounts should be present
  assert_contains "$manifest" "- name: configmap"
  assert_contains "$manifest" "- name: secret"
  assert_contains "$manifest" "- name: \${ProjectName}-data"
}

# =============================================================================
# Headless service naming with suffix/path
# =============================================================================

@test "headless service name includes suffix" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  # Service file should be named correctly
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/service-cache-headless.yaml" ]

  service=$(cat "$OUTPUT_SUB_PATH/manifests/combined/service-cache-headless.yaml")
  assert_contains "$service" "name: \${ProjectName}-cache-headless"

  manifest=$(read_suffixed_manifest "cache")
  assert_contains "$manifest" "serviceName: \${ProjectName}-cache-headless"
}

@test "headless service name includes combined sub-path" {
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="backend/redis"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  # Service file should be in subdirectory
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/backend/redis/service-headless.yaml" ]

  service=$(cat "$OUTPUT_SUB_PATH/manifests/combined/backend/redis/service-headless.yaml")
  assert_contains "$service" "name: \${ProjectName}-backend-redis-headless"

  manifest=$(read_combined_manifest "backend/redis")
  assert_contains "$manifest" "serviceName: \${ProjectName}-backend-redis-headless"
}

# =============================================================================
# ConfigMap/Secret name references with suffix/path
# =============================================================================

@test "configmap name uses full resource name with suffix" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"
  mkdir -p "${TEST_DIR}/src/kubernetes"
  touch "${TEST_DIR}/src/kubernetes/configmap-cache.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_suffixed_manifest "cache")
  # ConfigMap reference should include the suffix in the resource name
  assert_contains "$manifest" 'name: ${ProjectName}-cache-configmap-checksum'
}

@test "secret name uses full resource name with suffix" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"
  mkdir -p "${TEST_DIR}/src/kubernetes"
  touch "${TEST_DIR}/src/kubernetes/secret-cache.template.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_suffixed_manifest "cache")
  # Secret reference should include the suffix in the resource name
  assert_contains "$manifest" 'secretName: ${ProjectName}-cache-secret-checksum'
}

@test "configmap name uses full resource name with combined sub-path" {
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="backend/redis"
  mkdir -p "${TEST_DIR}/src/kubernetes/backend/redis"
  touch "${TEST_DIR}/src/kubernetes/backend/redis/configmap.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_combined_manifest "backend/redis")
  # ConfigMap reference should include the path in the resource name
  assert_contains "$manifest" 'name: ${ProjectName}-backend-redis-configmap-checksum'
}

@test "secret name uses full resource name with combined sub-path" {
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="backend/redis"
  mkdir -p "${TEST_DIR}/src/kubernetes/backend/redis"
  touch "${TEST_DIR}/src/kubernetes/backend/redis/secret.template.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_combined_manifest "backend/redis")
  # Secret reference should include the path in the resource name
  assert_contains "$manifest" 'secretName: ${ProjectName}-backend-redis-secret-checksum'
}

@test "configmap name uses full resource name with suffix and combined sub-path" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="backend/redis"
  mkdir -p "${TEST_DIR}/src/kubernetes/backend/redis"
  touch "${TEST_DIR}/src/kubernetes/backend/redis/configmap-cache.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_combined_suffixed_manifest "backend/redis" "cache")
  # ConfigMap reference should include both path and suffix in the resource name
  assert_contains "$manifest" 'name: ${ProjectName}-backend-redis-cache-configmap-checksum'
}

@test "secret name uses full resource name with suffix and combined sub-path" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="cache"
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="backend/redis"
  mkdir -p "${TEST_DIR}/src/kubernetes/backend/redis"
  touch "${TEST_DIR}/src/kubernetes/backend/redis/secret-cache.template.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_combined_suffixed_manifest "backend/redis" "cache")
  # Secret reference should include both path and suffix in the resource name
  assert_contains "$manifest" 'secretName: ${ProjectName}-backend-redis-cache-secret-checksum'
}

# =============================================================================
# Tolerations
# =============================================================================

@test "no tolerations by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"tolerations:"* ]]
}

@test "supports tolerations JSON" {
  export KUBERNETES_WORKLOAD_TOLERATIONS='[{"key":"dedicated","operator":"Equal","value":"database","effect":"NoSchedule"}]'

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "tolerations:"
  assert_contains "$manifest" "key: dedicated"
  assert_contains "$manifest" "operator: Equal"
  assert_contains "$manifest" "value: database"
  assert_contains "$manifest" "effect: NoSchedule"
}

@test "supports multiple tolerations" {
  export KUBERNETES_WORKLOAD_TOLERATIONS='[{"key":"dedicated","operator":"Equal","value":"db","effect":"NoSchedule"},{"key":"high-memory","operator":"Exists"}]'

  run "$GENERATORS_DIR/generate-kubernetes-workload-statefulset"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  assert_contains "$manifest" "tolerations:"
  assert_contains "$manifest" "key: dedicated"
  assert_contains "$manifest" "key: high-memory"
}
