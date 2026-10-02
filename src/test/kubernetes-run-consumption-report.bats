#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-run-consumption-report.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-run-consumption-report"

setup() {
  TEST_DIR=$(create_test_dir "kubernetes-run-consumption-report")
  mkdir -p "${TEST_DIR}/tree/run-foo"
  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"
  export BUILD_PLATFORM="local"
  export PROJECT_NAME="run-foo"
  export BUILD_KIND="kubernetes-run-environment"
  export VERSION="1.0.0"
  export OUTPUT_SUB_PATH="kaptain-out"
  export ENVIRONMENT_WORKLOAD_CONTENTS_SUB_PATH="tree"
  cd "${TEST_DIR}"
}

teardown() {
  dump_bats_result
}

@test "kind: an environment's report carries the short run kind" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.kind' kaptain-out/run-consumption-report/run-foo-1.0.0-consumption-report.yaml)" = "environment" ]
}

@test "kind: a run-platform's report carries the short run kind" {
  export PROJECT_NAME="run-platform-foo"
  export BUILD_KIND="kubernetes-run-platform-meta-environment"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.kind' kaptain-out/run-consumption-report/run-platform-foo-1.0.0-consumption-report.yaml)" = "run-platform" ]
}

REPORT="kaptain-out/run-consumption-report/run-foo-1.0.0-consumption-report.yaml"

@test "secret tokens: every secret-template token is listed" {
  printf 'stringData:\n  password: ${DbPassword}\n  user: ${DbUser}\n' > tree/run-foo/db.template.yaml
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.deployTimeSecretTokenCount' "${REPORT}")" = "2" ]
  [ "$(yq '.deployTimeSecretTokens | join(",")' "${REPORT}")" = "DbPassword,DbUser" ]
}

@test "secret tokens: tokens an IgnoreUnresolved marker covers are not listed" {
  printf 'stringData:\n  script: echo ${HOME} # IgnoreUnresolved\n  password: ${DbPassword}\n' > tree/run-foo/db.template.yaml
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.deployTimeSecretTokenCount' "${REPORT}")" = "1" ]
  [ "$(yq '.deployTimeSecretTokens | join(",")' "${REPORT}")" = "DbPassword" ]
}

@test "secret tokens: tokens across several templates are combined and de-duplicated" {
  printf 'stringData:\n  a: ${Shared}\n' > tree/run-foo/a.template.yaml
  printf 'stringData:\n  b: ${Shared}\n  c: ${Other}\n' > tree/run-foo/b.template.yaml
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.deployTimeSecretTokens | join(",")' "${REPORT}")" = "Other,Shared" ]
}

@test "secret tokens: none when there are no secret templates" {
  printf 'kind: ConfigMap\n' > tree/run-foo/cm.yaml
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.deployTimeSecretTokenCount' "${REPORT}")" = "0" ]
}
