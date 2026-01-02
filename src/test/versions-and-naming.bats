#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

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

  run "$SCRIPTS_DIR/versions-and-naming"
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

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.1"
}

@test "increments single-part version 7 to 8" {
  TEST_REPO=$(clone_fixture "tag-semver1")
  cd "$TEST_REPO"
  export MAX_VERSION_PARTS=1

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "8"
}

@test "increments two-digit single-part version 41 to 42" {
  TEST_REPO=$(clone_fixture "tag-semver1-twodigit")
  cd "$TEST_REPO"
  export MAX_VERSION_PARTS=1

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "42"
}

@test "increments ten-digit single-part version 1234567890 to 1234567891" {
  TEST_REPO=$(clone_fixture "tag-semver1-tendigit")
  cd "$TEST_REPO"
  export MAX_VERSION_PARTS=1

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1234567891"
}

@test "increments minor version for two-part tags" {
  TEST_REPO=$(clone_fixture "tag-semver2")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.3"
  assert_var_equals "VERSION_2_PART" "1.3"
  assert_var_equals "VERSION_3_PART" "1.3.0"
}

@test "increments last component for four-part versions" {
  TEST_REPO=$(clone_fixture "tag-semver4")
  cd "$TEST_REPO"
  export MAX_VERSION_PARTS=4

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.3.5"
  assert_var_equals "VERSION_3_PART" "1.2.3"
  assert_var_equals "VERSION_4_PART" "1.2.3.5"
}

@test "increments ten-part version 1.2.3.4.5.6.7.8.9.0 to 1.2.3.4.5.6.7.8.9.1" {
  TEST_REPO=$(clone_fixture "tag-semver10")
  cd "$TEST_REPO"
  export MAX_VERSION_PARTS=10

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.3.4.5.6.7.8.9.1"
}

@test "ignores v-prefixed tags" {
  TEST_REPO=$(clone_fixture "tag-vprefixed")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  # v1.0.0 exists but should be ignored, so starts fresh at 1.0.0
  assert_var_equals "VERSION" "1.0.0"
}

@test "finds highest tag across multiple" {
  TEST_REPO=$(clone_fixture "tag-multiple")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.3"
}

@test "sets IS_RELEASE=true on default branch" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "true"
}

@test "sets IS_RELEASE=false on feature branch" {
  TEST_REPO=$(clone_fixture "tag-feature-branch")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "false"
}

@test "adds PRERELEASE suffix on non-release branch" {
  TEST_REPO=$(clone_fixture "tag-feature-branch")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TAG" "1.0.1-PRERELEASE"
}

@test "uses numeric DOCKER_TAG on release branch" {
  TEST_REPO=$(clone_fixture "tag-semver3")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_TAG" "1.0.1"
}

@test "outputs PROJECT_NAME from repo directory" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_output_contains "PROJECT_NAME="
}

@test "respects ADDITIONAL_RELEASE_BRANCHES configuration" {
  TEST_REPO=$(clone_fixture "tag-feature-branch")
  cd "$TEST_REPO"
  export ADDITIONAL_RELEASE_BRANCHES="feature-test"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "true"
}

# Complex scenarios from Tag.md

@test "finds highest tag in series across isolated branches" {
  TEST_REPO=$(clone_fixture "tag-higher-on-other-branch")
  cd "$TEST_REPO"

  # main has 2.0, but isolated branch has 2.30-2.32
  # Should get 2.33, not 2.1
  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "2.33"
  assert_var_equals "VERSION_2_PART" "2.33"
  assert_var_equals "VERSION_3_PART" "2.33.0"
}

@test "increments 4-part patch version correctly" {
  TEST_REPO=$(clone_fixture "tag-patch-branch")
  cd "$TEST_REPO"
  export ADDITIONAL_RELEASE_BRANCHES="main-*"
  export MAX_VERSION_PARTS=4

  # Branch has 1.2.4.0-1.2.4.3, should get 1.2.4.4
  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4.4"
}

@test "patch branch ignores main's newer tags" {
  TEST_REPO=$(clone_fixture "tag-patch-ignores-main")
  cd "$TEST_REPO"
  export ADDITIONAL_RELEASE_BRANCHES="main-*"
  export MAX_VERSION_PARTS=4

  # main has 1.3.0, but patch branch is in 1.2.4.X series
  # Should get 1.2.4.1, not be affected by 1.3.0
  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4.1"
}

