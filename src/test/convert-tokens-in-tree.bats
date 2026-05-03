#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for convert-tokens-in-tree utility
#
# Rewrites unresolved tokens in a directory of files from one (delimiter,
# name) scheme to another, in place. Built on the regex/format/canonical
# primitives in lib/token-format.bash.

load helpers

CONVERT_SCRIPT="$UTIL_DIR/convert-tokens-in-tree"

setup() {
  TEST_DIR=$(create_test_dir "convert-tokens")
}

# =============================================================================
# Argument validation
# =============================================================================

@test "convert-tokens-in-tree: fails with no arguments" {
  run "$CONVERT_SCRIPT"
  [ "$status" -ne 0 ]
}

@test "convert-tokens-in-tree: fails with too few arguments" {
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase
  [ "$status" -ne 0 ]
}

@test "convert-tokens-in-tree: fails with invalid from-delim" {
  mkdir -p "$TEST_DIR/d"
  run "$CONVERT_SCRIPT" bogus PascalCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 2 ]
}

@test "convert-tokens-in-tree: fails with invalid from-name" {
  mkdir -p "$TEST_DIR/d"
  run "$CONVERT_SCRIPT" shell BogusCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 2 ]
}

@test "convert-tokens-in-tree: fails with invalid to-delim" {
  mkdir -p "$TEST_DIR/d"
  run "$CONVERT_SCRIPT" shell PascalCase bogus PascalCase "$TEST_DIR/d"
  [ "$status" -eq 2 ]
}

@test "convert-tokens-in-tree: fails with invalid to-name" {
  mkdir -p "$TEST_DIR/d"
  run "$CONVERT_SCRIPT" shell PascalCase mustache BogusCase "$TEST_DIR/d"
  [ "$status" -eq 2 ]
}

@test "convert-tokens-in-tree: fails with nonexistent directory" {
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase /nonexistent/dir
  [ "$status" -ne 0 ]
}

# =============================================================================
# No-op: same scheme
# =============================================================================

@test "convert-tokens-in-tree: same scheme is a no-op" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/manifest.yaml" << 'EOF'
apiVersion: v1
kind: Deployment
spec:
  replicas: ${Replicas}
EOF
  before=$(cat "$TEST_DIR/d/manifest.yaml")
  run "$CONVERT_SCRIPT" shell PascalCase shell PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  after=$(cat "$TEST_DIR/d/manifest.yaml")
  [ "$before" = "$after" ]
  echo "$output" | grep -q "No conversion needed"
}

# =============================================================================
# No-op: empty directory / no tokens
# =============================================================================

@test "convert-tokens-in-tree: empty directory exits 0 with message" {
  mkdir -p "$TEST_DIR/empty"
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase "$TEST_DIR/empty"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "No .* tokens found"
}

@test "convert-tokens-in-tree: directory with no tokens leaves files unchanged" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/plain.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: plain
data:
  greeting: hello
EOF
  before=$(cat "$TEST_DIR/d/plain.yaml")
  run "$CONVERT_SCRIPT" shell PascalCase mustache UPPER_SNAKE "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  after=$(cat "$TEST_DIR/d/plain.yaml")
  [ "$before" = "$after" ]
}

# =============================================================================
# Delimiter-only conversion
# =============================================================================

@test "convert-tokens-in-tree: shell -> mustache, PascalCase -> PascalCase" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: ${Replicas}
  template:
    spec:
      containers:
        - image: ${DockerImageName}:${DockerTag}
EOF
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  result=$(cat "$TEST_DIR/d/deployment.yaml")
  echo "$result" | grep -q "{{ Replicas }}"
  echo "$result" | grep -q "{{ DockerImageName }}"
  echo "$result" | grep -q "{{ DockerTag }}"
  ! echo "$result" | grep -q '\${'
}

@test "convert-tokens-in-tree: shell -> helm preserves token names" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/svc.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: ${ServiceName}
EOF
  run "$CONVERT_SCRIPT" shell PascalCase helm PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  result=$(cat "$TEST_DIR/d/svc.yaml")
  echo "$result" | grep -q "{{ .Values.ServiceName }}"
}

