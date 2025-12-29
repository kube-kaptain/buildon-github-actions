#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for token-name-validators

load helpers

setup() {
  export TEST_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

VALIDATORS_DIR="$PLUGINS_DIR/token-name-validators"

# Create a token file
create_token() {
  local name="$1"
  mkdir -p "$(dirname "$TEST_DIR/$name")"
  printf 'value' > "$TEST_DIR/$name"
}

# === UPPER_SNAKE tests ===

@test "UPPER_SNAKE: accepts valid names" {
  create_token "MY_VAR"
  create_token "MY_VAR_2"
  create_token "MY_2_VAR"
  create_token "A"
  create_token "AB"
  create_token "2_MY_VAR"

  run "$VALIDATORS_DIR/UPPER_SNAKE" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "UPPER_SNAKE: accepts nested paths" {
  create_token "MY_CATEGORY/MY_VAR"
  create_token "MY_CATEGORY/MY_SUB_VAR"
  create_token "A/B/C"

  run "$VALIDATORS_DIR/UPPER_SNAKE" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "UPPER_SNAKE: rejects lowercase" {
  create_token "my_var"

  run "$VALIDATORS_DIR/UPPER_SNAKE" "$TEST_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "my_var"
}

@test "UPPER_SNAKE: rejects kebab-case" {
  create_token "MY-VAR"

  run "$VALIDATORS_DIR/UPPER_SNAKE" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "UPPER_SNAKE: rejects lowercase in nested path" {
  create_token "MY_CATEGORY/my_var"

  run "$VALIDATORS_DIR/UPPER_SNAKE" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

# === lower_snake tests ===

@test "lower_snake: accepts valid names" {
  create_token "my_var"
  create_token "my_var_2"
  create_token "my_2_var"
  create_token "a"
  create_token "2_my_var"

  run "$VALIDATORS_DIR/lower_snake" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "lower_snake: accepts nested paths" {
  create_token "my_category/my_var"
  create_token "my_category/my_sub_var"

  run "$VALIDATORS_DIR/lower_snake" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "lower_snake: rejects uppercase" {
  create_token "MY_VAR"

  run "$VALIDATORS_DIR/lower_snake" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "lower_snake: rejects mixed case in nested path" {
  create_token "my_category/MY_VAR"

  run "$VALIDATORS_DIR/lower_snake" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

# === kebab-case tests ===

@test "kebab-case: accepts valid names" {
  create_token "my-var"
  create_token "my-var-2"
  create_token "my-2-var"
  create_token "a"
  create_token "2-my-var"
  create_token "2-password-secret"

  run "$VALIDATORS_DIR/kebab-case" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "kebab-case: accepts nested paths" {
  create_token "my-category/my-var"
  create_token "my-category/my-sub-var"

  run "$VALIDATORS_DIR/kebab-case" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "kebab-case: rejects underscore" {
  create_token "my_var"

  run "$VALIDATORS_DIR/kebab-case" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "kebab-case: rejects uppercase" {
  create_token "MY-VAR"

  run "$VALIDATORS_DIR/kebab-case" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

# === camelCase tests ===

@test "camelCase: accepts valid names" {
  create_token "myVar"
  create_token "myVar2"
  create_token "my2Var"
  create_token "a"
  create_token "2MyVar"

  run "$VALIDATORS_DIR/camelCase" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "camelCase: accepts nested paths" {
  create_token "myCategory/myVar"
  create_token "myCategory/mySubVar"

  run "$VALIDATORS_DIR/camelCase" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "camelCase: rejects PascalCase" {
  create_token "MyVar"

  run "$VALIDATORS_DIR/camelCase" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "camelCase: rejects underscore" {
  create_token "my_var"

  run "$VALIDATORS_DIR/camelCase" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "camelCase: rejects lowercase after leading digit" {
  create_token "2myVar"

  run "$VALIDATORS_DIR/camelCase" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

# === PascalCase tests ===

@test "PascalCase: accepts valid names" {
  create_token "MyVar"
  create_token "MyVar2"
  create_token "My2Var"
  create_token "A"
  create_token "2MyVar"

  run "$VALIDATORS_DIR/PascalCase" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PascalCase: accepts nested paths" {
  create_token "MyCategory/MyVar"
  create_token "MyCategory/MySubVar"

  run "$VALIDATORS_DIR/PascalCase" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "PascalCase: rejects camelCase" {
  create_token "myVar"

  run "$VALIDATORS_DIR/PascalCase" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "PascalCase: rejects underscore" {
  create_token "My_Var"

  run "$VALIDATORS_DIR/PascalCase" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

# === lower.dot tests ===

@test "lower.dot: accepts valid names" {
  create_token "my.var"
  create_token "my.var.2"
  create_token "my.2.var"
  create_token "a"
  create_token "2.my.var"

  run "$VALIDATORS_DIR/lower.dot" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "lower.dot: accepts nested paths" {
  create_token "my.category/my.var"
  create_token "my.category/my.sub.var"

  run "$VALIDATORS_DIR/lower.dot" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "lower.dot: rejects uppercase" {
  create_token "MY.VAR"

  run "$VALIDATORS_DIR/lower.dot" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "lower.dot: rejects hidden files" {
  create_token ".gitkeep"

  run "$VALIDATORS_DIR/lower.dot" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

# === UPPER.DOT tests ===

@test "UPPER.DOT: accepts valid names" {
  create_token "MY.VAR"
  create_token "MY.VAR.2"
  create_token "MY.2.VAR"
  create_token "A"
  create_token "2.MY.VAR"

  run "$VALIDATORS_DIR/UPPER.DOT" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "UPPER.DOT: accepts nested paths" {
  create_token "MY.CATEGORY/MY.VAR"
  create_token "MY.CATEGORY/MY.SUB.VAR"

  run "$VALIDATORS_DIR/UPPER.DOT" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "UPPER.DOT: rejects lowercase" {
  create_token "my.var"

  run "$VALIDATORS_DIR/UPPER.DOT" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

# === ALL tests ===

@test "ALL: accepts any valid style" {
  create_token "MY_VAR"
  create_token "my_var"
  create_token "my-var"
  create_token "myVar"
  create_token "MyVar"
  create_token "my.var"
  create_token "2"
  create_token "a2"
  create_token "2a"

  run "$VALIDATORS_DIR/ALL" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "ALL: accepts nested paths with mixed styles" {
  create_token "my-category/MY_VAR"
  create_token "MyCategory/my.var"

  run "$VALIDATORS_DIR/ALL" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "ALL: rejects hidden files" {
  create_token ".gitkeep"

  run "$VALIDATORS_DIR/ALL" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "ALL: rejects leading hyphen" {
  create_token "-leading"

  run "$VALIDATORS_DIR/ALL" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "ALL: rejects trailing hyphen" {
  create_token "trailing-"

  run "$VALIDATORS_DIR/ALL" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

@test "ALL: rejects special characters" {
  create_token "my;var"

  run "$VALIDATORS_DIR/ALL" "$TEST_DIR"
  [ "$status" -ne 0 ]
}

# === Common behavior tests ===

@test "empty directory succeeds" {
  run "$VALIDATORS_DIR/UPPER_SNAKE" "$TEST_DIR"
  [ "$status" -eq 0 ]
}

@test "nonexistent directory fails" {
  run "$VALIDATORS_DIR/UPPER_SNAKE" "/nonexistent"
  [ "$status" -ne 0 ]
  assert_output_contains "not found"
}

@test "lists all invalid names" {
  create_token "VALID_NAME"
  create_token "invalid-name"
  create_token "also_invalid"

  run "$VALIDATORS_DIR/UPPER_SNAKE" "$TEST_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "invalid-name"
  assert_output_contains "also_invalid"
}
