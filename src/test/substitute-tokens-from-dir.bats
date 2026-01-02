#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for substitute-tokens-from-dir (orchestrator script)

load helpers

setup() {
  export TOKENS_DIR=$(mktemp -d)
  export TARGET_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TOKENS_DIR"
  rm -rf "$TARGET_DIR"
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

@test "substitutes multiple tokens" {
  create_token "ProjectName" "my-app"
  create_token "Version" "1.2.3"
  create_target "test.yaml" 'name: ${ProjectName}
version: ${Version}'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  grep -q "name: my-app" "$TARGET_DIR/test.yaml"
  grep -q "version: 1.2.3" "$TARGET_DIR/test.yaml"
}

@test "processes tokens in sorted order" {
  # Token 'bar' contains reference to 'foo'
  # Since 'bar' < 'foo' alphabetically, bar is processed first
  # bar's value ${foo} is inserted literally, then foo substitutes ${foo}
  create_token "bar" '${foo}'
  create_token "foo" "actual-value"
  create_target "test.yaml" 'result: ${bar}'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  # bar processed first: ${bar} -> ${foo}
  # foo processed second: ${foo} -> actual-value
  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "result: actual-value" ]
}

@test "fails with unknown token style" {
  create_token "Var" "value"
  create_target "test.yaml" 'key: ${Var}'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" unknown-style "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown token style"
}

@test "fails when tokens directory not found" {
  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "/nonexistent" "$TARGET_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "not found"
}

@test "fails when target directory not found" {
  create_token "Var" "value"

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "/nonexistent"
  [ "$status" -ne 0 ]
  assert_output_contains "not found"
}

@test "fails with symlink in tokens directory" {
  create_token "RealToken" "real-value"
  ln -s RealToken "$TOKENS_DIR/SymlinkToken"
  create_target "test.yaml" 'key: ${RealToken}'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "Symlinks not allowed"
  assert_output_contains "SymlinkToken"
}

@test "fails with binary file in tokens directory" {
  printf 'binary\x00content' > "$TOKENS_DIR/BinaryToken"
  create_target "test.yaml" 'key: ${BinaryToken}'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "Binary files"
  assert_output_contains "BinaryToken"
}

@test "handles nested token directories" {
  mkdir -p "$TOKENS_DIR/category"
  printf '%s' "nested-value" > "$TOKENS_DIR/category/sub-var"
  create_target "test.yaml" 'value: ${category/sub-var}'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "value: nested-value" ]
}

@test "empty tokens directory succeeds" {
  create_target "test.yaml" 'unchanged: ${NotSubstituted}'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = 'unchanged: ${NotSubstituted}' ]
}

@test "passes CONFIG_VALUE_TRAILING_NEWLINE to provider" {
  printf 'my-value\n' > "$TOKENS_DIR/Var"
  create_target "test.yaml" 'key: ${Var}'

  CONFIG_VALUE_TRAILING_NEWLINE="strip-for-single-line" \
  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "key: my-value" ]
}

@test "lists all symlinks when multiple found" {
  create_token "RealToken" "real-value"
  ln -s RealToken "$TOKENS_DIR/Symlink1"
  ln -s RealToken "$TOKENS_DIR/Symlink2"
  create_target "test.yaml" 'key: value'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "Symlink1"
  assert_output_contains "Symlink2"
}

@test "lists all binary files when multiple found" {
  printf 'binary\x00content' > "$TOKENS_DIR/Binary1"
  printf 'more\x00binary' > "$TOKENS_DIR/Binary2"
  create_target "test.yaml" 'key: value'

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "Binary1"
  assert_output_contains "Binary2"
}
