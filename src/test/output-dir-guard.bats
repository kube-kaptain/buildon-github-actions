#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/output-dir-guard.bash: the checks made before an output dir is
# wiped. The callers' own suites (validate-tooling, load-final-kaptainpm-yaml)
# cover the wiring; this covers the rules.

bats_require_minimum_version 1.5.0

load helpers

setup() {
  REPO_DIR=$(create_test_dir "output-dir-guard")
  # Stands in for anything outside the repository a link could lead to
  OUTSIDE_DIR=$(create_test_dir "outside")
  mkdir -p "${OUTSIDE_DIR}/out"
  printf 'keep' > "${OUTSIDE_DIR}/out/marker"
  cd "${REPO_DIR}"
  # shellcheck source=src/scripts/lib/output-dir-guard.bash
  source "$LIB_DIR/output-dir-guard.bash"
}

teardown() {
  dump_bats_result
}

# =============================================================================
# Paths that are safe to wipe
# =============================================================================

@test "a path that does not exist yet passes, nested or not" {
  run assert_safe_output_dir "outputSubPath" "kaptain-out"
  [[ "$status" -eq 0 ]] || return 1
  run assert_safe_output_dir "outputSubPath" "build/out"
  [[ "$status" -eq 0 ]] || return 1
}

@test "an existing real directory passes, under real parents" {
  mkdir -p build/out/earlier-run
  run assert_safe_output_dir "outputSubPath" "build/out"
  [[ "$status" -eq 0 ]] || return 1
  run assert_safe_output_dir "outputSubPath" "build/out/not-there-yet"
  [[ "$status" -eq 0 ]] || return 1
}

# =============================================================================
# Path text
# =============================================================================

@test "paths that are not plain repository-relative ones fail" {
  local value
  for value in /tmp/out out/ './out' 'a/../b' '..' '.' 'a//b' ''; do
    run assert_safe_output_dir "outputSubPath" "${value}"
    [[ "$status" -eq 1 ]] || { echo "accepted: [${value}]"; return 1; }
    [[ "$output" == *"must be a path relative to the repository root"* ]] || { echo "wrong error for: [${value}]"; return 1; }
  done
}

@test ".git, kaptainpm and src fail, and so does anything inside them" {
  local value
  for value in .git .git/out kaptainpm kaptainpm/out src src/out; do
    run assert_safe_output_dir "outputSubPath" "${value}"
    [[ "$status" -eq 1 ]] || { echo "accepted: ${value}"; return 1; }
    [[ "$output" == *"must not be ${value%%/*} or inside it"* ]] || { echo "wrong error for: ${value}"; return 1; }
  done
}

@test "a directory holding git-tracked files fails" {
  mkdir -p docs
  printf 'mine' > docs/README.md
  git init -q
  git add docs/README.md
  run assert_safe_output_dir "outputSubPath" "docs"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"holds files tracked by git"* ]] || return 1
}

# =============================================================================
# Symbolic links: rm -rf and mv would follow one out of the repository
# =============================================================================

@test "a symlinked parent leading outside the repository fails" {
  ln -s "${OUTSIDE_DIR}" linked
  run assert_safe_output_dir "outputSubPath" "linked/out"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"outputSubPath linked/out is or passes through a symbolic link (linked)"* ]] || return 1
}

@test "a symlinked parent deeper in the path fails" {
  mkdir -p real
  ln -s "${OUTSIDE_DIR}" real/linked
  run assert_safe_output_dir "outputSubPath" "real/linked/out"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"symbolic link (real/linked)"* ]] || return 1
}

@test "the output dir itself being a symlink fails" {
  ln -s "${OUTSIDE_DIR}/out" kaptain-out
  run assert_safe_output_dir "outputSubPath" "kaptain-out"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"symbolic link (kaptain-out)"* ]] || return 1
}

@test "a symlink that stays inside the repository fails too" {
  mkdir -p real
  ln -s real linked
  run assert_safe_output_dir "outputSubPath" "linked/out"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"symbolic link (linked)"* ]] || return 1
}

@test "a dangling symlink fails" {
  ln -s "${OUTSIDE_DIR}/not-there" linked
  run assert_safe_output_dir "outputSubPath" "linked/out"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"symbolic link (linked)"* ]] || return 1
}

# =============================================================================
# Anything else that is not a directory
# =============================================================================

@test "a regular file where the output dir or a parent should be fails" {
  printf 'notes' > notes.txt
  run assert_safe_output_dir "outputSubPath" "notes.txt"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"notes.txt exists and is not a directory"* ]] || return 1
  run assert_safe_output_dir "outputSubPath" "notes.txt/out"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"notes.txt exists and is not a directory"* ]] || return 1
}
