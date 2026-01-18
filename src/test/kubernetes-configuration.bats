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

# =============================================================================
# generate_configuration_entries
# =============================================================================

@test "generate_configuration_entries: single-line file uses inline format" {
  local test_dir
  test_dir="$(mktemp -d)"
  echo "simple-value" > "${test_dir}/single.txt"

  result=$(generate_configuration_entries "${test_dir}")
  rm -rf "${test_dir}"

  [[ "${result}" == *"single.txt: simple-value"* ]]
}

@test "generate_configuration_entries: multi-line file uses block scalar format" {
  local test_dir
  test_dir="$(mktemp -d)"
  printf "line1\nline2\nline3" > "${test_dir}/multi.txt"

  result=$(generate_configuration_entries "${test_dir}")
  rm -rf "${test_dir}"

  [[ "${result}" == *"multi.txt: |"* ]]
}

@test "generate_configuration_entries: file with trailing newline uses inline format" {
  local test_dir
  test_dir="$(mktemp -d)"
  printf "value\n" > "${test_dir}/trailing.txt"

  result=$(generate_configuration_entries "${test_dir}")
  rm -rf "${test_dir}"

  [[ "${result}" == *"trailing.txt: value"* ]]
}

@test "generate_configuration_entries: preserves content in multi-line files" {
  local test_dir
  test_dir="$(mktemp -d)"
  printf "first\nsecond\nthird" > "${test_dir}/content.txt"

  result=$(generate_configuration_entries "${test_dir}")
  rm -rf "${test_dir}"

  [[ "${result}" == *"first"* ]]
  [[ "${result}" == *"second"* ]]
  [[ "${result}" == *"third"* ]]
}

@test "generate_configuration_entries: multiple files sorted alphabetically" {
  local test_dir
  test_dir="$(mktemp -d)"
  echo "z-content" > "${test_dir}/zebra.txt"
  echo "a-content" > "${test_dir}/apple.txt"

  result=$(generate_configuration_entries "${test_dir}")
  rm -rf "${test_dir}"

  apple_pos=$(echo "${result}" | grep -n "apple.txt" | cut -d: -f1)
  zebra_pos=$(echo "${result}" | grep -n "zebra.txt" | cut -d: -f1)
  [[ "${apple_pos}" -lt "${zebra_pos}" ]]
}
