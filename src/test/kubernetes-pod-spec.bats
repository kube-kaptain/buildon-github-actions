#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-pod-spec.bash library

load helpers

setup() {
  source "$LIB_DIR/kubernetes-pod-spec.bash"
}

# =============================================================================
# generate_pod_security_context
# =============================================================================

@test "generate_pod_security_context: basic with DISABLED seccomp" {
  run generate_pod_security_context 6 "DISABLED"
  [ "$status" -eq 0 ]
  [[ "$output" == *"      securityContext:"* ]]
  [[ "$output" == *"        runAsNonRoot: true"* ]]
  [[ "$output" != *"seccompProfile"* ]]
}

@test "generate_pod_security_context: with RuntimeDefault seccomp" {
  run generate_pod_security_context 6 "RuntimeDefault"
  [ "$status" -eq 0 ]
  [[ "$output" == *"securityContext:"* ]]
  [[ "$output" == *"runAsNonRoot: true"* ]]
  [[ "$output" == *"seccompProfile:"* ]]
  [[ "$output" == *"type: RuntimeDefault"* ]]
}

@test "generate_pod_security_context: with Localhost seccomp" {
  run generate_pod_security_context 4 "Localhost"
  [ "$status" -eq 0 ]
  [[ "$output" == *"    securityContext:"* ]]
  [[ "$output" == *"type: Localhost"* ]]
}

@test "generate_pod_security_context: respects indent" {
  run generate_pod_security_context 2 "DISABLED"
  [ "$status" -eq 0 ]
  [[ "$output" == "  securityContext:"* ]]
}

@test "generate_pod_security_context: fails with wrong arg count" {
  run generate_pod_security_context 6
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 2 arguments"* ]]
}

# =============================================================================
# generate_container_security_context
# =============================================================================

@test "generate_container_security_context: basic with true" {
  run generate_container_security_context 10 "true"
  [ "$status" -eq 0 ]
  [[ "$output" == *"securityContext:"* ]]
  [[ "$output" == *"allowPrivilegeEscalation: false"* ]]
  [[ "$output" == *"readOnlyRootFilesystem: true"* ]]
  [[ "$output" == *"capabilities:"* ]]
  [[ "$output" == *"drop:"* ]]
  [[ "$output" == *"- ALL"* ]]
}

@test "generate_container_security_context: with false" {
  run generate_container_security_context 10 "false"
  [ "$status" -eq 0 ]
  [[ "$output" == *"readOnlyRootFilesystem: false"* ]]
}

@test "generate_container_security_context: respects indent" {
  run generate_container_security_context 4 "true"
  [ "$status" -eq 0 ]
  [[ "$output" == "    securityContext:"* ]]
}

@test "generate_container_security_context: fails with wrong arg count" {
  run generate_container_security_context 10
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 2 arguments"* ]]
}

# =============================================================================
# generate_container_resources
# =============================================================================

@test "generate_container_resources: basic without cpu limit" {
  run generate_container_resources 10 "128Mi" "100m"
  [ "$status" -eq 0 ]
  [[ "$output" == *"resources:"* ]]
  [[ "$output" == *"requests:"* ]]
  [[ "$output" == *"memory: 128Mi"* ]]
  [[ "$output" == *"cpu: 100m"* ]]
  [[ "$output" == *"limits:"* ]]
  # Should not have cpu in limits
  local lines
  lines=$(echo "$output" | grep -c "cpu:")
  [ "$lines" -eq 1 ]
}

@test "generate_container_resources: with cpu limit" {
  run generate_container_resources 10 "256Mi" "100m" "500m"
  [ "$status" -eq 0 ]
  [[ "$output" == *"requests:"* ]]
  [[ "$output" == *"cpu: 100m"* ]]
  [[ "$output" == *"limits:"* ]]
  [[ "$output" == *"cpu: 500m"* ]]
  # Should have cpu twice (request and limit)
  local lines
  lines=$(echo "$output" | grep -c "cpu:")
  [ "$lines" -eq 2 ]
}

@test "generate_container_resources: respects indent" {
  run generate_container_resources 4 "64Mi" "50m"
  [ "$status" -eq 0 ]
  [[ "$output" == "    resources:"* ]]
}

@test "generate_container_resources: fails with wrong arg count" {
  run generate_container_resources 10 "128Mi"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires 3-4 arguments"* ]]
}

# =============================================================================
# generate_container_ports
# =============================================================================

@test "generate_container_ports: basic with default protocol" {
  run generate_container_ports 10 "8080"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ports:"* ]]
  [[ "$output" == *"- containerPort: 8080"* ]]
  [[ "$output" == *"protocol: TCP"* ]]
}