# =============================================================================
# Name-only conversion
# =============================================================================

@test "convert-tokens-in-tree: shell PascalCase -> shell UPPER_SNAKE" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: ${Replicas}
  template:
    spec:
      containers:
        - image: ${DockerImageName}:${DockerTag}
EOF
  run "$CONVERT_SCRIPT" shell PascalCase shell UPPER_SNAKE "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  result=$(cat "$TEST_DIR/d/deployment.yaml")
  echo "$result" | grep -q '\${REPLICAS}'
  echo "$result" | grep -q '\${DOCKER_IMAGE_NAME}'
  echo "$result" | grep -q '\${DOCKER_TAG}'
}

@test "convert-tokens-in-tree: shell UPPER_SNAKE -> shell lower-kebab" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/cfg.yaml" << 'EOF'
data:
  a: ${MAX_HEAP_SIZE}
  b: ${USER_HOME}
EOF
  run "$CONVERT_SCRIPT" shell UPPER_SNAKE shell lower-kebab "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  result=$(cat "$TEST_DIR/d/cfg.yaml")
  echo "$result" | grep -q '\${max-heap-size}'
  echo "$result" | grep -q '\${user-home}'
}

# =============================================================================
# Both delimiter + name conversion
# =============================================================================

@test "convert-tokens-in-tree: shell PascalCase -> mustache lower-kebab" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/deployment.yaml" << 'EOF'
spec:
  replicas: ${Replicas}
  resources:
    requests:
      memory: ${MaxHeapSize}
EOF
  run "$CONVERT_SCRIPT" shell PascalCase mustache lower-kebab "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  result=$(cat "$TEST_DIR/d/deployment.yaml")
  echo "$result" | grep -q "{{ replicas }}"
  echo "$result" | grep -q "{{ max-heap-size }}"
}

@test "convert-tokens-in-tree: erb PascalCase -> shell UPPER_SNAKE" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/x.yaml" << 'EOF'
data:
  a: <%= ImageName %>
  b: <%= ImageTag %>
EOF
  run "$CONVERT_SCRIPT" erb PascalCase shell UPPER_SNAKE "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  result=$(cat "$TEST_DIR/d/x.yaml")
  echo "$result" | grep -q '\${IMAGE_NAME}'
  echo "$result" | grep -q '\${IMAGE_TAG}'
}

# =============================================================================
# Nested-path tokens (with /)
# =============================================================================

@test "convert-tokens-in-tree: nested PascalCase -> nested UPPER_SNAKE preserves slashes" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/deployment.yaml" << 'EOF'
spec:
  replicas: ${VendorEnvoyGateway/Replicas}
  resources:
    requests:
      memory: ${VendorEnvoyGateway/Memory}
      cpu: ${VendorEnvoyGateway/Cpu}
EOF
  run "$CONVERT_SCRIPT" shell PascalCase shell UPPER_SNAKE "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  result=$(cat "$TEST_DIR/d/deployment.yaml")
  echo "$result" | grep -q '\${VENDOR_ENVOY_GATEWAY/REPLICAS}'
  echo "$result" | grep -q '\${VENDOR_ENVOY_GATEWAY/MEMORY}'
  echo "$result" | grep -q '\${VENDOR_ENVOY_GATEWAY/CPU}'
}

# =============================================================================
# Repeated tokens within a file
# =============================================================================

@test "convert-tokens-in-tree: replaces every occurrence (not just first)" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/repeats.yaml" << 'EOF'
a: ${ProjectName}
b: ${ProjectName}
c: ${ProjectName}-suffix
EOF
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  result=$(cat "$TEST_DIR/d/repeats.yaml")
  count=$(echo "$result" | grep -c "{{ ProjectName }}")
  [ "$count" -eq 3 ]
  ! echo "$result" | grep -q '\${ProjectName}'
}

