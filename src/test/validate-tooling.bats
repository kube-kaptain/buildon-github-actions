#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/validate-tooling: wiping the output dir as the first step of
# every build. The tool checks themselves depend on the host, so these tests
# assert only the wipe and its guards, never the overall status.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/validate-tooling"

setup() {
  TEST_DIR=$(create_test_dir "validate-tooling")
  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"
  export BUILD_MODE="local"
  unset OUTPUT_SUB_PATH
}

teardown() {
  dump_bats_result
}

# Usage: run_in <dir>
run_in() {
  run bash -c "cd '${1}' && '${SCRIPT}'"
}

@test "validate-tooling: a stale default output dir is wiped" {
  mkdir -p "${TEST_DIR}/kaptain-out/earlier-run"
  printf 'old' > "${TEST_DIR}/kaptain-out/earlier-run/file"
  run_in "${TEST_DIR}"
  [[ "$output" != *"OUTPUT_SUB_PATH must"* ]] || return 1
  [[ ! -e "${TEST_DIR}/kaptain-out" ]] || return 1
}

@test "validate-tooling: a stale output dir set in the env is wiped" {
  export OUTPUT_SUB_PATH="build/out"
  mkdir -p "${TEST_DIR}/build/out"
  printf 'old' > "${TEST_DIR}/build/out/file"
  run_in "${TEST_DIR}"
  [[ ! -e "${TEST_DIR}/build/out" ]] || return 1
  [[ -d "${TEST_DIR}/build" ]] || return 1
}

@test "validate-tooling: unsafe output dirs fail before anything is wiped" {
  local value
  mkdir -p "${TEST_DIR}/kaptainpm/final" "${TEST_DIR}/src/out"
  printf 'keep' > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml"
  printf 'keep' > "${TEST_DIR}/src/out/file"
  for value in /tmp/kaptain-out out/ './out' 'a/../b' '..' '.' 'a//b' '.git/out' kaptainpm src/out; do
    OUTPUT_SUB_PATH="${value}" run_in "${TEST_DIR}"
    [[ "$status" -eq 1 ]] || { echo "accepted: ${value}"; return 1; }
    [[ "$output" == *"OUTPUT_SUB_PATH"* ]] || { echo "wrong error for: ${value}"; return 1; }
  done
  [[ -f "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml" ]] || return 1
  [[ -f "${TEST_DIR}/src/out/file" ]] || return 1
}

@test "validate-tooling: an output dir holding git-tracked files fails" {
  local repo="${TEST_DIR}/repo"
  mkdir -p "${repo}/docs"
  printf 'mine' > "${repo}/docs/README.md"
  git -C "${repo}" init -q
  git -C "${repo}" add docs/README.md
  OUTPUT_SUB_PATH="docs" run_in "${repo}"
  [[ "$status" -eq 1 ]] || return 1
  assert_output_contains "holds files tracked by git"
  [[ -f "${repo}/docs/README.md" ]] || return 1
}

@test "validate-tooling: an output dir through a symlinked parent fails and nothing outside is wiped" {
  local outside
  outside=$(create_test_dir "outside")
  mkdir -p "${outside}/out"
  printf 'keep' > "${outside}/out/marker"
  ln -s "${outside}" "${TEST_DIR}/linked"
  OUTPUT_SUB_PATH="linked/out" run_in "${TEST_DIR}"
  [[ "$status" -eq 1 ]] || return 1
  assert_output_contains "OUTPUT_SUB_PATH linked/out is or passes through a symbolic link (linked)"
  [[ -f "${outside}/out/marker" ]] || return 1
}
