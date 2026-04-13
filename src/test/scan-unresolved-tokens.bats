#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for scan-unresolved-tokens utility
#
# Scans manifest files for unresolved token references matching a given
# delimiter style and name style. Returns sorted, deduplicated token names.

load helpers

SCAN_SCRIPT="$UTIL_DIR/scan-unresolved-tokens"

setup() {
  TEST_DIR=$(create_test_dir "scan-tokens")
}

# =============================================================================
# Argument validation
# =============================================================================

@test "scan-unresolved-tokens: fails with no arguments" {
  run "$SCAN_SCRIPT"
  [ "$status" -ne 0 ]
}

@test "scan-unresolved-tokens: fails with missing directory argument" {
  run "$SCAN_SCRIPT" shell PascalCase
  [ "$status" -ne 0 ]
}

@test "scan-unresolved-tokens: fails with nonexistent directory" {
  run "$SCAN_SCRIPT" shell PascalCase "/nonexistent/path"
  [ "$status" -ne 0 ]
}

# =============================================================================
# Shell + PascalCase (default Kaptain style)
# =============================================================================

@test "scan-unresolved-tokens: finds shell PascalCase tokens" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: Deployment
spec:
  replicas: ${Replicas}
  template:
    spec:
      containers:
        - image: ${EnvironmentDockerRegistryAndNamespace}/${DockerImageName}:${DockerTag}
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 4 ]
  echo "$output" | grep -q "^DockerImageName$"
  echo "$output" | grep -q "^DockerTag$"
  echo "$output" | grep -q "^EnvironmentDockerRegistryAndNamespace$"
  echo "$output" | grep -q "^Replicas$"
}

@test "scan-unresolved-tokens: deduplicates tokens across files" {
  cat > "$TEST_DIR/deploy.yaml" << 'EOF'
image: ${DockerImageName}:${DockerTag}
EOF
  cat > "$TEST_DIR/service.yaml" << 'EOF'
namespace: ${Environment}
image: ${DockerImageName}:${DockerTag}
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 3 ]
  echo "$output" | grep -q "^DockerImageName$"
  echo "$output" | grep -q "^DockerTag$"
  echo "$output" | grep -q "^Environment$"
}

@test "scan-unresolved-tokens: returns empty for clean manifests" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ports:
    - port: 80
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "scan-unresolved-tokens: finds tokens inside YAML comments" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
# Default: ${DefaultMemory}
apiVersion: v1
kind: ConfigMap
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^DefaultMemory$"
}

@test "scan-unresolved-tokens: multiple tokens on one line" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
image: ${Registry}/${ImageName}:${Tag}
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 3 ]
  echo "$output" | grep -q "^Registry$"
  echo "$output" | grep -q "^ImageName$"
  echo "$output" | grep -q "^Tag$"
}

@test "scan-unresolved-tokens: empty directory returns nothing" {
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "scan-unresolved-tokens: ignores non-matching patterns" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
env:
  - name: HOME
    value: /home/user
  - name: SHELL_VAR
    value: $HOME
  - name: CURLY
    value: ${lowercase_not_pascal}
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "scan-unresolved-tokens: scans subdirectories" {
  mkdir -p "$TEST_DIR/sub/nested"
  cat > "$TEST_DIR/top.yaml" << 'EOF'
name: ${TopLevel}
EOF
  cat > "$TEST_DIR/sub/nested/deep.yaml" << 'EOF'
name: ${DeepNested}
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 2 ]
  echo "$output" | grep -q "^DeepNested$"
  echo "$output" | grep -q "^TopLevel$"
}

@test "scan-unresolved-tokens: scans non-yaml files too" {
  cat > "$TEST_DIR/Dockerfile" << 'EOF'
FROM ${BaseImage}
COPY . /app
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^BaseImage$"
}

# =============================================================================
# Other delimiter styles
# =============================================================================

@test "scan-unresolved-tokens: mustache PascalCase" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
image: {{ Registry }}/{{ ImageName }}:{{ Tag }}
EOF
  run "$SCAN_SCRIPT" mustache PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 3 ]
  echo "$output" | grep -q "^Registry$"
  echo "$output" | grep -q "^ImageName$"
  echo "$output" | grep -q "^Tag$"
}

@test "scan-unresolved-tokens: shell UPPER_SNAKE" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
image: ${DOCKER_REGISTRY}/${IMAGE_NAME}:${DOCKER_TAG}
EOF
  run "$SCAN_SCRIPT" shell UPPER_SNAKE "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 3 ]
  echo "$output" | grep -q "^DOCKER_REGISTRY$"
  echo "$output" | grep -q "^IMAGE_NAME$"
  echo "$output" | grep -q "^DOCKER_TAG$"
}

@test "scan-unresolved-tokens: stringtemplate PascalCase" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
image: $Registry$/$ImageName$:$Tag$
EOF
  run "$SCAN_SCRIPT" stringtemplate PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 3 ]
  echo "$output" | grep -q "^Registry$"
  echo "$output" | grep -q "^ImageName$"
  echo "$output" | grep -q "^Tag$"
}

@test "scan-unresolved-tokens: ognl PascalCase" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
image: %{Registry}/%{ImageName}:%{Tag}
EOF
  run "$SCAN_SCRIPT" ognl PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 3 ]
  echo "$output" | grep -q "^Registry$"
  echo "$output" | grep -q "^ImageName$"
  echo "$output" | grep -q "^Tag$"
}

# =============================================================================
# Edge cases
# =============================================================================

@test "scan-unresolved-tokens: does not match partial shell tokens" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
not-a-token: ${
also-not: ${}
broken: ${
Name}
literal-dollar: $Name
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "scan-unresolved-tokens: handles files with special characters in content" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
data:
  script: |
    echo "hello world"
    if [[ $? -eq 0 ]]; then
      echo "success"
    fi
  token: ${RealToken}
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 1 ]
  echo "$output" | grep -q "^RealToken$"
}

@test "scan-unresolved-tokens: finds nested (path-based) shell PascalCase tokens" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
replicas: ${VendorEnvoyGateway/Replicas}
memory: ${VendorEnvoyGateway/Memory}
cpu: ${VendorEnvoyGateway/Cpu}
namespace: ${Environment}
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "VendorEnvoyGateway/Replicas"
  echo "$output" | grep -q "VendorEnvoyGateway/Memory"
  echo "$output" | grep -q "VendorEnvoyGateway/Cpu"
  echo "$output" | grep -q "Environment"
}

@test "scan-unresolved-tokens: finds nested shell UPPER_SNAKE tokens" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
replicas: ${VENDOR_ENVOY_GATEWAY/REPLICAS}
namespace: ${ENVIRONMENT}
EOF
  run "$SCAN_SCRIPT" shell UPPER_SNAKE "$TEST_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "VENDOR_ENVOY_GATEWAY/REPLICAS"
  echo "$output" | grep -q "ENVIRONMENT"
}

@test "scan-unresolved-tokens: output is sorted alphabetically" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
z: ${Zebra}
a: ${Alpha}
m: ${Middle}
EOF
  run "$SCAN_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | head -1)" = "Alpha" ]
  [ "$(echo "$output" | sed -n '2p')" = "Middle" ]
  [ "$(echo "$output" | tail -1)" = "Zebra" ]
}
