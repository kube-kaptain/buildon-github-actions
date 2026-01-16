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
  run generate_container_resources 10 "512Mi" "128Mi" "100m"
  [ "$status" -eq 0 ]
  [[ "$output" == *"resources:"* ]]
  [[ "$output" == *"requests:"* ]]
  [[ "$output" == *"ephemeral-storage: 512Mi"* ]]
  [[ "$output" == *"memory: 128Mi"* ]]
  [[ "$output" == *"cpu: 100m"* ]]
  [[ "$output" == *"limits:"* ]]
  # ephemeral-storage and memory in both requests and limits
  local storage_count memory_count cpu_count
  storage_count=$(echo "$output" | grep -c "ephemeral-storage:")
  memory_count=$(echo "$output" | grep -c "memory:")
  cpu_count=$(echo "$output" | grep -c "cpu:")
  [ "$storage_count" -eq 2 ]
  [ "$memory_count" -eq 2 ]
  # cpu only in requests (no limit specified)
  [ "$cpu_count" -eq 1 ]
}

@test "generate_container_resources: with cpu limit" {
  run generate_container_resources 10 "1Gi" "256Mi" "100m" "500m"
  [ "$status" -eq 0 ]
  [[ "$output" == *"requests:"* ]]
  [[ "$output" == *"ephemeral-storage: 1Gi"* ]]
  [[ "$output" == *"memory: 256Mi"* ]]
  [[ "$output" == *"limits:"* ]]
  # All resources in both requests and limits when cpu limit specified
  local storage_count memory_count cpu_count
  storage_count=$(echo "$output" | grep -c "ephemeral-storage:")
  memory_count=$(echo "$output" | grep -c "memory:")
  cpu_count=$(echo "$output" | grep -c "cpu:")
  [ "$storage_count" -eq 2 ]
  [ "$memory_count" -eq 2 ]
  [ "$cpu_count" -eq 2 ]
}

@test "generate_container_resources: respects indent" {
  run generate_container_resources 4 "256Mi" "64Mi" "50m"
  [ "$status" -eq 0 ]
  [[ "$output" == "    resources:"* ]]
}

@test "generate_container_resources: fails with wrong arg count" {
  run generate_container_resources 10 "512Mi" "128Mi"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires 4-5 arguments"* ]]
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
  test_dir=$(create_test_dir "pod-spec-env")
  echo "value1" > "$test_dir/VAR1"
  echo "value2" > "$test_dir/VAR2"

  run generate_container_env_from_directory 10 "$test_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"env:"* ]]
  [[ "$output" == *"- name: VAR1"* ]]
  [[ "$output" == *"value: \"value1\""* ]]
  [[ "$output" == *"- name: VAR2"* ]]
  [[ "$output" == *"value: \"value2\""* ]]
}

@test "generate_container_env_from_directory: outputs nothing when dir missing" {
  run generate_container_env_from_directory 10 "/nonexistent/dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_container_env_from_directory: outputs nothing when dir empty" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-empty")

  run generate_container_env_from_directory 10 "$test_dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_container_env_from_directory: ignores dotfiles" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-dotfiles")
  echo "visible" > "$test_dir/VISIBLE"
  echo "hidden" > "$test_dir/.hidden"

  run generate_container_env_from_directory 10 "$test_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VISIBLE"* ]]
  [[ "$output" != *".hidden"* ]]
}

@test "generate_container_env_from_directory: skip_header mode omits env header" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-skip-header")
  echo "value1" > "$test_dir/VAR1"

  run generate_container_env_from_directory 10 "$test_dir" "true"
  [ "$status" -eq 0 ]
  [[ "$output" != *"env:"* ]]
  [[ "$output" == *"- name: VAR1"* ]]
  [[ "$output" == *"value: \"value1\""* ]]
}

@test "generate_container_env_from_directory: fails with wrong arg count" {
  run generate_container_env_from_directory 10
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires 2-3 arguments"* ]]
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

# =============================================================================
# generate_container_env_refs
# =============================================================================

@test "generate_container_env_refs: generates configmap refs" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-cm-refs")
  cat > "$test_dir/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
data:
  DATABASE_HOST: localhost
  DATABASE_PORT: "5432"
EOF

  run generate_container_env_refs 2 configmap "$test_dir/configmap.yaml" "test-cm" "DATABASE_HOST,DATABASE_PORT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- name: DATABASE_HOST"* ]]
  [[ "$output" == *"valueFrom:"* ]]
  [[ "$output" == *"configMapKeyRef:"* ]]
  [[ "$output" == *"name: test-cm"* ]]
  [[ "$output" == *"key: DATABASE_HOST"* ]]
  [[ "$output" == *"- name: DATABASE_PORT"* ]]
  [[ "$output" == *"key: DATABASE_PORT"* ]]
}

