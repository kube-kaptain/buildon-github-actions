#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-workload-deployment

load helpers

setup() {
  export TEST_DIR=$(mktemp -d)
  export OUTPUT_SUB_PATH=$(mktemp -d)
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"

  # Create test directory structure
  mkdir -p "${TEST_DIR}/src/kubernetes"
  mkdir -p "${TEST_DIR}/src/workload-env"

  cd "${TEST_DIR}"
}

teardown() {
  rm -rf "$TEST_DIR"
  rm -rf "$OUTPUT_SUB_PATH"
}

# Helper to create env file
create_env_file() {
  local filename="$1"
  local content="$2"
  printf '%s' "$content" > "${TEST_DIR}/src/workload-env/$filename"
}

# Helper to create suffixed env directory
create_env_file_with_suffix() {
  local suffix="$1"
  local filename="$2"
  local content="$3"
  mkdir -p "${TEST_DIR}/src/workload-${suffix}-env"
  printf '%s' "$content" > "${TEST_DIR}/src/workload-${suffix}-env/$filename"
}

# Helper to read generated manifest
read_manifest() {
  cat "$OUTPUT_SUB_PATH/manifests/combined/deployment.yaml"
}

# Helper to read suffixed manifest
read_manifest_with_suffix() {
  local suffix="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/deployment-${suffix}.yaml"
}

# =============================================================================
# Basic structure
# =============================================================================

@test "generates valid Deployment structure" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"apiVersion: apps/v1"* ]]
  [[ "$manifest" == *"kind: Deployment"* ]]
  [[ "$manifest" == *'name: ${ProjectName}'* ]]
  [[ "$manifest" == *'namespace: ${Environment}'* ]]
}

@test "includes standard labels" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"labels:"* ]]
  [[ "$manifest" == *'app: ${ProjectName}'* ]]
  [[ "$manifest" == *'app.kubernetes.io/name: ${ProjectName}'* ]]
  [[ "$manifest" == *'app.kubernetes.io/version: ${Version}'* ]]
  [[ "$manifest" == *"app.kubernetes.io/managed-by: kaptain"* ]]
}

@test "includes kaptain annotations" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"annotations:"* ]]
  [[ "$manifest" == *'kaptain/project-name: ${ProjectName}'* ]]
  [[ "$manifest" == *'kaptain/version: ${Version}'* ]]
  [[ "$manifest" == *"kaptain/build-timestamp:"* ]]
  [[ "$manifest" == *"kubectl.kubernetes.io/default-container: default-app"* ]]
}

# =============================================================================
# Container configuration
# =============================================================================

@test "generates container with correct image reference" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"name: default-app"* ]]
  [[ "$manifest" == *'image: ${EnvironmentRegistry}/${EnvironmentRegistryBasePath}/${DockerImageName}:${DockerTag}'* ]]
  [[ "$manifest" == *"imagePullPolicy: IfNotPresent"* ]]
}

@test "generates container port" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"ports:"* ]]
  [[ "$manifest" == *'containerPort: ${KubernetesContainerPort}'* ]]
  [[ "$manifest" == *"protocol: TCP"* ]]
}

# =============================================================================
# Security context
# =============================================================================

@test "generates secure defaults" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"runAsNonRoot: true"* ]]
  [[ "$manifest" == *"allowPrivilegeEscalation: false"* ]]
  [[ "$manifest" == *"readOnlyRootFilesystem: true"* ]]
  [[ "$manifest" == *"drop:"* ]]
  [[ "$manifest" == *"- ALL"* ]]
  # seccompProfile omitted by default (DISABLED)
  [[ "$manifest" != *"seccompProfile:"* ]]
}

@test "includes seccomp profile when configured" {
  export KUBERNETES_WORKLOAD_SECCOMP_PROFILE="RuntimeDefault"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"seccompProfile:"* ]]
  [[ "$manifest" == *"type: RuntimeDefault"* ]]
}

@test "rejects invalid seccomp profile" {
  export KUBERNETES_WORKLOAD_SECCOMP_PROFILE="invalid"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -ne 0 ]
  assert_output_contains "KUBERNETES_WORKLOAD_SECCOMP_PROFILE must be"
}

@test "allows disabling readonly root filesystem" {
  export KUBERNETES_WORKLOAD_READONLY_ROOT_FILESYSTEM="false"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"readOnlyRootFilesystem: false"* ]]
}

# =============================================================================
# Resources
# =============================================================================

@test "generates resource requests and limits" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"resources:"* ]]
  [[ "$manifest" == *"requests:"* ]]
  [[ "$manifest" == *'memory: ${KubernetesMemory}'* ]]
  [[ "$manifest" == *'cpu: ${KubernetesCpuRequest}'* ]]
  [[ "$manifest" == *"limits:"* ]]
}

