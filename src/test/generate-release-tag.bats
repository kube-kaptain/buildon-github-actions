#!/usr/bin/env bats

load helpers

setup() {
  export DEFAULT_BRANCH=main
  setup_mock_git
}

teardown() {
  cleanup_test_repo "$TEST_REPO"
  cleanup_mock_git
}

@test "generates 1.0.0 for repo with no tags" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.0"
  assert_var_equals "VERSION_MAJOR" "1"
  assert_var_equals "VERSION_MINOR" "0"
  assert_var_equals "VERSION_PATCH" "0"
  assert_var_equals "VERSION_2_PART" "1.0"
  assert_var_equals "VERSION_3_PART" "1.0.0"
  assert_var_equals "VERSION_4_PART" "1.0.0.0"
}

@test "increments patch version from 1.0.0" {
  TEST_REPO=$(clone_fixture "tag-semver3")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.1"
}

@test "increments minor version for two-part tags" {
  TEST_REPO=$(clone_fixture "tag-semver2")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.3"
  assert_var_equals "VERSION_2_PART" "1.3"
  assert_var_equals "VERSION_3_PART" "1.3.0"
}

@test "increments last component for four-part versions" {
  TEST_REPO=$(clone_fixture "tag-semver4")
  cd "$TEST_REPO"
  export MAX_VERSION_PARTS=4

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.3.5"
  assert_var_equals "VERSION_3_PART" "1.2.3"
  assert_var_equals "VERSION_4_PART" "1.2.3.5"
}

@test "strips v prefix from existing tags" {
  TEST_REPO=$(clone_fixture "tag-vprefixed")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.1"
}

@test "finds highest tag across multiple" {
  TEST_REPO=$(clone_fixture "tag-multiple")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.3"
}

@test "sets IS_RELEASE=true on default branch" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "true"
}

@test "sets IS_RELEASE=false on feature branch" {
  TEST_REPO=$(clone_fixture "tag-feature-branch")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "false"
}

@test "adds PRERELEASE suffix on non-release branch" {
  TEST_REPO=$(clone_fixture "tag-feature-branch")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TAG" "1.0.1-PRERELEASE"
}

@test "uses numeric DOCKER_TAG on release branch" {
  TEST_REPO=$(clone_fixture "tag-semver3")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TAG" "1.0.1"
}

@test "outputs PROJECT_NAME from repo directory" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_output_contains "PROJECT_NAME="
}

@test "respects PATCH_BRANCHES configuration" {
  TEST_REPO=$(clone_fixture "tag-feature-branch")
  cd "$TEST_REPO"
  export PATCH_BRANCHES="feature-*"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "true"
}

# Complex scenarios from Tag.md

@test "finds highest tag in series across isolated branches" {
  TEST_REPO=$(clone_fixture "tag-higher-on-other-branch")
  cd "$TEST_REPO"

  # main has 2.0, but isolated branch has 2.30-2.32
  # Should get 2.33, not 2.1
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "2.33"
  assert_var_equals "VERSION_2_PART" "2.33"
  assert_var_equals "VERSION_3_PART" "2.33.0"
}

@test "increments 4-part patch version correctly" {
  TEST_REPO=$(clone_fixture "tag-patch-branch")
  cd "$TEST_REPO"
  export PATCH_BRANCHES="main-*"
  export MAX_VERSION_PARTS=4

  # Branch has 1.2.4.0-1.2.4.3, should get 1.2.4.4
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4.4"
}

@test "patch branch ignores main's newer tags" {
  TEST_REPO=$(clone_fixture "tag-patch-ignores-main")
  cd "$TEST_REPO"
  export PATCH_BRANCHES="main-*"
  export MAX_VERSION_PARTS=4

  # main has 1.3.0, but patch branch is in 1.2.4.X series
  # Should get 1.2.4.1, not be affected by 1.3.0
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4.1"
}

@test "handles double-digit versions correctly" {
  TEST_REPO=$(clone_fixture "tag-double-digits")
  cd "$TEST_REPO"

  # Has 1.4, 1.5, 1.40, 1.41 - should get 1.42 not 1.6
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.42"
}

@test "ignores non-numeric version tags" {
  TEST_REPO=$(clone_fixture "tag-with-suffixes")
  cd "$TEST_REPO"

  # Has 1.2.3, 1.2.4-rc1, 1.2.4-beta - should get 1.2.4 (ignoring suffixed tags)
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4"
}

@test "fails when version exceeds MAX_VERSION_PARTS" {
  TEST_REPO=$(clone_fixture "tag-semver4")
  cd "$TEST_REPO"
  export MAX_VERSION_PARTS=3

  # Has 1.2.3.4, would generate 1.2.3.5 which is 4 parts > max 3
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 1 ]
  assert_output_contains "exceeds MAX_VERSION_PARTS"
}

# Tag date ordering tests

@test "picks newer tag by date when multiple tags on same commit" {
  TEST_REPO=$(clone_fixture "tag-same-commit-multiple")
  cd "$TEST_REPO"

  # Same commit has 2.3.4 (older) and 1.2.3 (newer)
  # Should pick 1.2.3 because it's newer by tag creation date
  # Then generate 1.2.4
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4"
}

@test "picks newer tag by date at same distance after merge" {
  TEST_REPO=$(clone_fixture "tag-merge-same-distance")
  cd "$TEST_REPO"

  # After merge, both 2.3.4 (older) and 1.2.3 (newer) are same distance from HEAD
  # 1.2.3 is newer by tag creation date, should be picked
  # Would generate 1.2.4
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4"
}

@test "uses closer tag even if older commit was tagged later" {
  TEST_REPO=$(clone_fixture "tag-backfill-order")
  cd "$TEST_REPO"

  # Linear: A (tag 2.0.0, created 2nd) → B (tag 1.0.0, created 1st) → C (HEAD)
  # 1.0.0 is distance 1, 2.0.0 is distance 2
  # Should pick 1.0.0 (closer) despite 2.0.0 having newer creation date
  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.1"
}

@test "generates docker image name from repo prefix" {
  TEST_REPO=$(clone_fixture "tag-none")
  # Rename to match group-project-specialisation pattern
  local parent_dir=$(dirname "$TEST_REPO")
  local new_name="$parent_dir/group-project-specialisation"
  mv "$TEST_REPO" "$new_name"
  TEST_REPO="$new_name"
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/generate-release-tag"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_IMAGE_NAME" "group/group-project-specialisation"
}
