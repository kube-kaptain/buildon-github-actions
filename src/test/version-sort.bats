#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)

load helpers

# Helper to run version-sort with input
sort_versions() {
  printf '%s\n' "$@" | "$SCRIPTS_DIR/version-sort"
}

# Helper to assert exact output
assert_output_equals() {
  local expected="$1"
  if [[ "$output" != "$expected" ]]; then
    echo "Expected:"
    echo "$expected"
    echo "Actual:"
    echo "$output"
    return 1
  fi
}

# =============================================================================
# Basic sorting tests
# =============================================================================

@test "sorts basic 3-part versions numerically" {
  run sort_versions "1.2.10" "1.2.3" "1.10.2" "1.2.1"
  [ "$status" -eq 0 ]
  expected="1.2.1
1.2.3
1.2.10
1.10.2"
  assert_output_equals "$expected"
}

@test "sorts single-part versions" {
  run sort_versions "10" "2" "1" "20" "3"
  [ "$status" -eq 0 ]
  expected="1
2
3
10
20"
  assert_output_equals "$expected"
}

@test "sorts two-part versions" {
  run sort_versions "1.10" "1.2" "2.1" "1.20"
  [ "$status" -eq 0 ]
  expected="1.2
1.10
1.20
2.1"
  assert_output_equals "$expected"
}

@test "sorts many-part versions" {
  run sort_versions "1.2.3.4.5.6" "1.2.3.4.5.5" "1.2.3.4.5.10"
  [ "$status" -eq 0 ]
  expected="1.2.3.4.5.5
1.2.3.4.5.6
1.2.3.4.5.10"
  assert_output_equals "$expected"
}

@test "handles large version numbers" {
  run sort_versions "1.999.1000" "1.999.999" "1.1000.1"
  [ "$status" -eq 0 ]
  expected="1.999.999
1.999.1000
1.1000.1"
  assert_output_equals "$expected"
}

# =============================================================================
# Mixed depth tests (core requirement: 1.2 equals 1.2.0 but comes first)
# =============================================================================

@test "1.2 comes before 1.2.0 (fewer parts = older)" {
  run sort_versions "1.2.0" "1.2"
  [ "$status" -eq 0 ]
  expected="1.2
1.2.0"
  assert_output_equals "$expected"
}

@test "1.2.0 comes before 1.2.0.0 (fewer parts = older)" {
  run sort_versions "1.2.0.0" "1.2.0"
  [ "$status" -eq 0 ]
  expected="1.2.0
1.2.0.0"
  assert_output_equals "$expected"
}

@test "mixed depths sort correctly with tie-breaker" {
  run sort_versions "1.2.1" "1.2" "1.2.0" "1.2.0.0"
  [ "$status" -eq 0 ]
  expected="1.2
1.2.0
1.2.0.0
1.2.1"
  assert_output_equals "$expected"
}

@test "1.2 is less than 1.2.1 (missing part = 0)" {
  run sort_versions "1.2.1" "1.2"
  [ "$status" -eq 0 ]
  expected="1.2
1.2.1"
  assert_output_equals "$expected"
}

@test "complex mixed depth scenario" {
  run sort_versions "2.0" "1.10" "1.2.3" "1.2" "1.2.0" "1.2.0.1"
  [ "$status" -eq 0 ]
  expected="1.2
1.2.0
1.2.0.1
1.2.3
1.10
2.0"
  assert_output_equals "$expected"
}

# =============================================================================
# Edge cases
# =============================================================================

@test "handles empty input" {
  run "$SCRIPTS_DIR/version-sort" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "handles single version" {
  run sort_versions "1.2.3"
  [ "$status" -eq 0 ]
  assert_output_equals "1.2.3"
}

@test "handles versions starting with 0" {
  run sort_versions "0.2.1" "0.1.0" "0.10.0"
  [ "$status" -eq 0 ]
  expected="0.1.0
0.2.1
0.10.0"
  assert_output_equals "$expected"
}

@test "handles version 0" {
  run sort_versions "1" "0" "2"
  [ "$status" -eq 0 ]
  expected="0
1
2"
  assert_output_equals "$expected"
}

@test "preserves duplicate versions" {
  run sort_versions "1.2.3" "1.2.3" "1.2.2"
  [ "$status" -eq 0 ]
  expected="1.2.2
1.2.3
1.2.3"
  assert_output_equals "$expected"
}

@test "already sorted input stays sorted" {
  run sort_versions "1.0.0" "1.0.1" "1.1.0" "2.0.0"
  [ "$status" -eq 0 ]
  expected="1.0.0
1.0.1
1.1.0
2.0.0"
  assert_output_equals "$expected"
}

@test "reverse sorted input gets sorted" {
  run sort_versions "2.0.0" "1.1.0" "1.0.1" "1.0.0"
  [ "$status" -eq 0 ]
  expected="1.0.0
1.0.1
1.1.0
2.0.0"
  assert_output_equals "$expected"
}

# =============================================================================
# Real-world scenarios
# =============================================================================

@test "typical semver progression" {
  run sort_versions "1.0.0" "1.0.1" "1.0.10" "1.1.0" "1.10.0" "2.0.0"
  [ "$status" -eq 0 ]
  expected="1.0.0
1.0.1
1.0.10
1.1.0
1.10.0
2.0.0"
  assert_output_equals "$expected"
}

@test "finds highest with tail -n1" {
  result=$(sort_versions "1.2.3" "1.2.10" "1.2.9" | tail -n1)
  [ "$result" = "1.2.10" ]
}

@test "finds highest across different depths" {
  result=$(sort_versions "1.2" "1.2.0" "1.2.1" | tail -n1)
  [ "$result" = "1.2.1" ]
}

@test "1.2 and 1.2.0 - highest is 1.2.0 (comes last due to more parts)" {
  result=$(sort_versions "1.2" "1.2.0" | tail -n1)
  [ "$result" = "1.2.0" ]
}
