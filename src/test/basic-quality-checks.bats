#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export DEFAULT_BRANCH=main
  export TARGET_BRANCH=main
}

teardown() {
  cleanup_test_repo "$TEST_REPO"
}

@test "passes for clean feature branch" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export PR_BRANCH=fix-something
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
  assert_output_contains "All quality checks passed"
}

@test "skips checks on default branch" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"
  git checkout main --quiet

  export PR_BRANCH=main
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
  assert_output_contains "Skipping checks for default branch"
}

@test "blocks GitHub default branch names" {
  TEST_REPO=$(clone_fixture "qc-bad-branch-name")
  cd "$TEST_REPO"

  export PR_BRANCH=testuser-patch-1
  export PR_CREATOR=testuser
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 1 ]
  assert_output_contains "GitHub's default naming pattern"
}

@test "allows branches with slashes by default" {
  TEST_REPO=$(clone_fixture "qc-branch-with-slash")
  cd "$TEST_REPO"

  export PR_BRANCH=feature/something
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
}

@test "blocks slashes when configured" {
  TEST_REPO=$(clone_fixture "qc-branch-with-slash")
  cd "$TEST_REPO"

  export PR_BRANCH=feature/something
  export BLOCK_SLASHES=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 1 ]
  assert_output_contains "contains a slash"
}

@test "blocks Update filename commits" {
  TEST_REPO=$(clone_fixture "qc-update-commit")
  cd "$TEST_REPO"

  export PR_BRANCH=fix-docs
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "GitHub UI default message"
}

@test "blocks Create filename commits" {
  TEST_REPO=$(clone_fixture "qc-create-commit")
  cd "$TEST_REPO"

  export PR_BRANCH=add-file
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "GitHub UI default message"
}

@test "blocks Delete filename commits" {
  TEST_REPO=$(clone_fixture "qc-delete-commit")
  cd "$TEST_REPO"

  export PR_BRANCH=remove-file
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "GitHub UI default message"
}

@test "blocks merge commits" {
  TEST_REPO=$(clone_fixture "qc-merge-commit")
  cd "$TEST_REPO"

  export PR_BRANCH=feature-with-merge
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 4 ]
  assert_output_contains "merge commit"
}

@test "blocks unrebased branches" {
  TEST_REPO=$(clone_fixture "qc-not-rebased")
  cd "$TEST_REPO"

  export PR_BRANCH=old-feature
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 8 ]
  assert_output_contains "not up to date"
}

@test "blocks Update with extra text (copilot style)" {
  TEST_REPO=$(clone_fixture "qc-update-copilot")
  cd "$TEST_REPO"

  export PR_BRANCH=fix-readme
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "GitHub UI default message"
}

@test "accumulates multiple errors with bit flags" {
  TEST_REPO=$(clone_fixture "qc-multiple-issues")
  cd "$TEST_REPO"

  export PR_BRANCH=testuser-patch-1
  export PR_CREATOR=testuser
  run "$SCRIPTS_DIR/basic-quality-checks"
  # Should have both FLAG_BAD_BRANCH (1) and FLAG_BAD_COMMIT (2) = 3
  [ "$status" -eq 3 ]
}

@test "validates target branch in PR context" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export PR_BRANCH=fix-something
  export TARGET_BRANCH=develop
  export GITHUB_HEAD_REF=fix-something
  run "$SCRIPTS_DIR/basic-quality-checks"
  # FLAG_BAD_TARGET = 16, but also FLAG_NOT_REBASED = 8 since develop doesn't exist
  # Actually the script checks if target is allowed first
  [ "$status" -ne 0 ]
  assert_output_contains "not an allowed target"
}

@test "allows configured patch branches as targets" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"
  git checkout main --quiet
  git checkout -b release-1.0.x --quiet
  git checkout fix-something --quiet

  export PR_BRANCH=fix-something
  export TARGET_BRANCH=release-1.0.x
  export ADDITIONAL_RELEASE_BRANCHES="release-1.0.x"
  export GITHUB_HEAD_REF=fix-something
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
}

@test "blocks double hyphens by default" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export PR_BRANCH=fix--something
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 1 ]
  assert_output_contains "double hyphens"
}

@test "allows double hyphens when disabled" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export PR_BRANCH=fix--something
  export BLOCK_DOUBLE_HYPHEN_CONTAINING_BRANCHES=false
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
}

@test "requires branch prefix when enabled" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export PR_BRANCH=my-branch
  export REQUIRE_CONVENTIONAL_BRANCHES=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 1 ]
  assert_output_contains "must start with a prefix"
}

@test "allows branch with valid prefix" {
  TEST_REPO=$(clone_fixture "qc-branch-with-slash")
  cd "$TEST_REPO"

  export PR_BRANCH=feature/my-feature
  export REQUIRE_CONVENTIONAL_BRANCHES=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
  assert_output_contains "has required prefix"
}

@test "requires conventional commits when enabled" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export PR_BRANCH=fix-something
  export REQUIRE_CONVENTIONAL_COMMITS=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "does not use conventional commit format"
}

@test "blocks conventional commits when enabled" {
  TEST_REPO=$(clone_fixture "qc-conventional-commit")
  cd "$TEST_REPO"

  export PR_BRANCH=add-feature
  export BLOCK_CONVENTIONAL_COMMITS=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "conventional commit format which is not allowed"
}
