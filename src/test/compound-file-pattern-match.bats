#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  export DEFAULT_BRANCH=main
  export CURRENT_BRANCH=main
  export REPOSITORY_NAME=test-repo
  setup_mock_git
}

teardown() {
  cleanup_test_repo "$TEST_REPO"
  cleanup_mock_git
}

# compound-file-pattern-match strategy tests

@test "compound-file-pattern-match combines two sources and starts at ONE.TWO.1" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'DEPLOY_VERSION=1.0.0' > src/config/version.txt
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.32.4' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^DEPLOY_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/docker
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=Dockerfile
  export TAG_VERSION_SOURCE_TWO_PATTERN='^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=2
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.0.1.32.1"
}

@test "compound-file-pattern-match increments PATCH from existing tags" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'DEPLOY_VERSION=1.0.0' > src/config/version.txt
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.32.4' > src/docker/Dockerfile
  git tag -m "test" 1.0.0.1.32.1
  git tag -m "test" 1.0.0.1.32.2

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^DEPLOY_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/docker
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=Dockerfile
  export TAG_VERSION_SOURCE_TWO_PATTERN='^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=2
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.0.0.1.32.3"
}

@test "compound-file-pattern-match ignores tags from different series" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'DEPLOY_VERSION=1.0.0' > src/config/version.txt
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.33.4' > src/docker/Dockerfile
  git tag -m "test" 1.0.0.1.32.1
  git tag -m "test" 1.0.0.1.32.5

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^DEPLOY_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/docker
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=Dockerfile
  export TAG_VERSION_SOURCE_TWO_PATTERN='^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=2
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  # 1.33 series, not 1.32 - existing 1.0.0.1.32.x tags are ignored
  assert_var_equals "VERSION" "1.0.0.1.33.1"
}

@test "compound-file-pattern-match uses dockerfile-env-kubectl for source ONE" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.35.4' > src/docker/Dockerfile
  mkdir -p src/config
  echo 'SCRIPTS_VERSION=2.1.0' > src/config/version.txt

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_PREFIX_PARTS=2
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_TWO_PATTERN='^SCRIPTS_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=3
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.35.2.1.0.1"
}

@test "compound-file-pattern-match dockerfile-env-kubectl allows custom pattern override" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  # No ENV KUBECTL_VERSION - use custom FROM pattern instead
  echo 'FROM ghcr.io/example/deploy-scripts:1.0.1 AS SCRIPTS
FROM ghcr.io/example/base-image:1.32.4' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  # Override the default KUBECTL pattern with a FROM pattern (must match whole line with .*)
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^FROM .*deploy-scripts:([0-9]+\.[0-9]+\.[0-9]+).*'
  export TAG_VERSION_PREFIX_PARTS=3
  export TAG_VERSION_SOURCE_TWO_PATTERN='^FROM .*base-image:([0-9]+\.[0-9]+\.[0-9]+).*'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=2
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  # ONE=1.0.1 (3 parts), TWO=1.32 (2 parts from 1.32.4)
  assert_var_equals "VERSION" "1.0.1.1.32.1"
}

@test "compound-file-pattern-match TAG_VERSION_PREFIX_PARTS trims source ONE" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'DEPLOY_VERSION=1.0.0' > src/config/version.txt
  mkdir -p src/other
  echo 'OTHER_VERSION=5.6.7' > src/other/version.txt

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^DEPLOY_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_PREFIX_PARTS=2
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/other
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_TWO_PATTERN='^OTHER_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=2
  export TAG_VERSION_MAX_PARTS=6

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  # ONE trimmed to 1.0, TWO trimmed to 5.6
  assert_var_equals "VERSION" "1.0.5.6.1"
}

@test "compound-file-pattern-match fails when source TWO file missing" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'DEPLOY_VERSION=1.0.0' > src/config/version.txt

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^DEPLOY_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/docker
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=Dockerfile
  export TAG_VERSION_SOURCE_TWO_PATTERN='^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "Source file not found"
}

