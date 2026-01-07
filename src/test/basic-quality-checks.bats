#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export DEFAULT_BRANCH=main
  export TARGET_BRANCH=main
  export CURRENT_BRANCH=test-branch
}

teardown() {
  cleanup_test_repo "$TEST_REPO"
}

@test "fails when release-branch differs from default-branch" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export DEFAULT_BRANCH=main
  export RELEASE_BRANCH=develop
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 1 ]
  assert_output_contains "RELEASE_BRANCH (develop) must match DEFAULT_BRANCH (main)"
}

@test "fails when additional-release-branch not prefixed with release-branch" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export ADDITIONAL_RELEASE_BRANCHES="release-1.0.x"
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 1 ]
  assert_output_contains "must start with 'main' followed by a divider"
}

@test "accepts additional-release-branches with valid prefixes" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  # All valid dividers: . - / _ +
  export ADDITIONAL_RELEASE_BRANCHES="main-1.0,main.hotfix,main/patch,main_test,main+experimental"
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
}

@test "passes for clean feature branch" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
  assert_output_contains "All quality checks passed"
}

@test "fails when TARGET_BRANCH not set (non-PR context)" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  unset TARGET_BRANCH
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -ne 0 ]
  assert_output_contains "TARGET_BRANCH"
  assert_output_contains "Is required"
}

@test "fails when run on release branch" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=main
  export TARGET_BRANCH=feature-branch
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 1 ]
  assert_output_contains "should not run on release branches"
}

@test "blocks GitHub default branch names" {
  TEST_REPO=$(clone_fixture "qc-bad-branch-name")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=testuser-patch-1
  export MERGE_CANDIDATE_CREATOR=testuser
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "GitHub's default naming pattern"
}

@test "allows branches with slashes by default" {
  TEST_REPO=$(clone_fixture "qc-branch-with-slash")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=feature/something
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
}

@test "blocks slashes when configured" {
  TEST_REPO=$(clone_fixture "qc-branch-with-slash")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=feature/something
  export BLOCK_SLASHES=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "contains a slash"
}

@test "blocks Update filename commits" {
  TEST_REPO=$(clone_fixture "qc-update-commit")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 4 ]
  assert_output_contains "GitHub UI default message"
}

@test "blocks Create filename commits" {
  TEST_REPO=$(clone_fixture "qc-create-commit")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 4 ]
  assert_output_contains "GitHub UI default message"
}

@test "blocks Delete filename commits" {
  TEST_REPO=$(clone_fixture "qc-delete-commit")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 4 ]
  assert_output_contains "GitHub UI default message"
}

@test "blocks merge commits" {
  TEST_REPO=$(clone_fixture "qc-merge-commit")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 8 ]
  assert_output_contains "merge commit"
}

@test "blocks unrebased branches" {
  TEST_REPO=$(clone_fixture "qc-not-rebased")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 8 ]
  assert_output_contains "not up to date"
}

@test "blocks Update with extra text (copilot style)" {
  TEST_REPO=$(clone_fixture "qc-update-copilot")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 4 ]
  assert_output_contains "GitHub UI default message"
}

@test "accumulates multiple errors with bit flags" {
  TEST_REPO=$(clone_fixture "qc-multiple-issues")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=testuser-patch-1
  export MERGE_CANDIDATE_CREATOR=testuser
  run "$SCRIPTS_DIR/basic-quality-checks"
  # Should have both FLAG_BAD_BRANCH (2) and FLAG_BAD_COMMIT (4) = 6
  [ "$status" -eq 6 ]
}

@test "validates target branch in PR context" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export TARGET_BRANCH=develop
  run "$SCRIPTS_DIR/basic-quality-checks"
  # FLAG_BAD_SETUP = 16 since develop is not a release branch
  [ "$status" -ne 0 ]
  assert_output_contains "not a release branch"
}

@test "allows configured patch branches as targets" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"
  git checkout main --quiet
  git checkout -b main-1.0.x --quiet
  git checkout fix-something --quiet

  export CURRENT_BRANCH=fix-something
  export TARGET_BRANCH=main-1.0.x
  export ADDITIONAL_RELEASE_BRANCHES="main-1.0.x"
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
}

@test "blocks release branch to release branch PRs" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"
  git checkout main --quiet
  git checkout -b main-1.0.x --quiet

  export CURRENT_BRANCH=main-1.0.x
  export TARGET_BRANCH=main
  export ADDITIONAL_RELEASE_BRANCHES="main-1.0.x"
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 16 ]
  assert_output_contains "Use cherry-pick to move changes between release branches"
}

@test "blocks double hyphens by default" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=fix--something
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "double hyphens"
}

@test "allows double hyphens when disabled" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=fix--something
  export BLOCK_DOUBLE_HYPHEN_CONTAINING_BRANCHES=false
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
}

@test "requires branch prefix when enabled" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=my-branch
  export REQUIRE_CONVENTIONAL_BRANCHES=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 2 ]
  assert_output_contains "must start with a prefix"
}

@test "allows branch with valid prefix" {
  TEST_REPO=$(clone_fixture "qc-branch-with-slash")
  cd "$TEST_REPO"

  export CURRENT_BRANCH=feature/my-feature
  export REQUIRE_CONVENTIONAL_BRANCHES=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
  assert_output_contains "has required prefix"
}

@test "requires conventional commits when enabled" {
  TEST_REPO=$(clone_fixture "qc-clean")
  cd "$TEST_REPO"

  export REQUIRE_CONVENTIONAL_COMMITS=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 4 ]
  assert_output_contains "does not use conventional commit format"
}

@test "blocks conventional commits when enabled" {
  TEST_REPO=$(clone_fixture "qc-conventional-commit")
  cd "$TEST_REPO"

  export BLOCK_CONVENTIONAL_COMMITS=true
  run "$SCRIPTS_DIR/basic-quality-checks"
  [ "$status" -eq 4 ]
  assert_output_contains "conventional commit format which is not allowed"
}
