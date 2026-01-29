#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-workload-detection.bash - Resource detection for workload generators
#
# Detects optional Kubernetes resources (ServiceAccount, ConfigMap, Secret, env vars)
# that may be present in source or combined manifest directories.
#
# Required variables before sourcing:
#   OUTPUT_SUB_PATH - Build output directory
#   MANIFESTS_SUB_PATH - Source manifests directory
#
# Optional variables:
#   COMBINED_SUB_PATH - Sub-path within manifests (for multi-component projects)
#   NAME_SUFFIX - Suffix for resource names (e.g., "worker")
#   ENV_SUB_PATH - Directory containing environment variable files
#
# After calling detection functions, these globals are set:
#   combined_check_dir, source_check_dir - Detection search paths
#   suffix_fragment - Empty or "-${NAME_SUFFIX}"
#   has_serviceaccount, serviceaccount_source - ServiceAccount detection results
#   has_configmap, configmap_source - ConfigMap detection results
#   has_secret, secret_source - Secret detection results
#   has_env_vars, env_file_count - Environment variables detection results
#
# shellcheck disable=SC2034 # has_* and *_source variables used by caller
# shellcheck disable=SC2154 # OUTPUT_SUB_PATH, MANIFESTS_SUB_PATH set by caller

# Build detection paths with sub-path support
# Sets: combined_check_dir, source_check_dir
build_detection_paths() {
  combined_check_dir="${OUTPUT_SUB_PATH}/manifests/combined"
  source_check_dir="${MANIFESTS_SUB_PATH}"
  if [[ -n "${COMBINED_SUB_PATH:-}" ]]; then
    combined_check_dir="${combined_check_dir}/${COMBINED_SUB_PATH}"
    source_check_dir="${source_check_dir}/${COMBINED_SUB_PATH}"
  fi
}

# Build suffix fragment for filenames
# Sets: suffix_fragment
build_suffix_fragment() {
  suffix_fragment=""
  if [[ -n "${NAME_SUFFIX:-}" ]]; then
    suffix_fragment="-${NAME_SUFFIX}"
  fi
}

# Detect ServiceAccount
# Requires: combined_check_dir, source_check_dir, suffix_fragment
# Sets: has_serviceaccount, serviceaccount_source
detect_serviceaccount() {
  has_serviceaccount=false
  serviceaccount_source=""
  local sa_filename="serviceaccount${suffix_fragment}.yaml"
  if [[ -f "${combined_check_dir}/${sa_filename}" ]]; then
    has_serviceaccount=true
    serviceaccount_source="${combined_check_dir}/${sa_filename}"
  elif [[ -f "${source_check_dir}/${sa_filename}" ]]; then
    has_serviceaccount=true
    serviceaccount_source="${source_check_dir}/${sa_filename}"
  fi
}

# Detect ConfigMap
# Requires: combined_check_dir, source_check_dir, suffix_fragment
# Sets: has_configmap, configmap_source
detect_configmap() {
  has_configmap=false
  configmap_source=""
  local configmap_filename="configmap${suffix_fragment}.yaml"
  if [[ -f "${combined_check_dir}/${configmap_filename}" ]]; then
    has_configmap=true
    configmap_source="${combined_check_dir}/${configmap_filename}"
  elif [[ -f "${source_check_dir}/${configmap_filename}" ]]; then
    has_configmap=true
    configmap_source="${source_check_dir}/${configmap_filename}"
  fi
}

# Detect Secret template
# Requires: combined_check_dir, source_check_dir, suffix_fragment
# Sets: has_secret, secret_source
detect_secret() {
  has_secret=false
  secret_source=""
  local secret_filename="secret${suffix_fragment}.template.yaml"
  if [[ -f "${combined_check_dir}/${secret_filename}" ]]; then
    has_secret=true
    secret_source="${combined_check_dir}/${secret_filename}"
  elif [[ -f "${source_check_dir}/${secret_filename}" ]]; then
    has_secret=true
    secret_source="${source_check_dir}/${secret_filename}"
  fi
}

# Detect environment variables directory
# Requires: ENV_SUB_PATH
# Sets: has_env_vars, env_file_count
detect_env_vars() {
  has_env_vars=false
  env_file_count=0
  if [[ -d "${ENV_SUB_PATH:-}" ]]; then
    env_file_count=$(find "${ENV_SUB_PATH}" -type f -not -name '.*' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${env_file_count}" -gt 0 ]]; then
      has_env_vars=true
    fi
  fi
}

# Convenience function to run all detection
# Requires: OUTPUT_SUB_PATH, MANIFESTS_SUB_PATH, ENV_SUB_PATH
# Optional: COMBINED_SUB_PATH, NAME_SUFFIX
# Sets: All detection globals
detect_all_resources() {
  build_detection_paths
  build_suffix_fragment
  detect_serviceaccount
  detect_configmap
  detect_secret
  detect_env_vars
}
