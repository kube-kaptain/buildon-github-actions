#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-workload-detection.bash library

load helpers

setup() {
  source "$LIB_DIR/kubernetes-workload-detection.bash"
  TEST_DIR=$(create_test_dir "workload-detect")
  OUTPUT_SUB_PATH="$TEST_DIR/target"
  MANIFESTS_SUB_PATH="$TEST_DIR/src/kubernetes"
  mkdir -p "$OUTPUT_SUB_PATH/manifests/combined"
  mkdir -p "$MANIFESTS_SUB_PATH"
}

teardown() {
  :
}

# =============================================================================
# build_detection_paths
# =============================================================================

@test "build_detection_paths: sets combined and source check dirs" {
  COMBINED_SUB_PATH=""
  build_detection_paths
  [ "$combined_check_dir" = "$OUTPUT_SUB_PATH/manifests/combined" ]
  [ "$source_check_dir" = "$MANIFESTS_SUB_PATH" ]
}

@test "build_detection_paths: appends combined sub-path when set" {
  COMBINED_SUB_PATH="api"
  build_detection_paths
  [ "$combined_check_dir" = "$OUTPUT_SUB_PATH/manifests/combined/api" ]
  [ "$source_check_dir" = "$MANIFESTS_SUB_PATH/api" ]
}

@test "build_detection_paths: handles nested combined sub-path" {
  COMBINED_SUB_PATH="services/api"
  build_detection_paths
  [ "$combined_check_dir" = "$OUTPUT_SUB_PATH/manifests/combined/services/api" ]
  [ "$source_check_dir" = "$MANIFESTS_SUB_PATH/services/api" ]
}

# =============================================================================
# build_suffix_fragment
# =============================================================================

@test "build_suffix_fragment: empty when no suffix" {
  NAME_SUFFIX=""
  build_suffix_fragment
  [ "$suffix_fragment" = "" ]
}

@test "build_suffix_fragment: prefixed with hyphen when set" {
  NAME_SUFFIX="worker"
  build_suffix_fragment
  [ "$suffix_fragment" = "-worker" ]
}

# =============================================================================
# detect_serviceaccount
# =============================================================================

@test "detect_serviceaccount: not found when no file exists" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  build_detection_paths
  build_suffix_fragment
  detect_serviceaccount
  [ "$has_serviceaccount" = "false" ]
  [ "$serviceaccount_source" = "" ]
}

@test "detect_serviceaccount: found in combined dir" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  build_detection_paths
  build_suffix_fragment
  touch "$combined_check_dir/serviceaccount.yaml"
  detect_serviceaccount
  [ "$has_serviceaccount" = "true" ]
  [ "$serviceaccount_source" = "$combined_check_dir/serviceaccount.yaml" ]
}

@test "detect_serviceaccount: found in source dir" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  build_detection_paths
  build_suffix_fragment
  touch "$source_check_dir/serviceaccount.yaml"
  detect_serviceaccount
  [ "$has_serviceaccount" = "true" ]
  [ "$serviceaccount_source" = "$source_check_dir/serviceaccount.yaml" ]
}

@test "detect_serviceaccount: combined dir takes precedence over source" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  build_detection_paths
  build_suffix_fragment
  touch "$combined_check_dir/serviceaccount.yaml"
  touch "$source_check_dir/serviceaccount.yaml"
  detect_serviceaccount
  [ "$has_serviceaccount" = "true" ]
  [ "$serviceaccount_source" = "$combined_check_dir/serviceaccount.yaml" ]
}

@test "detect_serviceaccount: respects suffix in filename" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX="worker"
  build_detection_paths
  build_suffix_fragment
  touch "$combined_check_dir/serviceaccount-worker.yaml"
  detect_serviceaccount
  [ "$has_serviceaccount" = "true" ]
  [ "$serviceaccount_source" = "$combined_check_dir/serviceaccount-worker.yaml" ]
}

@test "detect_serviceaccount: does not find unsuffixed when suffix expected" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX="worker"
  build_detection_paths
  build_suffix_fragment
  touch "$combined_check_dir/serviceaccount.yaml"
  detect_serviceaccount
  [ "$has_serviceaccount" = "false" ]
}

# =============================================================================
# detect_configmap
# =============================================================================

@test "detect_configmap: not found when no file exists" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  build_detection_paths
  build_suffix_fragment
  detect_configmap
  [ "$has_configmap" = "false" ]
  [ "$configmap_source" = "" ]
}

@test "detect_configmap: found in combined dir" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  build_detection_paths
  build_suffix_fragment
  touch "$combined_check_dir/configmap.yaml"
  detect_configmap
  [ "$has_configmap" = "true" ]
  [ "$configmap_source" = "$combined_check_dir/configmap.yaml" ]
}

