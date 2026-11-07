#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-workload (router)

bats_require_minimum_version 1.5.0

load helpers

setup() {
  export OUTPUT_SUB_PATH=$(create_test_dir "gen-workload")
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"
}

teardown() {
  dump_bats_result
  :
}

# =============================================================================
# Routing behavior
# =============================================================================

@test "defaults to deployment when KUBERNETES_WORKLOAD_TYPE not set" {
  unset KUBERNETES_WORKLOAD_TYPE

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/deployment.yaml" ]
}

@test "routes to deployment when KUBERNETES_WORKLOAD_TYPE=deployment" {
  export KUBERNETES_WORKLOAD_TYPE="deployment"

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/deployment.yaml" ]
}

@test "skips generation when KUBERNETES_WORKLOAD_TYPE=none" {
  export KUBERNETES_WORKLOAD_TYPE="none"

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Workload generation disabled"* ]] || return 1
  [ ! -f "$OUTPUT_SUB_PATH/manifests/combined/deployment.yaml" ]
}

@test "fails with unknown workload type" {
  export KUBERNETES_WORKLOAD_TYPE="unknown"

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown workload type 'unknown'"* ]] || return 1
}

@test "lists available types on unknown type error" {
  export KUBERNETES_WORKLOAD_TYPE="unknown"

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Available workload types:"* ]] || return 1
  [[ "$output" == *"deployment"* ]] || return 1
}

# =============================================================================
# Environment variable passthrough
# =============================================================================

@test "passes KUBERNETES_WORKLOAD_* variables to generator" {
  export KUBERNETES_WORKLOAD_TYPE="deployment"
  export KUBERNETES_WORKLOAD_NAME_SUFFIX="backend"

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/deployment-backend.yaml" ]
}

@test "passes KUBERNETES_DEPLOYMENT_* variables to generator" {
  export KUBERNETES_WORKLOAD_TYPE="deployment"
  export KUBERNETES_WORKLOAD_REPLICAS="3"

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 0 ]

  manifest=$(cat "$OUTPUT_SUB_PATH/manifests/combined/deployment.yaml")
  [[ "$manifest" == *"replicas: 3"* ]] || return 1
}

# =============================================================================
# Workload-level envSubPath, labels and annotations as fallbacks: the per-type
# value wins, else the workload-level value, else the default
# =============================================================================

WORKLOAD_TYPES="deployment statefulset daemonset cronjob job"

# Fresh project dir for one workload type
# Usage: dir=$(project_dir <type>)
project_dir() {
  local dir
  dir=$(create_test_dir "gen-workload-${1}")
  mkdir -p "${dir}/src/kubernetes"
  echo "${dir}"
}

# Generate one workload type in a project dir, print its manifest
# Usage: generate_type <type> [<dir>]
generate_type() {
  local type="${1}" dir="${2:-}"
  [[ -n "${dir}" ]] || dir=$(project_dir "${type}")
  cd "${dir}"
  export OUTPUT_SUB_PATH="${dir}/kaptain-out"
  KUBERNETES_WORKLOAD_TYPE="${type}" "$GENERATORS_DIR/generate-kubernetes-workload" > "${dir}/generator.log" 2>&1 \
    || { cat "${dir}/generator.log"; return 1; }
  cat "${OUTPUT_SUB_PATH}"/manifests/combined/*.yaml
}

@test "fallback: workload-level labels and annotations apply to every type when unset per type" {
  export KUBERNETES_WORKLOAD_ADDITIONAL_LABELS="tier=shared"
  export KUBERNETES_WORKLOAD_ADDITIONAL_ANNOTATIONS="owner=platform"
  local type manifest
  for type in ${WORKLOAD_TYPES}; do
    manifest=$(generate_type "${type}") || return 1
    [[ "${manifest}" == *'tier: "shared"'* ]] || { echo "${type}: no workload label"; return 1; }
    [[ "${manifest}" == *'owner: "platform"'* ]] || { echo "${type}: no workload annotation"; return 1; }
  done
}

@test "fallback: per-type labels and annotations win over workload-level ones" {
  export KUBERNETES_WORKLOAD_ADDITIONAL_LABELS="tier=shared"
  export KUBERNETES_WORKLOAD_ADDITIONAL_ANNOTATIONS="owner=platform"
  local type upper manifest
  for type in ${WORKLOAD_TYPES}; do
    upper=$(printf '%s' "${type}" | tr '[:lower:]' '[:upper:]')
    export "KUBERNETES_${upper}_ADDITIONAL_LABELS=tier=${type}"
    export "KUBERNETES_${upper}_ADDITIONAL_ANNOTATIONS=owner=${type}"
    manifest=$(generate_type "${type}") || return 1
    [[ "${manifest}" == *"tier: \"${type}\""* ]] || { echo "${type}: per-type label lost"; return 1; }
    [[ "${manifest}" != *'tier: "shared"'* ]] || { echo "${type}: workload label leaked"; return 1; }
    [[ "${manifest}" == *"owner: \"${type}\""* ]] || { echo "${type}: per-type annotation lost"; return 1; }
    [[ "${manifest}" != *'owner: "platform"'* ]] || { echo "${type}: workload annotation leaked"; return 1; }
  done
}

@test "fallback: workload-level envSubPath is read by every type when unset per type" {
  export KUBERNETES_WORKLOAD_ENV_SUB_PATH="src/shared-env"
  local type manifest dir
  for type in ${WORKLOAD_TYPES}; do
    dir=$(project_dir "${type}")
    mkdir -p "${dir}/src/shared-env"
    printf 'from-shared' > "${dir}/src/shared-env/SHARED_SETTING"
    manifest=$(generate_type "${type}" "${dir}") || return 1
    [[ "${manifest}" == *"- name: SHARED_SETTING"* ]] || { echo "${type}: workload env not read"; return 1; }
  done
}

@test "fallback: per-type envSubPath wins over the workload-level one" {
  export KUBERNETES_WORKLOAD_ENV_SUB_PATH="src/shared-env"
  export KUBERNETES_DEPLOYMENT_ENV_SUB_PATH="src/own-env"
  local dir manifest
  dir=$(project_dir deployment)
  mkdir -p "${dir}/src/shared-env" "${dir}/src/own-env"
  printf 'from-shared' > "${dir}/src/shared-env/SHARED_SETTING"
  printf 'from-own' > "${dir}/src/own-env/OWN_SETTING"
  manifest=$(generate_type deployment "${dir}") || return 1
  [[ "${manifest}" == *"- name: OWN_SETTING"* ]] || return 1
  [[ "${manifest}" != *"SHARED_SETTING"* ]] || return 1
}

@test "fallback: with neither set each type keeps its own default env path" {
  local dir manifest
  dir=$(project_dir statefulset)
  mkdir -p "${dir}/src/statefulset-env"
  printf 'x' > "${dir}/src/statefulset-env/DEFAULT_SETTING"
  manifest=$(generate_type statefulset "${dir}") || return 1
  [[ "${manifest}" == *"- name: DEFAULT_SETTING"* ]] || return 1
}