@test "generate_container_env_refs: generates secret refs" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-secret-refs")
  cat > "$test_dir/secret.yaml" << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
type: Opaque
stringData:
  DB_PASSWORD: supersecret
  API_KEY: abcd1234
EOF

  run generate_container_env_refs 4 secret "$test_dir/secret.yaml" "test-secret" "DB_PASSWORD API_KEY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- name: DB_PASSWORD"* ]]
  [[ "$output" == *"secretKeyRef:"* ]]
  [[ "$output" == *"name: test-secret"* ]]
  [[ "$output" == *"key: DB_PASSWORD"* ]]
  [[ "$output" == *"- name: API_KEY"* ]]
}

@test "generate_container_env_refs: fails on missing key" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-missing-key")
  cat > "$test_dir/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
data:
  EXISTING_KEY: value
EOF

  run generate_container_env_refs 2 configmap "$test_dir/configmap.yaml" "test-cm" "NONEXISTENT_KEY"
  [ "$status" -eq 1 ]
  [[ "$output" == *"key 'NONEXISTENT_KEY' not found"* ]]
}

@test "generate_container_env_refs: outputs nothing when keys empty" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-empty-keys")
  cat > "$test_dir/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
data:
  KEY: value
EOF

  run generate_container_env_refs 2 configmap "$test_dir/configmap.yaml" "test-cm" ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_container_env_refs: fails on invalid resource type" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-invalid-type")
  touch "$test_dir/file.yaml"

  run generate_container_env_refs 2 invalid "$test_dir/file.yaml" "name" "key"
  [ "$status" -eq 1 ]
  [[ "$output" == *"resource_type must be 'configmap' or 'secret'"* ]]
}

@test "generate_container_env_refs: fails with wrong arg count" {
  run generate_container_env_refs 2 configmap
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 5 arguments"* ]]
}

# =============================================================================
# generate_container_env_all
# =============================================================================

@test "generate_container_env_all: combines plain env and refs" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-env-all")

  # Create env directory with plain vars
  mkdir -p "$test_dir/env"
  echo "plain_value" > "$test_dir/env/PLAIN_VAR"

  # Create configmap and secret
  cat > "$test_dir/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
data:
  CM_KEY: cm_value
EOF
  cat > "$test_dir/secret.yaml" << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
type: Opaque
stringData:
  SECRET_KEY: secret_value
EOF

  run generate_container_env_all 8 "$test_dir/env" \
    "$test_dir/configmap.yaml" "test-cm" "CM_KEY" \
    "$test_dir/secret.yaml" "test-secret" "SECRET_KEY"

  [ "$status" -eq 0 ]
  # Should have exactly one env: header
  local env_count
  env_count=$(echo "$output" | grep -c "^        env:$" || true)
  [ "$env_count" -eq 1 ]
  # Plain env var
  [[ "$output" == *"- name: PLAIN_VAR"* ]]
  [[ "$output" == *"value: \"plain_value\""* ]]
  # ConfigMap ref
  [[ "$output" == *"- name: CM_KEY"* ]]
  [[ "$output" == *"configMapKeyRef:"* ]]
  # Secret ref
  [[ "$output" == *"- name: SECRET_KEY"* ]]
  [[ "$output" == *"secretKeyRef:"* ]]
}

@test "generate_container_env_all: outputs nothing when all empty" {
  run generate_container_env_all 8 "/nonexistent/env" \
    "/nonexistent/cm.yaml" "cm" "" \
    "/nonexistent/secret.yaml" "secret" ""

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_container_env_all: works with only configmap refs" {
  local test_dir
  test_dir=$(create_test_dir "pod-spec-cm-only")
  cat > "$test_dir/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
data:
  KEY1: value1
EOF

  run generate_container_env_all 8 "/nonexistent/env" \
    "$test_dir/configmap.yaml" "test-cm" "KEY1" \
    "/nonexistent/secret.yaml" "secret" ""

  [ "$status" -eq 0 ]
  [[ "$output" == *"env:"* ]]
  [[ "$output" == *"- name: KEY1"* ]]
  [[ "$output" == *"configMapKeyRef:"* ]]
}

@test "generate_container_env_all: fails with wrong arg count" {
  run generate_container_env_all 8 "/env" "/cm.yaml" "cm"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires exactly 8 arguments"* ]]
}