# =============================================================================
# Multiple files
# =============================================================================

@test "convert-tokens-in-tree: processes nested directory structure" {
  mkdir -p "$TEST_DIR/d/sub/deeper"
  cat > "$TEST_DIR/d/top.yaml" << 'EOF'
top: ${TopVar}
EOF
  cat > "$TEST_DIR/d/sub/mid.yaml" << 'EOF'
mid: ${MidVar}
EOF
  cat > "$TEST_DIR/d/sub/deeper/deep.yaml" << 'EOF'
deep: ${DeepVar}
EOF
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  grep -q "{{ TopVar }}" "$TEST_DIR/d/top.yaml"
  grep -q "{{ MidVar }}" "$TEST_DIR/d/sub/mid.yaml"
  grep -q "{{ DeepVar }}" "$TEST_DIR/d/sub/deeper/deep.yaml"
}

@test "convert-tokens-in-tree: leaves untouched files alone" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/with-tokens.yaml" << 'EOF'
a: ${SomeToken}
EOF
  cat > "$TEST_DIR/d/no-tokens.yaml" << 'EOF'
plain: content
EOF
  before_no_tokens=$(cat "$TEST_DIR/d/no-tokens.yaml")
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  grep -q "{{ SomeToken }}" "$TEST_DIR/d/with-tokens.yaml"
  after_no_tokens=$(cat "$TEST_DIR/d/no-tokens.yaml")
  [ "$before_no_tokens" = "$after_no_tokens" ]
}

# =============================================================================
# Trailing newline preservation
# =============================================================================

@test "convert-tokens-in-tree: preserves trailing newline when input has one" {
  mkdir -p "$TEST_DIR/d"
  printf 'value: %s\n' '${Token}' > "$TEST_DIR/d/file.yaml"
  # Confirm the input ends with newline
  [ "$(tail -c1 "$TEST_DIR/d/file.yaml" | od -An -c | tr -d ' ')" = '\n' ]
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  # Output must still end with newline
  [ "$(tail -c1 "$TEST_DIR/d/file.yaml" | od -An -c | tr -d ' ')" = '\n' ]
}

@test "convert-tokens-in-tree: preserves no-trailing-newline when input has none" {
  mkdir -p "$TEST_DIR/d"
  printf 'value: %s' '${Token}' > "$TEST_DIR/d/file.yaml"
  # Confirm the input does NOT end with newline
  [ "$(tail -c1 "$TEST_DIR/d/file.yaml" | od -An -c | tr -d ' ')" = '}' ]
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  # Output must still NOT end with newline
  [ "$(tail -c1 "$TEST_DIR/d/file.yaml" | od -An -c | tr -d ' ')" = '}' ]
}

# =============================================================================
# Round-trip: convert and back
# =============================================================================

@test "convert-tokens-in-tree: round-trip shell PascalCase -> mustache UPPER_SNAKE -> shell PascalCase is identity" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/file.yaml" << 'EOF'
a: ${ProjectName}
b: ${MaxHeapSize}
c: ${VendorEnvoyGateway/Cpu}
EOF
  before=$(cat "$TEST_DIR/d/file.yaml")
  run "$CONVERT_SCRIPT" shell PascalCase mustache UPPER_SNAKE "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  run "$CONVERT_SCRIPT" mustache UPPER_SNAKE shell PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  after=$(cat "$TEST_DIR/d/file.yaml")
  [ "$before" = "$after" ]
}

# =============================================================================
# Output messaging
# =============================================================================

@test "convert-tokens-in-tree: reports per-file replacements" {
  mkdir -p "$TEST_DIR/d"
  cat > "$TEST_DIR/d/file.yaml" << 'EOF'
a: ${One}
b: ${Two}
c: ${One}
EOF
  run "$CONVERT_SCRIPT" shell PascalCase mustache PascalCase "$TEST_DIR/d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Converted 3 token instances in file.yaml"
  echo "$output" | grep -q "Total replacements: 3"
}
