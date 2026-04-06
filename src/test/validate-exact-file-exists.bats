#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  source "$LIB_DIR/validate-exact-file-exists.bash"
  TEST_DIR=$(create_test_dir "validate-exact-file-exists")
}

# === Directory validation ===

@test "fails when directory does not exist" {
  run validate_exact_file_exists "${TEST_DIR}/nonexistent" "KaptainPM.yaml"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Directory"*"does not exist"* ]]
}

# === File not found ===

@test "fails when file not found" {
  mkdir -p "${TEST_DIR}/empty"
  run validate_exact_file_exists "${TEST_DIR}/empty" "KaptainPM.yaml"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"not found"* ]]
}

# === Case mismatch ===

@test "fails when file exists with wrong case" {
  mkdir -p "${TEST_DIR}/wrongcase"
  echo "test" > "${TEST_DIR}/wrongcase/kaptainpm.yaml"
  run validate_exact_file_exists "${TEST_DIR}/wrongcase" "KaptainPM.yaml"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"case mismatch"* ]]
}

# === Exact match ===

@test "passes when file exists with exact case" {
  mkdir -p "${TEST_DIR}/correct"
  echo "test" > "${TEST_DIR}/correct/KaptainPM.yaml"
  run validate_exact_file_exists "${TEST_DIR}/correct" "KaptainPM.yaml"
  [[ "$status" -eq 0 ]]
}

# === Duplicate detection (Linux only - case-insensitive FS cannot create both) ===

@test "fails when multiple case variants exist" {
  mkdir -p "${TEST_DIR}/dupes"
  echo "test" > "${TEST_DIR}/dupes/KaptainPM.yaml"
  echo "test" > "${TEST_DIR}/dupes/kaptainpm.yaml"
  # On case-insensitive FS these are the same file, so skip
  local count=0
  for f in "${TEST_DIR}/dupes"/*; do
    [[ -e "$f" ]] && count=$((count + 1))
  done
  if [[ "$count" -lt 2 ]]; then
    skip "case-insensitive filesystem cannot create duplicate case variants"
  fi
  run validate_exact_file_exists "${TEST_DIR}/dupes" "KaptainPM.yaml"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Multiple files"* ]]
}

# === file_exists_any_case ===

@test "file_exists_any_case: returns 1 when directory does not exist" {
  run file_exists_any_case "${TEST_DIR}/nonexistent-any" "KaptainPM.yaml"
  [[ "$status" -eq 1 ]]
  [[ -z "$output" ]]
}

@test "file_exists_any_case: returns 1 when file not found" {
  mkdir -p "${TEST_DIR}/empty-any"
  run file_exists_any_case "${TEST_DIR}/empty-any" "KaptainPM.yaml"
  [[ "$status" -eq 1 ]]
  [[ -z "$output" ]]
}

@test "file_exists_any_case: returns 0 on exact match" {
  mkdir -p "${TEST_DIR}/exact-any"
  echo "test" > "${TEST_DIR}/exact-any/KaptainPM.yaml"
  run file_exists_any_case "${TEST_DIR}/exact-any" "KaptainPM.yaml"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "file_exists_any_case: returns 0 on case-mismatched match" {
  mkdir -p "${TEST_DIR}/mismatch-any"
  echo "test" > "${TEST_DIR}/mismatch-any/kaptainpm.yaml"
  run file_exists_any_case "${TEST_DIR}/mismatch-any" "KaptainPM.yaml"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "file_exists_any_case: returns 0 when sibling files are present and a case variant matches" {
  mkdir -p "${TEST_DIR}/siblings-any"
  echo "test" > "${TEST_DIR}/siblings-any/other.txt"
  echo "test" > "${TEST_DIR}/siblings-any/KAPTAINPM.YAML"
  run file_exists_any_case "${TEST_DIR}/siblings-any" "KaptainPM.yaml"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}