@test "handles double-digit versions correctly" {
  TEST_REPO=$(clone_fixture "tag-double-digits")
  cd "$TEST_REPO"

  # Has 1.4, 1.5, 1.40, 1.41 - should get 1.42 not 1.6
  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.42"
}

@test "ignores non-numeric version tags" {
  TEST_REPO=$(clone_fixture "tag-with-suffixes")
  cd "$TEST_REPO"

  # Has 1.2.3, 1.2.4-rc1, 1.2.4-beta - should get 1.2.4 (ignoring suffixed tags)
  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4"
}

@test "fails when version exceeds MAX_VERSION_PARTS" {
  TEST_REPO=$(clone_fixture "tag-semver4")
  cd "$TEST_REPO"
  export MAX_VERSION_PARTS=3

  # Has 1.2.3.4, would generate 1.2.3.5 which is 4 parts > max 3
  run "$SCRIPTS_DIR/versions-and-naming"
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
  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4"
}

@test "picks newer tag by date at same distance after merge" {
  TEST_REPO=$(clone_fixture "tag-merge-same-distance")
  cd "$TEST_REPO"

  # After merge, both 2.3.4 (older) and 1.2.3 (newer) are same distance from HEAD
  # 1.2.3 is newer by tag creation date, should be picked
  # Would generate 1.2.4
  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.2.4"
}

@test "uses closer tag even if older commit was tagged later" {
  TEST_REPO=$(clone_fixture "tag-backfill-order")
  cd "$TEST_REPO"

  # Linear: A (tag 2.0.0, created 2nd) → B (tag 1.0.0, created 1st) → C (HEAD)
  # 1.0.0 is distance 1, 2.0.0 is distance 2
  # Should pick 1.0.0 (closer) despite 2.0.0 having newer creation date
  run "$SCRIPTS_DIR/versions-and-naming"
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

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "DOCKER_IMAGE_NAME" "group/group-project-specialisation"
}

# file-pattern-match strategy tests

@test "file-pattern-match dockerfile-env-kubectl extracts version from ENV and starts at x.y.1" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.0' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.28.1"
}

@test "file-pattern-match dockerfile-env-kubectl increments patch from existing tags" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.0' > src/docker/Dockerfile
  git tag -m "test" 1.28.0
  git tag -m "test" 1.28.1
  git tag -m "test" 1.28.2

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.28.3"
}

@test "file-pattern-match uses custom pattern for different ENV variable" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV HELM_VERSION=3.14.0' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/docker
  export TAG_VERSION_SOURCE_FILE_NAME=Dockerfile
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^ENV HELM_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "3.14.1"
}

@test "file-pattern-match dockerfile-env-kubectl uses custom source path" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p custom/path
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.29.0' > custom/path/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_SOURCE_SUB_PATH=custom/path

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.29.1"
}

@test "file-pattern-match fails if source file not found" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  # No Dockerfile created

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "Source file not found"
}

@test "file-pattern-match fails if pattern not matched" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "Could not find version matching pattern"
}

@test "file-pattern-match ignores tags from different series" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.29.0' > src/docker/Dockerfile
  # Tags from different series should be ignored
  git tag -m "test" 1.28.0
  git tag -m "test" 1.28.5
  git tag -m "test" 1.30.0

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.29.1"
}

@test "file-pattern-match retag-workflow-source-tag extracts from workflow file" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p .github/workflows
  echo 'name: Build
on: push
jobs:
  build:
    uses: example/workflow@v1
    with:
      docker-source-tag: 3.10.1' > .github/workflows/build.yaml

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=retag-workflow-source-tag

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "3.10.1"
}

@test "file-pattern-match retag-workflow-source-tag handles quoted values" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p .github/workflows
  echo "name: Build
on: push
jobs:
  build:
    uses: example/workflow@v1
    with:
      docker-source-tag: '2.5.0'" > .github/workflows/build.yaml

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=retag-workflow-source-tag

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "2.5.1"
}

@test "file-pattern-match custom type requires all inputs" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  # Missing required inputs

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "required for custom pattern type"
}

@test "file-pattern-match fails for unknown pattern type" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=unknown-type

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "Unknown TAG_VERSION_PATTERN_TYPE"
}

@test "file-pattern-match fails when custom pattern captures non-version" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'APP_NAME=my-cool-app' > src/config/settings.txt

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=settings.txt
  # This pattern captures "my-cool-app" which is not a version
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^APP_NAME=(.+)$'

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "not a valid version format"
}

