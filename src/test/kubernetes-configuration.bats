#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-configuration.bash library

load helpers

setup() {
  source "$LIB_DIR/kubernetes-configuration.bash"
}

# =============================================================================
# build_configuration_source_path
# =============================================================================

@test "build_configuration_source_path: base path only, no suffix, no static suffix" {
  result=$(build_configuration_source_path "src/configmap" "" "")
  [ "$result" = "src/configmap" ]
}

@test "build_configuration_source_path: base path with suffix, no static suffix" {
  result=$(build_configuration_source_path "src/configmap" "nginx" "")
  [ "$result" = "src/configmap-nginx" ]
}

@test "build_configuration_source_path: base path only, no suffix, with static suffix" {
  result=$(build_configuration_source_path "src/secret" "" ".template")
  [ "$result" = "src/secret.template" ]
}

@test "build_configuration_source_path: base path with suffix and static suffix" {
  result=$(build_configuration_source_path "src/secret" "db" ".template")
  [ "$result" = "src/secret-db.template" ]
}

@test "build_configuration_source_path: base path already has static suffix, no name suffix" {
  result=$(build_configuration_source_path "src/secret.template" "" ".template")
  [ "$result" = "src/secret.template" ]
}

@test "build_configuration_source_path: base path already has static suffix, with name suffix" {
  result=$(build_configuration_source_path "src/secret.template" "db" ".template")
  [ "$result" = "src/secret-db.template" ]
}

@test "build_configuration_source_path: custom path with suffix" {
  result=$(build_configuration_source_path "custom/path" "nginx" "")
  [ "$result" = "custom/path-nginx" ]
}

@test "build_configuration_source_path: custom path with suffix and static suffix" {
  result=$(build_configuration_source_path "custom/path" "db" ".template")
  [ "$result" = "custom/path-db.template" ]
}

@test "build_configuration_source_path: custom path already has static suffix" {
  result=$(build_configuration_source_path "custom/path.template" "db" ".template")
  [ "$result" = "custom/path-db.template" ]
}

@test "build_configuration_source_path: deployment-env default with suffix" {
  result=$(build_configuration_source_path "src/deployment-env" "worker" "-env")
  [ "$result" = "src/deployment-worker-env" ]
}

@test "build_configuration_source_path: deployment-env default without suffix" {
  result=$(build_configuration_source_path "src/deployment-env" "" "-env")
  [ "$result" = "src/deployment-env" ]
}

@test "build_configuration_source_path: deployment path without -env gets it added" {
  result=$(build_configuration_source_path "src/deployment" "worker" "-env")
  [ "$result" = "src/deployment-worker-env" ]
}

@test "build_configuration_source_path: handles paths with multiple segments" {
  result=$(build_configuration_source_path "some/deep/nested/path" "suffix" ".ext")
  [ "$result" = "some/deep/nested/path-suffix.ext" ]
}

@test "build_configuration_source_path: empty base path with suffix" {
  result=$(build_configuration_source_path "" "suffix" "")
  [ "$result" = "-suffix" ]
}