@test "detect_configmap: respects suffix in filename" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX="api"
  build_detection_paths
  build_suffix_fragment
  touch "$source_check_dir/configmap-api.yaml"
  detect_configmap
  [ "$has_configmap" = "true" ]
  [ "$configmap_source" = "$source_check_dir/configmap-api.yaml" ]
}

# =============================================================================
# detect_secret
# =============================================================================

@test "detect_secret: not found when no file exists" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  build_detection_paths
  build_suffix_fragment
  detect_secret
  [ "$has_secret" = "false" ]
  [ "$secret_source" = "" ]
}

@test "detect_secret: found in combined dir" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  build_detection_paths
  build_suffix_fragment
  touch "$combined_check_dir/secret.template.yaml"
  detect_secret
  [ "$has_secret" = "true" ]
  [ "$secret_source" = "$combined_check_dir/secret.template.yaml" ]
}

@test "detect_secret: respects suffix in filename" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX="db"
  build_detection_paths
  build_suffix_fragment
  touch "$source_check_dir/secret.template-db.yaml"
  detect_secret
  [ "$has_secret" = "true" ]
  [ "$secret_source" = "$source_check_dir/secret.template-db.yaml" ]
}

# =============================================================================
# detect_env_vars
# =============================================================================

@test "detect_env_vars: not found when directory does not exist" {
  ENV_SUB_PATH="$TEST_DIR/nonexistent"
  detect_env_vars
  [ "$has_env_vars" = "false" ]
  [ "$env_file_count" = "0" ]
}

@test "detect_env_vars: not found when directory is empty" {
  ENV_SUB_PATH="$TEST_DIR/env"
  mkdir -p "$ENV_SUB_PATH"
  detect_env_vars
  [ "$has_env_vars" = "false" ]
  [ "$env_file_count" = "0" ]
}

@test "detect_env_vars: found with single file" {
  ENV_SUB_PATH="$TEST_DIR/env"
  mkdir -p "$ENV_SUB_PATH"
  echo "value1" > "$ENV_SUB_PATH/VAR1"
  detect_env_vars
  [ "$has_env_vars" = "true" ]
  [ "$env_file_count" = "1" ]
}

@test "detect_env_vars: counts multiple files" {
  ENV_SUB_PATH="$TEST_DIR/env"
  mkdir -p "$ENV_SUB_PATH"
  echo "value1" > "$ENV_SUB_PATH/VAR1"
  echo "value2" > "$ENV_SUB_PATH/VAR2"
  echo "value3" > "$ENV_SUB_PATH/VAR3"
  detect_env_vars
  [ "$has_env_vars" = "true" ]
  [ "$env_file_count" = "3" ]
}

@test "detect_env_vars: ignores dotfiles" {
  ENV_SUB_PATH="$TEST_DIR/env"
  mkdir -p "$ENV_SUB_PATH"
  echo "value1" > "$ENV_SUB_PATH/VAR1"
  echo "hidden" > "$ENV_SUB_PATH/.hidden"
  detect_env_vars
  [ "$has_env_vars" = "true" ]
  [ "$env_file_count" = "1" ]
}

# =============================================================================
# detect_all_resources
# =============================================================================

@test "detect_all_resources: sets all globals" {
  COMBINED_SUB_PATH=""
  NAME_SUFFIX=""
  ENV_SUB_PATH="$TEST_DIR/env"
  mkdir -p "$ENV_SUB_PATH"
  touch "$OUTPUT_SUB_PATH/manifests/combined/serviceaccount.yaml"
  touch "$MANIFESTS_SUB_PATH/configmap.yaml"
  echo "val" > "$ENV_SUB_PATH/MY_VAR"

  detect_all_resources

  [ "$has_serviceaccount" = "true" ]
  [ "$has_configmap" = "true" ]
  [ "$has_secret" = "false" ]
  [ "$has_env_vars" = "true" ]
  [ "$suffix_fragment" = "" ]
}

@test "detect_all_resources: works with combined sub-path and suffix" {
  COMBINED_SUB_PATH="api"
  NAME_SUFFIX="worker"
  ENV_SUB_PATH="$TEST_DIR/env"
  mkdir -p "$OUTPUT_SUB_PATH/manifests/combined/api"
  mkdir -p "$MANIFESTS_SUB_PATH/api"
  touch "$OUTPUT_SUB_PATH/manifests/combined/api/secret.template-worker.yaml"

  detect_all_resources

  [ "$has_serviceaccount" = "false" ]
  [ "$has_configmap" = "false" ]
  [ "$has_secret" = "true" ]
  [ "$has_env_vars" = "false" ]
  [ "$suffix_fragment" = "-worker" ]
}
