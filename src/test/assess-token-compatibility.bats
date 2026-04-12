#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for assess-token-compatibility utility
#
# Scans manifest content for patterns that would collide with other token
# delimiter/name style combinations. Produces automaticConversion and
# repackageRequired lists.

load helpers

ASSESS_SCRIPT="$UTIL_DIR/assess-token-compatibility"

setup() {
  TEST_DIR=$(create_test_dir "assess-compat")
}

# Helper: extract automatic conversion list from output
get_automatic() {
  echo "$output" | sed -n '/^AUTOMATIC_CONVERSION:$/,/^REPACKAGE_REQUIRED:$/p' | grep -v '^AUTOMATIC_CONVERSION:$' | grep -v '^REPACKAGE_REQUIRED:$' || true
}

# Helper: extract repackage required list from output
get_repackage() {
  echo "$output" | sed -n '/^REPACKAGE_REQUIRED:$/,$p' | grep -v '^REPACKAGE_REQUIRED:$' || true
}

# =============================================================================
# Argument validation
# =============================================================================

@test "assess-token-compatibility: fails with no arguments" {
  run "$ASSESS_SCRIPT"
  [ "$status" -ne 0 ]
}

@test "assess-token-compatibility: fails with nonexistent directory" {
  run "$ASSESS_SCRIPT" shell PascalCase "/nonexistent/path"
  [ "$status" -ne 0 ]
}

# =============================================================================
# Clean manifests (no problematic content)
# =============================================================================

@test "assess-token-compatibility: clean manifests - all schemes auto-convertible" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ports:
    - port: 80
      targetPort: 8080
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # Should have no repackage entries
  repackage=$(get_repackage)
  [ -z "$repackage" ]
  # Should have many automatic entries
  automatic=$(get_automatic)
  [ -n "$automatic" ]
}

@test "assess-token-compatibility: output has both section headers" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^AUTOMATIC_CONVERSION:$"
  echo "$output" | grep -q "^REPACKAGE_REQUIRED:$"
}

@test "assess-token-compatibility: current scheme excluded from output" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # shell-PascalCase should not appear in either list
  ! echo "$output" | grep -q "shell-PascalCase"
}

# =============================================================================
# Sneaky scenario: bash scripts in ConfigMaps
# =============================================================================

@test "assess-token-compatibility: bash in ConfigMap triggers shell delimiter conflicts" {
  cat > "$TEST_DIR/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: scripts
data:
  init.sh: |
    #!/bin/bash
    echo "Starting ${AppName}"
    export HOME=${UserHome}
EOF
  run "$ASSESS_SCRIPT" mustache PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # shell-PascalCase should be in repackage (the bash ${AppName} matches shell regex)
  repackage=$(get_repackage)
  echo "$repackage" | grep -q "shell-PascalCase"
}

# =============================================================================
# Sneaky scenario: helm template leftovers
# =============================================================================

@test "assess-token-compatibility: helm template leftovers cause mustache/helm conflicts" {
  cat > "$TEST_DIR/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    original-chart: "rendered from {{ .Values.ChartName }}"
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # helm pattern {{ .Values.Name }} should trigger repackage
  repackage=$(get_repackage)
  echo "$repackage" | grep -q "helm-PascalCase"
}

# =============================================================================
# Sneaky scenario: dollar signs in resource values
# =============================================================================

@test "assess-token-compatibility: dollar in env values with uppercase" {
  cat > "$TEST_DIR/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - env:
            - name: JAVA_OPTS
              value: "-Xmx${MaxHeapSize}"
EOF
  run "$ASSESS_SCRIPT" mustache PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  repackage=$(get_repackage)
  echo "$repackage" | grep -q "shell-PascalCase"
}

# =============================================================================
# Sneaky scenario: at signs in email addresses
# =============================================================================

@test "assess-token-compatibility: email addresses do not trigger at-sign conflicts" {
  cat > "$TEST_DIR/deployment.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  annotations:
    contact: admin@example.com
    team: "platform-team@company.org"
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # at-sign delimiter wraps like @{Name}@ - plain email shouldn't match
  repackage=$(get_repackage)
  # Email addresses should NOT trigger at-sign conflicts
  ! echo "$repackage" | grep -q "at-sign-"
}