@test "omits CPU limit by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # Should not have cpu under limits
  # The memory limit should be there, but not cpu
  [[ "$manifest" == *"limits:"* ]]
  # Check that limits section only has memory (no cpu: line)
  limits_section=$(echo "$manifest" | grep -A5 "limits:")
  [[ "$limits_section" != *"cpu:"* ]]
}

@test "includes CPU limit when configured" {
  export KUBERNETES_WORKLOAD_RESOURCES_CPU_LIMIT="500m"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'cpu: 500m'* ]]
}

# =============================================================================
# Replicas and scaling
# =============================================================================

@test "generates default replicas" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'replicas: ${EnvironmentDefaultReplicaCount}'* ]]
}

@test "omits replicas when set to NO" {
  export KUBERNETES_DEPLOYMENT_REPLICAS="NO"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"replicas:"* ]]
}

@test "generates revision history limit" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"revisionHistoryLimit: 10"* ]]
}

# =============================================================================
# Update strategy
# =============================================================================

@test "generates zero-downtime update strategy" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"strategy:"* ]]
  [[ "$manifest" == *"type: RollingUpdate"* ]]
  [[ "$manifest" == *"maxSurge: 1"* ]]
  [[ "$manifest" == *"maxUnavailable: 0"* ]]
}

# =============================================================================
# Probes
# =============================================================================

@test "generates liveness probe with http-get by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"httpGet:"* ]]
  [[ "$manifest" == *"path: /liveness"* ]]
  [[ "$manifest" == *"initialDelaySeconds: 10"* ]]
  [[ "$manifest" == *"periodSeconds: 10"* ]]
}

@test "generates readiness probe with http-get by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"readinessProbe:"* ]]
  [[ "$manifest" == *"path: /readiness"* ]]
  [[ "$manifest" == *"initialDelaySeconds: 5"* ]]
}

@test "generates startup probe with http-get by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"startupProbe:"* ]]
  [[ "$manifest" == *"path: /startup"* ]]
  [[ "$manifest" == *"initialDelaySeconds: 0"* ]]
  [[ "$manifest" == *"failureThreshold: 30"* ]]
}

@test "generates tcp-socket probe when configured" {
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_CHECK_TYPE="tcp-socket"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"tcpSocket:"* ]]
  [[ "$manifest" == *"port: 1024"* ]]
}

@test "generates exec probe when configured" {
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_CHECK_TYPE="exec"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_EXEC_COMMAND="pg_isready -U postgres"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"exec:"* ]]
  [[ "$manifest" == *"command:"* ]]
  [[ "$manifest" == *"- /bin/sh"* ]]
  [[ "$manifest" == *"- -c"* ]]
  [[ "$manifest" == *"- pg_isready -U postgres"* ]]
}

@test "generates grpc probe when configured" {
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_CHECK_TYPE="grpc"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_GRPC_PORT="50051"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_GRPC_SERVICE="myapp.Health"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"grpc:"* ]]
  [[ "$manifest" == *"port: 50051"* ]]
  [[ "$manifest" == *"service: myapp.Health"* ]]
}

# =============================================================================
# Termination and lifecycle
# =============================================================================

@test "generates termination grace period" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'terminationGracePeriodSeconds: 10'* ]]
}

@test "omits preStop hook by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"lifecycle:"* ]]
  [[ "$manifest" != *"preStop:"* ]]
}

@test "includes preStop hook when configured" {
  export KUBERNETES_WORKLOAD_PRESTOP_COMMAND="sleep 5"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"lifecycle:"* ]]
  [[ "$manifest" == *"preStop:"* ]]
  [[ "$manifest" == *"exec:"* ]]
  [[ "$manifest" == *"- sleep 5"* ]]
}

# =============================================================================
# Affinity
# =============================================================================

@test "generates default affinity strategy" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]]
  [[ "$manifest" == *"podAntiAffinity:"* ]]
  [[ "$manifest" == *"preferredDuringSchedulingIgnoredDuringExecution:"* ]]
  [[ "$manifest" == *"weight: 100"* ]]
  [[ "$manifest" == *"weight: 50"* ]]
}

@test "omits affinity when strategy is none" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="none"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"affinity:"* ]]
}

@test "rejects unknown affinity strategy" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="invalid-strategy"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown affinity strategy"
}

# =============================================================================
# Volume mounts
# =============================================================================

