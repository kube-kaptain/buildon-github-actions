#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-workload (router)

load helpers

setup() {
  export OUTPUT_SUB_PATH=$(create_test_dir "gen-workload")
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"
}

teardown() {
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
  [[ "$output" == *"Workload generation disabled"* ]]
  [ ! -f "$OUTPUT_SUB_PATH/manifests/combined/deployment.yaml" ]
}

@test "fails with unknown workload type" {
  export KUBERNETES_WORKLOAD_TYPE="unknown"

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown workload type 'unknown'"* ]]
}

@test "lists available types on unknown type error" {
  export KUBERNETES_WORKLOAD_TYPE="unknown"

  run "$GENERATORS_DIR/generate-kubernetes-workload"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Available workload types:"* ]]
  [[ "$output" == *"deployment"* ]]
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
  [[ "$manifest" == *"replicas: 3"* ]]
}