@test "generate_container_ports: with custom protocol" {
  run generate_container_ports 10 "53" "UDP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"containerPort: 53"* ]]
  [[ "$output" == *"protocol: UDP"* ]]
}

@test "generate_container_ports: respects indent" {
  run generate_container_ports 4 "3000"
  [ "$status" -eq 0 ]
  [[ "$output" == "    ports:"* ]]
}

@test "generate_container_ports: fails with wrong arg count" {
  run generate_container_ports 10
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires 2-3 arguments"* ]]
}

# =============================================================================
# generate_container_lifecycle
# =============================================================================

@test "generate_container_lifecycle: generates preStop hook" {
  run generate_container_lifecycle 10 "sleep 5"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lifecycle:"* ]]
  [[ "$output" == *"preStop:"* ]]
  [[ "$output" == *"exec:"* ]]
  [[ "$output" == *"command:"* ]]
  [[ "$output" == *"- /bin/sh"* ]]
  [[ "$output" == *"- -c"* ]]
  [[ "$output" == *"- sleep 5"* ]]
}

@test "generate_container_lifecycle: outputs nothing when command empty" {
  run generate_container_lifecycle 10 ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_container_lifecycle: respects indent" {
  run generate_container_lifecycle 4 "exit 0"
  [ "$status" -eq 0 ]
  [[ "$output" == "    lifecycle:"* ]]
}

@test "generate_container_lifecycle: fails with wrong arg count" {
  run generate_container_lifecycle 10
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 2 arguments"* ]]
}

# =============================================================================
# generate_container_env_from_directory
# =============================================================================

@test "generate_container_env_from_directory: generates env vars from files" {
  local test_dir
  test_dir=$(mktemp -d)
  echo "value1" > "$test_dir/VAR1"
  echo "value2" > "$test_dir/VAR2"

  run generate_container_env_from_directory 10 "$test_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"env:"* ]]
  [[ "$output" == *"- name: VAR1"* ]]
  [[ "$output" == *"value: \"value1\""* ]]
  [[ "$output" == *"- name: VAR2"* ]]
  [[ "$output" == *"value: \"value2\""* ]]

  rm -rf "$test_dir"
}

@test "generate_container_env_from_directory: outputs nothing when dir missing" {
  run generate_container_env_from_directory 10 "/nonexistent/dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_container_env_from_directory: outputs nothing when dir empty" {
  local test_dir
  test_dir=$(mktemp -d)

  run generate_container_env_from_directory 10 "$test_dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  rm -rf "$test_dir"
}

@test "generate_container_env_from_directory: ignores dotfiles" {
  local test_dir
  test_dir=$(mktemp -d)
  echo "visible" > "$test_dir/VISIBLE"
  echo "hidden" > "$test_dir/.hidden"

  run generate_container_env_from_directory 10 "$test_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VISIBLE"* ]]
  [[ "$output" != *".hidden"* ]]

  rm -rf "$test_dir"
}

@test "generate_container_env_from_directory: fails with wrong arg count" {
  run generate_container_env_from_directory 10
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 2 arguments"* ]]
}

# =============================================================================
# generate_configmap_secret_volume_mounts
# =============================================================================

@test "generate_configmap_secret_volume_mounts: both configmap and secret" {
  run generate_configmap_secret_volume_mounts 10 "true" "true" "/config" "/secret"
  [ "$status" -eq 0 ]
  [[ "$output" == *"volumeMounts:"* ]]
  [[ "$output" == *"- name: configmap"* ]]
  [[ "$output" == *"mountPath: /config"* ]]
  [[ "$output" == *"- name: secret"* ]]
  [[ "$output" == *"mountPath: /secret"* ]]
  [[ "$output" == *"readOnly: true"* ]]
}

@test "generate_configmap_secret_volume_mounts: only configmap" {
  run generate_configmap_secret_volume_mounts 10 "true" "false" "/config" "/secret"
  [ "$status" -eq 0 ]
  [[ "$output" == *"volumeMounts:"* ]]
  [[ "$output" == *"- name: configmap"* ]]
  [[ "$output" != *"- name: secret"* ]]
}

@test "generate_configmap_secret_volume_mounts: only secret" {
  run generate_configmap_secret_volume_mounts 10 "false" "true" "/config" "/secret"
  [ "$status" -eq 0 ]
  [[ "$output" == *"volumeMounts:"* ]]
  [[ "$output" != *"- name: configmap"* ]]
  [[ "$output" == *"- name: secret"* ]]
}

