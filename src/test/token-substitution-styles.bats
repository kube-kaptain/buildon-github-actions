#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Parameterized tests for all token substitution styles
#
# Each style uses different delimiters but the same substitution logic.
# This file runs identical test cases across all styles to ensure consistent behavior.

load helpers

setup() {
  export TOKENS_DIR=$(mktemp -d)
  export TARGET_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TOKENS_DIR"
  rm -rf "$TARGET_DIR"
}

# Style definitions: name|token-pattern-template
# The template uses TOKEN as placeholder for the actual token name
STYLES=(
  "shell|\${TOKEN}"
  "mustache|{{ TOKEN }}"
  "helm|{{ .Values.TOKEN }}"
  "erb|<%= TOKEN %>"
  "github-actions|\${{ TOKEN }}"
  "blade|{{ \$TOKEN }}"
  "stringtemplate|\$TOKEN\$"
  "ognl|%{TOKEN}"
  "t4|<#= TOKEN #>"
  "swift|\\(TOKEN)"
)

# Generate token reference for a given style and token name
make_token_ref() {
  local style="$1"
  local token_name="$2"

  case "$style" in
    shell) echo "\${$token_name}" ;;
    mustache) echo "{{ $token_name }}" ;;
    helm) echo "{{ .Values.$token_name }}" ;;
    erb) echo "<%= $token_name %>" ;;
    github-actions) echo "\${{ $token_name }}" ;;
    blade) echo "{{ \$$token_name }}" ;;
    stringtemplate) echo "\$$token_name\$" ;;
    ognl) echo "%{$token_name}" ;;
    t4) echo "<#= $token_name #>" ;;
    swift) echo "\\($token_name)" ;;
  esac
}

# Create a token file
create_token() {
  local name="$1"
  local value="$2"
  mkdir -p "$(dirname "$TOKENS_DIR/$name")"
  printf '%s' "$value" > "$TOKENS_DIR/$name"
}

# Create a target file
create_target() {
  local filename="$1"
  local content="$2"
  mkdir -p "$(dirname "$TARGET_DIR/$filename")"
  printf '%s' "$content" > "$TARGET_DIR/$filename"
}

# Run substitution for a given style
run_substitution() {
  local style="$1"
  cd "$TOKENS_DIR"
  "$SCRIPTS_DIR/substitute-tokens-from-dir" "$style" "$TOKENS_DIR" "$TARGET_DIR"
}

# === Parameterized Tests ===
# Each test iterates through all styles

@test "all styles: basic substitution" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    # Reset directories
    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "ProjectName" "my-app"
    local token_ref=$(make_token_ref "$style" "ProjectName")
    create_target "test.yaml" "name: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "name: my-app" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: value with slashes" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "DockerImage" "org/repo/image"
    local token_ref=$(make_token_ref "$style" "DockerImage")
    create_target "test.yaml" "image: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "image: org/repo/image" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: value with commas" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "Tags" "tag1,tag2,tag3"
    local token_ref=$(make_token_ref "$style" "Tags")
    create_target "test.yaml" "tags: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "tags: tag1,tag2,tag3" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: value with special regex characters" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "Pattern" ".*[a-z]+\\d{3}"
    local token_ref=$(make_token_ref "$style" "Pattern")
    create_target "test.yaml" "regex: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = 'regex: .*[a-z]+\d{3}' ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: multiple occurrences in same file" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "Version" "1.2.3"
    local token_ref=$(make_token_ref "$style" "Version")
    create_target "test.yaml" "v1: $token_ref
v2: $token_ref
v3: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    grep -q "v1: 1.2.3" "$TARGET_DIR/test.yaml" || { echo "Failed v1 for style: $style"; return 1; }
    grep -q "v2: 1.2.3" "$TARGET_DIR/test.yaml" || { echo "Failed v2 for style: $style"; return 1; }
    grep -q "v3: 1.2.3" "$TARGET_DIR/test.yaml" || { echo "Failed v3 for style: $style"; return 1; }
  done
}

@test "all styles: multiple files" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "Name" "test-value"
    local token_ref=$(make_token_ref "$style" "Name")
    create_target "file1.yaml" "name: $token_ref"
    create_target "subdir/file2.yaml" "name: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    [ "$(cat "$TARGET_DIR/file1.yaml")" = "name: test-value" ] || { echo "Failed file1 for style: $style"; return 1; }
    [ "$(cat "$TARGET_DIR/subdir/file2.yaml")" = "name: test-value" ] || { echo "Failed file2 for style: $style"; return 1; }
  done
}

@test "all styles: leaves other tokens untouched" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "Defined" "defined-value"
    local defined_ref=$(make_token_ref "$style" "Defined")
    local undefined_ref=$(make_token_ref "$style" "Undefined")
    create_target "test.yaml" "a: $defined_ref
b: $undefined_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    grep -q "a: defined-value" "$TARGET_DIR/test.yaml" || { echo "Failed defined for style: $style"; return 1; }
    # Use grep -F for fixed string matching (no regex/variable expansion issues)
    grep -qF "b: $undefined_ref" "$TARGET_DIR/test.yaml" || { echo "Failed undefined for style: $style"; return 1; }
  done
}