@test "file-pattern-match TAG_VERSION_PREFIX_PARTS=2 uses two-part prefix (default behavior)" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.5' > src/docker/Dockerfile
  # Tags in 1.28.X series
  git tag -m "test" 1.28.1
  git tag -m "test" 1.28.2

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_PREFIX_PARTS=2
  export MAX_VERSION_PARTS=3

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  # prefix=1.28, highest in series=1.28.2, next=1.28.3
  assert_var_equals "VERSION" "1.28.3"
}

@test "file-pattern-match TAG_VERSION_PREFIX_PARTS=1 uses single-part prefix" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.5' > src/docker/Dockerfile
  # Tags in 1.X series
  git tag -m "test" 1.3
  git tag -m "test" 1.10

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_PREFIX_PARTS=1
  export MAX_VERSION_PARTS=2

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  # prefix=1, highest in series=1.10, next=1.11
  assert_var_equals "VERSION" "1.11"
}

@test "file-pattern-match TAG_VERSION_PREFIX_PARTS=3 uses full source version as prefix" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.5' > src/docker/Dockerfile
  # Tags in 1.28.5.X series
  git tag -m "test" 1.28.5.1
  git tag -m "test" 1.28.5.2

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_PREFIX_PARTS=3
  export MAX_VERSION_PARTS=4

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  # prefix=1.28.5, highest in series=1.28.5.2, next=1.28.5.3
  assert_var_equals "VERSION" "1.28.5.3"
}

@test "file-pattern-match TAG_VERSION_PREFIX_PARTS=3 starts at prefix.1 when no tags exist" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.5' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_PREFIX_PARTS=3
  export MAX_VERSION_PARTS=4

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  # prefix=1.28.5, no existing tags, start at 1.28.5.1
  assert_var_equals "VERSION" "1.28.5.1"
}

@test "file-pattern-match fails when PREFIX_PARTS + 1 exceeds MAX_VERSION_PARTS" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.5' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_PREFIX_PARTS=3
  export MAX_VERSION_PARTS=3  # Output would be 4 parts, exceeds limit

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  # PREFIX_PARTS=3 means output has 4 parts, but MAX_VERSION_PARTS=3
  assert_output_contains "TAG_VERSION_PREFIX_PARTS (3) + 1 exceeds MAX_VERSION_PARTS (3)"
}

@test "file-pattern-match fails when PREFIX_PARTS=2 but source has 1 part" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'VERSION=7' > src/config/version.txt

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^VERSION=([0-9]+)$'
  export TAG_VERSION_PREFIX_PARTS=2  # Source only has 1 part
  export MAX_VERSION_PARTS=3

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  # PREFIX_PARTS=2 but source "7" only has 1 part
  assert_output_contains "TAG_VERSION_PREFIX_PARTS (2) exceeds source version parts (1 in '7')"
}

@test "file-pattern-match fails when PREFIX_PARTS=3 but source has 2 parts" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'VERSION=1.28' > src/config/version.txt

  export TAG_VERSION_CALCULATION_STRATEGY=file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^VERSION=([0-9]+\.[0-9]+)$'
  export TAG_VERSION_PREFIX_PARTS=3  # Source only has 2 parts
  export MAX_VERSION_PARTS=4

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  # PREFIX_PARTS=3 but source "1.28" only has 2 parts
  assert_output_contains "TAG_VERSION_PREFIX_PARTS (3) exceeds source version parts (2 in '1.28')"
}

# BUILD_LOCATION tests

@test "fails when BUILD_LOCATION is not set" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  unset BUILD_LOCATION

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "BUILD_LOCATION is required"
}

@test "fails when BUILD_LOCATION has invalid value" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  export BUILD_LOCATION="invalid_value"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "Invalid BUILD_LOCATION"
}

@test "BUILD_LOCATION=local forces IS_RELEASE=false on default branch" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  export BUILD_LOCATION="local"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "false"
  assert_var_equals "DOCKER_TAG" "1.0.0-PRERELEASE"
}

@test "BUILD_LOCATION=local forces IS_RELEASE=false on additional release branch" {
  TEST_REPO=$(clone_fixture "tag-feature-branch")
  cd "$TEST_REPO"
  export BUILD_LOCATION="local"
  export ADDITIONAL_RELEASE_BRANCHES="feature-test"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "false"
  assert_var_equals "DOCKER_TAG" "1.0.1-PRERELEASE"
}

@test "BUILD_LOCATION=build_server allows IS_RELEASE=true on default branch" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  export BUILD_LOCATION="build_server"

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "IS_RELEASE" "true"
  assert_var_equals "DOCKER_TAG" "1.0.0"
}