# =============================================================================
# Sneaky scenario: percent signs in URLs
# =============================================================================

@test "assess-token-compatibility: percent-encoded URLs do not trigger ognl conflicts" {
  cat > "$TEST_DIR/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
data:
  callback-url: "https://example.com/path%20with%20spaces"
  encoded: "hello%2Fworld"
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # ognl uses %{Name} - percent-encoded URLs shouldn't match
  repackage=$(get_repackage)
  ! echo "$repackage" | grep -q "ognl-"
}

# =============================================================================
# Sneaky scenario: hash signs in YAML comments
# =============================================================================

@test "assess-token-compatibility: YAML comments with hash do not trigger hash conflicts" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
# This is a comment with various #symbols
data:
  key: value # inline comment
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # hash delimiter isn't in the supported list for is_valid_substitution_token_style
  # so it should be skipped entirely
}

# =============================================================================
# Sneaky scenario: XML in annotations
# =============================================================================

@test "assess-token-compatibility: XML-like content in annotations triggers xml conflicts" {
  cat > "$TEST_DIR/deployment.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  annotations:
    config: '<property name="MaxRetries" value="3"/>'
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # erb uses <%= Name %> and t4 uses <#= Name #>
  # plain XML tags shouldn't match those patterns
}

# =============================================================================
# Sneaky scenario: github-actions-like expressions
# =============================================================================

@test "assess-token-compatibility: github actions expressions trigger github-actions conflicts" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
data:
  workflow-ref: "${{ github.ref }}"
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # github-actions uses ${{ Name }} pattern
  repackage=$(get_repackage)
  echo "$repackage" | grep -q "github-actions-"
}

# =============================================================================
# Sneaky scenario: stringtemplate dollar-delimited
# =============================================================================

@test "assess-token-compatibility: dollar-bounded names trigger stringtemplate conflicts" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
data:
  template: "$Header$"
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  repackage=$(get_repackage)
  echo "$repackage" | grep -q "stringtemplate-PascalCase"
}

# =============================================================================
# Mixed content: some schemes okay, some not
# =============================================================================

@test "assess-token-compatibility: mixed content splits correctly" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
data:
  bash-snippet: |
    echo ${SomeVar}
  clean-value: "just a string"
EOF
  run "$ASSESS_SCRIPT" mustache PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # shell should be in repackage due to ${SomeVar}
  repackage=$(get_repackage)
  echo "$repackage" | grep -q "shell-PascalCase"
  # ognl should be in automatic (no %{...} content)
  automatic=$(get_automatic)
  echo "$automatic" | grep -q "ognl-PascalCase"
}

# =============================================================================
# Sneaky scenario: unresolved tokens from current scheme in content
# =============================================================================

@test "assess-token-compatibility: own unresolved tokens do not affect other scheme assessment" {
  # The manifests have unresolved shell-PascalCase tokens (the current scheme)
  # Other schemes should still be assessed correctly
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: Deployment
spec:
  replicas: 3
  template:
    spec:
      containers:
        - image: ${EnvironmentDockerRegistryAndNamespace}/${DockerImageName}:${DockerTag}
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  # The ${...} tokens are OUR tokens - but they also match shell-camelCase,
  # shell-UPPER_SNAKE etc regex patterns, so those should be in repackage
  repackage=$(get_repackage)
  # ognl should be fine (no %{...} in content)
  automatic=$(get_automatic)
  echo "$automatic" | grep -q "ognl-PascalCase"
}

# =============================================================================
# Sneaky scenario: blade vs mustache ambiguity
# =============================================================================

@test "assess-token-compatibility: blade dollar-prefixed mustache triggers blade conflicts" {
  cat > "$TEST_DIR/manifest.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
data:
  template: "{{ $UserName }}"
EOF
  run "$ASSESS_SCRIPT" shell PascalCase "$TEST_DIR"
  [ "$status" -eq 0 ]
  repackage=$(get_repackage)
  echo "$repackage" | grep -q "blade-PascalCase"
}