@test "includes configmap volume when detected" {
  touch "${TEST_DIR}/src/kubernetes/configmap.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"volumeMounts:"* ]]
  [[ "$manifest" == *"name: configmap"* ]]
  [[ "$manifest" == *'mountPath: ${KubernetesConfigmapMountPath}'* ]]
  [[ "$manifest" == *"readOnly: true"* ]]
  [[ "$manifest" == *"volumes:"* ]]
  [[ "$manifest" == *"configMap:"* ]]
  [[ "$manifest" == *'name: ${ProjectName}-configmap-checksum'* ]]
}

@test "includes secret volume when detected" {
  touch "${TEST_DIR}/src/kubernetes/secret.template.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"volumeMounts:"* ]]
  [[ "$manifest" == *"name: secret"* ]]
  [[ "$manifest" == *'mountPath: ${KubernetesSecretMountPath}'* ]]
  [[ "$manifest" == *"volumes:"* ]]
  [[ "$manifest" == *"secret:"* ]]
  [[ "$manifest" == *'secretName: ${ProjectName}-secret-checksum'* ]]
}

@test "omits volumes when not detected" {
  # No configmap.yaml or secret.template.yaml files exist by default
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"volumeMounts:"* ]]
  [[ "$manifest" != *"volumes:"* ]] || [[ "$manifest" == *"volumes:"*"imagePullSecrets:"* ]]
}

# =============================================================================
# Environment variables
# =============================================================================

@test "includes environment variables from workload-env" {
  create_env_file "DATABASE_HOST" "db.example.com"
  create_env_file "LOG_LEVEL" "info"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"env:"* ]]
  [[ "$manifest" == *"- name: DATABASE_HOST"* ]]
  [[ "$manifest" == *'value: "db.example.com"'* ]]
  [[ "$manifest" == *"- name: LOG_LEVEL"* ]]
  [[ "$manifest" == *'value: "info"'* ]]
}

@test "omits env section when workload-env is empty" {
  rm -rf "${TEST_DIR}/src/workload-env"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"env:"* ]] || [[ "$manifest" == *"env:"*"volumeMounts:"* ]]
}

# =============================================================================
# ServiceAccount
# =============================================================================

@test "includes serviceAccountName when serviceaccount detected" {
  touch "${TEST_DIR}/src/kubernetes/serviceaccount.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'serviceAccountName: ${ProjectName}'* ]]
  [[ "$manifest" == *"automountServiceAccountToken: false"* ]]
}

@test "includes serviceAccountName when detected in combined output" {
  rm -f "${TEST_DIR}/src/kubernetes/serviceaccount.yaml"
  # Simulate earlier generator having created serviceaccount in combined output
  mkdir -p "${OUTPUT_SUB_PATH}/manifests/combined"
  touch "${OUTPUT_SUB_PATH}/manifests/combined/serviceaccount.yaml"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'serviceAccountName: ${ProjectName}'* ]]
}

# =============================================================================
# Image pull secrets
# =============================================================================

@test "includes imagePullSecrets" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"imagePullSecrets:"* ]]
  [[ "$manifest" == *'- name: ${EnvironmentDockerRegistry}'* ]]
}

# =============================================================================
# Suffix and combined path
# =============================================================================

@test "generates suffixed deployment" {
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="worker"
  create_env_file_with_suffix "worker" "WORKER_ID" "1"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/combined/deployment-worker.yaml" ]
  manifest=$(read_manifest_with_suffix "worker")
  [[ "$manifest" == *'name: ${ProjectName}-worker'* ]]
}

@test "generates deployment in combined sub-path" {
  export KUBERNETES_WORKLOAD_COMBINED_SUB_PATH="services/backend"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/combined/services/backend/deployment.yaml" ]
}

# =============================================================================
# Token styles
# =============================================================================

@test "respects PascalCase token style" {
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${ProjectName}'* ]]
  [[ "$manifest" == *'${Environment}'* ]]
}

@test "respects camelCase token style" {
  export TOKEN_NAME_STYLE="camelCase"
  export TOKEN_DELIMITER_STYLE="shell"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${projectName}'* ]]
  [[ "$manifest" == *'${environment}'* ]]
}

@test "respects mustache delimiter style" {
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="mustache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'{{ ProjectName }}'* ]]
  [[ "$manifest" == *'{{ Environment }}'* ]]
}

# =============================================================================
# Validation
# =============================================================================

@test "fails when PROJECT_NAME is missing" {
  unset PROJECT_NAME

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME is required"
}

@test "fails with unknown token name style" {
  export TOKEN_NAME_STYLE="InvalidStyle"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown token name style"
}

@test "fails with unknown token delimiter style" {
  export TOKEN_DELIMITER_STYLE="invalid"

  run "$GENERATORS_DIR/generate-kubernetes-workload-deployment"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown substitution token style"
}