@test "compound-file-pattern-match fails when source TWO pattern not matched" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'DEPLOY_VERSION=1.0.0' > src/config/version.txt
  mkdir -p src/docker
  echo 'FROM alpine:3.19' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^DEPLOY_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/docker
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=Dockerfile
  export TAG_VERSION_SOURCE_TWO_PATTERN='^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "Could not find version matching pattern"
}

@test "compound-file-pattern-match defaults TWO path and file from ONE with different file" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.32.4' > src/docker/Dockerfile
  mkdir -p src/docker
  echo 'SCRIPTS_VERSION=2.0.0' > src/docker/versions.txt

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_PREFIX_PARTS=2
  # TWO uses same dir as ONE (src/docker) but different file
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=versions.txt
  export TAG_VERSION_SOURCE_TWO_PATTERN='^SCRIPTS_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=2
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.32.2.0.1"
}

@test "compound-file-pattern-match defaults TWO pattern from ONE when different file" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.32.4' > src/docker/Dockerfile
  mkdir -p other
  echo 'FROM ubuntu:24.04
ENV KUBECTL_VERSION=1.33.2' > other/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  export TAG_VERSION_PREFIX_PARTS=2
  # TWO points to a different directory, same file name, same pattern (inherited)
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=other
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=2
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 0 ]
  assert_var_equals "VERSION" "1.32.1.33.1"
}

@test "compound-file-pattern-match fails when same file and TWO pattern missing" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.32.4' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  # No TWO overrides: same file as ONE, so TWO pattern is required
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "TAG_VERSION_SOURCE_TWO_PATTERN is required when source TWO uses the same file as source ONE"
}

@test "compound-file-pattern-match fails when same file and TWO pattern same as ONE" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.32.4' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=dockerfile-env-kubectl
  # Same file, TWO pattern explicitly set but identical to ONE's pattern
  export TAG_VERSION_SOURCE_TWO_PATTERN='^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_MAX_PARTS=7

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "TAG_VERSION_SOURCE_TWO_PATTERN must differ from source ONE pattern when using the same file"
}

@test "compound-file-pattern-match fails when result exceeds TAG_VERSION_MAX_PARTS" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'DEPLOY_VERSION=1.0.0' > src/config/version.txt
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.32.4' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^DEPLOY_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/docker
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=Dockerfile
  export TAG_VERSION_SOURCE_TWO_PATTERN='^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=2
  export TAG_VERSION_MAX_PARTS=5

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  # 1.0.0.1.32.1 = 6 parts, exceeds max of 5
  assert_output_contains "exceeds TAG_VERSION_MAX_PARTS"
}

@test "compound-file-pattern-match fails when TWO_PREFIX_PARTS exceeds source TWO parts" {
  TEST_REPO=$(clone_fixture "tag-none")
  cd "$TEST_REPO"
  mkdir -p src/config
  echo 'DEPLOY_VERSION=1.0.0' > src/config/version.txt
  mkdir -p src/docker
  echo 'FROM alpine:3.19
ENV KUBECTL_VERSION=1.32.4' > src/docker/Dockerfile

  export TAG_VERSION_CALCULATION_STRATEGY=compound-file-pattern-match
  export TAG_VERSION_PATTERN_TYPE=custom
  export TAG_VERSION_SOURCE_SUB_PATH=src/config
  export TAG_VERSION_SOURCE_FILE_NAME=version.txt
  export TAG_VERSION_SOURCE_CUSTOM_PATTERN='^DEPLOY_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_SUB_PATH=src/docker
  export TAG_VERSION_SOURCE_TWO_FILE_NAME=Dockerfile
  export TAG_VERSION_SOURCE_TWO_PATTERN='^ENV KUBECTL_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$'
  export TAG_VERSION_SOURCE_TWO_PREFIX_PARTS=5
  export TAG_VERSION_MAX_PARTS=10

  run "$SCRIPTS_DIR/versions-and-naming"
  [ "$status" -eq 1 ]
  assert_output_contains "TAG_VERSION_SOURCE_TWO_PREFIX_PARTS (5) exceeds source TWO version parts"
}