@test "generate_configmap_secret_volume_mounts: outputs nothing when neither" {
  run generate_configmap_secret_volume_mounts 10 "false" "false" "/config" "/secret"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_configmap_secret_volume_mounts: fails with wrong arg count" {
  run generate_configmap_secret_volume_mounts 10 "true" "true"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 5 arguments"* ]]
}

# =============================================================================
# generate_configmap_secret_volumes
# =============================================================================

@test "generate_configmap_secret_volumes: both configmap and secret" {
  run generate_configmap_secret_volumes 6 "true" "true" "my-configmap" "my-secret"
  [ "$status" -eq 0 ]
  [[ "$output" == *"volumes:"* ]]
  [[ "$output" == *"- name: configmap"* ]]
  [[ "$output" == *"configMap:"* ]]
  [[ "$output" == *"name: my-configmap"* ]]
  [[ "$output" == *"- name: secret"* ]]
  [[ "$output" == *"secret:"* ]]
  [[ "$output" == *"secretName: my-secret"* ]]
}

@test "generate_configmap_secret_volumes: only configmap" {
  run generate_configmap_secret_volumes 6 "true" "false" "my-configmap" "my-secret"
  [ "$status" -eq 0 ]
  [[ "$output" == *"volumes:"* ]]
  [[ "$output" == *"configMap:"* ]]
  [[ "$output" != *"secret:"* ]]
}

@test "generate_configmap_secret_volumes: only secret" {
  run generate_configmap_secret_volumes 6 "false" "true" "my-configmap" "my-secret"
  [ "$status" -eq 0 ]
  [[ "$output" == *"volumes:"* ]]
  [[ "$output" != *"configMap:"* ]]
  [[ "$output" == *"secret:"* ]]
}

@test "generate_configmap_secret_volumes: outputs nothing when neither" {
  run generate_configmap_secret_volumes 6 "false" "false" "my-configmap" "my-secret"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_configmap_secret_volumes: fails with wrong arg count" {
  run generate_configmap_secret_volumes 6 "true"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 5 arguments"* ]]
}

# =============================================================================
# generate_image_pull_secrets
# =============================================================================

@test "generate_image_pull_secrets: generates block" {
  run generate_image_pull_secrets 6 "my-registry-secret"
  [ "$status" -eq 0 ]
  [[ "$output" == *"imagePullSecrets:"* ]]
  [[ "$output" == *"- name: my-registry-secret"* ]]
}

@test "generate_image_pull_secrets: respects indent" {
  run generate_image_pull_secrets 2 "secret"
  [ "$status" -eq 0 ]
  [[ "$output" == "  imagePullSecrets:"* ]]
}

@test "generate_image_pull_secrets: fails with wrong arg count" {
  run generate_image_pull_secrets 6
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 2 arguments"* ]]
}

# =============================================================================
# generate_service_account_config
# =============================================================================

@test "generate_service_account_config: with serviceaccount" {
  run generate_service_account_config 6 "true" "my-sa" "false"
  [ "$status" -eq 0 ]
  [[ "$output" == *"serviceAccountName: my-sa"* ]]
  [[ "$output" == *"automountServiceAccountToken: false"* ]]
}

@test "generate_service_account_config: without serviceaccount" {
  run generate_service_account_config 6 "false" "my-sa" "true"
  [ "$status" -eq 0 ]
  [[ "$output" != *"serviceAccountName"* ]]
  [[ "$output" == *"automountServiceAccountToken: true"* ]]
}

@test "generate_service_account_config: respects indent" {
  run generate_service_account_config 2 "true" "sa" "false"
  [ "$status" -eq 0 ]
  [[ "$output" == "  serviceAccountName: sa"* ]]
}

@test "generate_service_account_config: fails with wrong arg count" {
  run generate_service_account_config 6 "true"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 4 arguments"* ]]
}

# =============================================================================
# generate_container_start
# =============================================================================

@test "generate_container_start: basic with defaults" {
  run generate_container_start 8 "app" "nginx:latest"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- name: app"* ]]
  [[ "$output" == *"image: nginx:latest"* ]]
  [[ "$output" == *"imagePullPolicy: IfNotPresent"* ]]
}

@test "generate_container_start: with custom pull policy" {
  run generate_container_start 8 "sidecar" "busybox:1.0" "Always"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- name: sidecar"* ]]
  [[ "$output" == *"image: busybox:1.0"* ]]
  [[ "$output" == *"imagePullPolicy: Always"* ]]
}

@test "generate_container_start: respects indent" {
  run generate_container_start 4 "test" "test:1"
  [ "$status" -eq 0 ]
  [[ "$output" == "    - name: test"* ]]
}

@test "generate_container_start: fails with wrong arg count" {
  run generate_container_start 8 "app"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires 3-4 arguments"* ]]
}