@test "all styles: does not substitute partial matches" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "Name" "value"
    local longer_ref=$(make_token_ref "$style" "NameExtra")
    create_target "test.yaml" "key: $longer_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "key: $longer_ref" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: nested token path" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    mkdir -p "$TOKENS_DIR/category"
    printf '%s' "nested-value" > "$TOKENS_DIR/category/sub-var"
    local token_ref=$(make_token_ref "$style" "category/sub-var")
    create_target "test.yaml" "value: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "value: nested-value" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: self-referential token (pass-through)" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    # Token value is itself - should substitute once and stop (no infinite loop)
    local token_ref=$(make_token_ref "$style" "ProjectName")
    printf '%s' "$token_ref" > "$TOKENS_DIR/ProjectName"
    create_target "test.yaml" "name: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "name: $token_ref" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: empty token value" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    printf '' > "$TOKENS_DIR/Empty"
    local token_ref=$(make_token_ref "$style" "Empty")
    create_target "test.yaml" "prefix-${token_ref}-suffix"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "prefix--suffix" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: preserves file without trailing newline" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "Var" "value"
    local token_ref=$(make_token_ref "$style" "Var")
    printf 'key: %s' "$token_ref" > "$TARGET_DIR/test.txt"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.txt")
    [ "$result" = "key: value" ] || { echo "Failed for style: $style - got: $result"; return 1; }

    # Verify no trailing newline was added
    local last_byte=$(tail -c 1 "$TARGET_DIR/test.txt" | od -An -tx1 | tr -d ' ')
    [ "$last_byte" = "65" ] || { echo "Trailing newline added for style: $style"; return 1; }  # 65 = 'e' in hex
  done
}

@test "all styles: preserves file with trailing newline" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "Var" "value"
    local token_ref=$(make_token_ref "$style" "Var")
    printf 'key: %s\n' "$token_ref" > "$TARGET_DIR/test.txt"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local content
    content=$(cat "$TARGET_DIR/test.txt" && echo x)
    content="${content%x}"
    [ "$content" = $'key: value\n' ] || { echo "Failed for style: $style"; return 1; }
  done
}

@test "all styles: strip-for-single-line mode" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    printf 'my-value\n' > "$TOKENS_DIR/SingleLine"
    local token_ref=$(make_token_ref "$style" "SingleLine")
    create_target "test.yaml" "key: $token_ref"

    cd "$TOKENS_DIR"
    CONFIG_VALUE_TRAILING_NEWLINE="strip-for-single-line" \
    run "$SCRIPTS_DIR/substitute-tokens-from-dir" "$style" "$TOKENS_DIR" "$TARGET_DIR"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "key: my-value" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: preserve-all mode" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    printf 'my-value\n' > "$TOKENS_DIR/SingleLine"
    local token_ref=$(make_token_ref "$style" "SingleLine")
    create_target "test.yaml" "key: ${token_ref}suffix"

    cd "$TOKENS_DIR"
    CONFIG_VALUE_TRAILING_NEWLINE="preserve-all" \
    run "$SCRIPTS_DIR/substitute-tokens-from-dir" "$style" "$TOKENS_DIR" "$TARGET_DIR"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local content=$(cat "$TARGET_DIR/test.yaml")
    [[ "$content" == *$'\n'* ]] || { echo "No newline for style: $style"; return 1; }
    [[ "$content" == "key: my-value"$'\n'"suffix" ]] || { echo "Failed for style: $style - got: $content"; return 1; }
  done
}

@test "all styles: always-strip-one-newline mode" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    printf 'my-value\n\n' > "$TOKENS_DIR/DoubleNewline"
    local token_ref=$(make_token_ref "$style" "DoubleNewline")
    create_target "test.yaml" "key: ${token_ref}suffix"

    cd "$TOKENS_DIR"
    CONFIG_VALUE_TRAILING_NEWLINE="always-strip-one-newline" \
    run "$SCRIPTS_DIR/substitute-tokens-from-dir" "$style" "$TOKENS_DIR" "$TARGET_DIR"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local content=$(cat "$TARGET_DIR/test.yaml")
    [[ "$content" == "key: my-value"$'\n'"suffix" ]] || { echo "Failed for style: $style - got: $content"; return 1; }
  done
}

@test "all styles: multi-line value preserves internal newlines" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    printf 'line1\nline2\nline3' > "$TOKENS_DIR/MultiLine"
    local token_ref=$(make_token_ref "$style" "MultiLine")
    create_target "test.yaml" "data: |
  $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    grep -q "line1" "$TARGET_DIR/test.yaml" || { echo "Missing line1 for style: $style"; return 1; }
    grep -q "line2" "$TARGET_DIR/test.yaml" || { echo "Missing line2 for style: $style"; return 1; }
    grep -q "line3" "$TARGET_DIR/test.yaml" || { echo "Missing line3 for style: $style"; return 1; }
  done
}

@test "all styles: kebab-case token name" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "my-token-name" "kebab-value"
    local token_ref=$(make_token_ref "$style" "my-token-name")
    create_target "test.yaml" "key: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "key: kebab-value" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: UPPER_SNAKE token name" {
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    create_token "MY_TOKEN_NAME" "snake-value"
    local token_ref=$(make_token_ref "$style" "MY_TOKEN_NAME")
    create_target "test.yaml" "key: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "key: snake-value" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}

@test "all styles: value containing style's own delimiters" {
  # Test that a value containing the style's delimiters doesn't cause issues
  for style_def in "${STYLES[@]}"; do
    local style="${style_def%%|*}"

    rm -rf "$TOKENS_DIR"/* "$TARGET_DIR"/*

    # Create a value that contains delimiters from this style
    local tricky_value=$(make_token_ref "$style" "SomeOther")
    create_token "Token" "$tricky_value"
    local token_ref=$(make_token_ref "$style" "Token")
    create_target "test.yaml" "key: $token_ref"

    run run_substitution "$style"
    [ "$status" -eq 0 ] || { echo "Failed for style: $style"; return 1; }

    local result=$(cat "$TARGET_DIR/test.yaml")
    [ "$result" = "key: $tricky_value" ] || { echo "Failed for style: $style - got: $result"; return 1; }
  done
}
