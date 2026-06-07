#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-poddisruptionbudget

bats_require_minimum_version 1.5.0

load helpers

setup() {
  export OUTPUT_SUB_PATH=$(create_test_dir "gen-pdb")
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"
  export KUBERNETES_WORKLOAD_TYPE="deployment"
  export KUBERNETES_PODDISRUPTIONBUDGET_GENERATION_ENABLED="true"
  export REPOSITORY_OWNER="kube-kaptain"
  export SOURCE_REPO="kube-kaptain/test-project"
  export IMAGE_URI="ghcr.io/kube-kaptain/test-project:1.0.0"
}

teardown() {
  dump_bats_result
  :
}

# Helper to read generated manifest
read_manifest() {
  cat "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml"
}

read_manifest_with_suffix() {
  local suffix="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget-${suffix}.yaml"
}

read_manifest_in_subpath() {
  local subpath="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/${subpath}/poddisruptionbudget.yaml"
}

# =============================================================================
# Generation enabled/disabled - smart defaults
# =============================================================================

@test "smart default: enabled for deployment workload type" {
  unset KUBERNETES_PODDISRUPTIONBUDGET_GENERATION_ENABLED
  export KUBERNETES_WORKLOAD_TYPE="deployment"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml" ]
}

@test "smart default: enabled for statefulset workload type" {
  unset KUBERNETES_PODDISRUPTIONBUDGET_GENERATION_ENABLED
  export KUBERNETES_WORKLOAD_TYPE="statefulset"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml" ]
}

@test "smart default: disabled for other workload types" {
  unset KUBERNETES_PODDISRUPTIONBUDGET_GENERATION_ENABLED
  export KUBERNETES_WORKLOAD_TYPE="cronjob"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not enabled"* ]] || return 1
  [ ! -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml" ]
}

@test "explicit false overrides smart default for deployment" {
  export KUBERNETES_PODDISRUPTIONBUDGET_GENERATION_ENABLED="false"
  export KUBERNETES_WORKLOAD_TYPE="deployment"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not enabled"* ]] || return 1
  [ ! -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml" ]
}

@test "explicit true overrides smart default for other types" {
  export KUBERNETES_PODDISRUPTIONBUDGET_GENERATION_ENABLED="true"
  export KUBERNETES_WORKLOAD_TYPE="cronjob"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml" ]
}

# =============================================================================
# Basic functionality
# =============================================================================

@test "generates valid PodDisruptionBudget structure" {
  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"apiVersion: policy/v1"* ]] || return 1
  [[ "$manifest" == *"kind: PodDisruptionBudget"* ]] || return 1
  [[ "$manifest" == *"metadata:"* ]] || return 1
  [[ "$manifest" == *'name: ${ProjectName}'* ]] || return 1
  [[ "$manifest" == *'namespace: ${Environment}'* ]] || return 1
}

@test "includes selector matching workload" {
  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"selector:"* ]] || return 1
  [[ "$manifest" == *"matchLabels:"* ]] || return 1
  [[ "$manifest" == *'app: ${ProjectName}'* ]] || return 1
}

@test "includes standard labels" {
  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"labels:"* ]] || return 1
  [[ "$manifest" == *'app: ${ProjectName}'* ]] || return 1
  [[ "$manifest" == *'app.kubernetes.io/name: ${ProjectName}'* ]] || return 1
  [[ "$manifest" == *'app.kubernetes.io/version: "${Version}"'* ]] || return 1
  [[ "$manifest" == *"app.kubernetes.io/managed-by: Kaptain"* ]] || return 1
  [[ "$manifest" == *'kaptain.org/version: "${Version}"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/project-name: ${ProjectName}'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/owner: kube-kaptain'* ]] || return 1
}

@test "includes kaptain annotations" {
  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"annotations:"* ]] || return 1
  [[ "$manifest" == *'kaptain.org/project-name: ${ProjectName}'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/version: "${Version}"'* ]] || return 1
  [[ "$manifest" == *"kaptain.org/build-timestamp:"* ]] || return 1
  [[ "$manifest" == *'kaptain.org/generated-by: "Generated by Kaptain generate-kubernetes-poddisruptionbudget"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/built-by: test'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/source-repository: kube-kaptain/test-project'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/image-uri: ghcr.io/kube-kaptain/test-project:1.0.0'* ]] || return 1
}

# =============================================================================
# Strategy and value
# =============================================================================

@test "default strategy is max-unavailable with value 1" {
  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"maxUnavailable: 1"* ]] || return 1
  [[ "$manifest" != *"minAvailable:"* ]] || return 1
}

@test "max-unavailable strategy generates maxUnavailable field" {
  export KUBERNETES_PODDISRUPTIONBUDGET_STRATEGY="max-unavailable"
  export KUBERNETES_PODDISRUPTIONBUDGET_VALUE="2"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"maxUnavailable: 2"* ]] || return 1
  [[ "$manifest" != *"minAvailable:"* ]] || return 1
}

@test "min-available strategy generates minAvailable field" {
  export KUBERNETES_PODDISRUPTIONBUDGET_STRATEGY="min-available"
  export KUBERNETES_PODDISRUPTIONBUDGET_VALUE="1"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"minAvailable: 1"* ]] || return 1
  [[ "$manifest" != *"maxUnavailable:"* ]] || return 1
}

@test "supports percentage values" {
  export KUBERNETES_PODDISRUPTIONBUDGET_STRATEGY="max-unavailable"
  export KUBERNETES_PODDISRUPTIONBUDGET_VALUE="25%"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"maxUnavailable: 25%"* ]] || return 1
}

@test "fails with invalid strategy" {
  export KUBERNETES_PODDISRUPTIONBUDGET_STRATEGY="invalid"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 4 ]
  [[ "$output" == *"Invalid"* ]] || return 1
  [[ "$output" == *"min-available"* ]] || return 1
  [[ "$output" == *"max-unavailable"* ]] || return 1
}

@test "empty value gets default of 1" {
  export KUBERNETES_PODDISRUPTIONBUDGET_VALUE=""

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"maxUnavailable: 1"* ]] || return 1
}

# =============================================================================
# Token styles
# =============================================================================

@test "respects PascalCase token name style" {
  export TOKEN_NAME_STYLE="PascalCase"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${ProjectName}'* ]] || return 1
  [[ "$manifest" == *'${Environment}'* ]] || return 1
}

@test "respects lower-kebab token name style" {
  export TOKEN_NAME_STYLE="lower-kebab"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${project-name}'* ]] || return 1
  [[ "$manifest" == *'${environment}'* ]] || return 1
}

@test "respects mustache substitution style" {
  export TOKEN_DELIMITER_STYLE="mustache"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'{{ ProjectName }}'* ]] || return 1
  [[ "$manifest" == *'{{ Environment }}'* ]] || return 1
}

@test "fails with unknown token name style" {
  export TOKEN_NAME_STYLE="unknown"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 2 ]
}

@test "fails with unknown substitution token style" {
  export TOKEN_DELIMITER_STYLE="unknown"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 3 ]
}

# =============================================================================
# Output paths
# =============================================================================

@test "creates output directory if missing" {
  export OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH}/fresh-subdir"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml" ]
}

@test "respects custom OUTPUT_SUB_PATH" {
  export OUTPUT_SUB_PATH=$(create_test_dir "pdb-custom")

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml" ]
}

# =============================================================================
# Additional labels and annotations
# =============================================================================

@test "adds global additional labels" {
  export KUBERNETES_GLOBAL_ADDITIONAL_LABELS="team=platform,cost-center=123"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"team: platform"* ]] || return 1
  [[ "$manifest" == *"cost-center: 123"* ]] || return 1
}

@test "adds pdb-specific additional labels" {
  export KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_LABELS="pdb-label=value"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"pdb-label: value"* ]] || return 1
}

@test "pdb labels override global labels" {
  export KUBERNETES_GLOBAL_ADDITIONAL_LABELS="team=platform"
  export KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_LABELS="team=override"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"team: override"* ]] || return 1
  [[ "$manifest" != *"team: platform"* ]] || return 1
}

@test "adds global additional annotations" {
  export KUBERNETES_GLOBAL_ADDITIONAL_ANNOTATIONS="example.com/note=test"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"example.com/note: test"* ]] || return 1
}

@test "adds pdb-specific additional annotations" {
  export KUBERNETES_PODDISRUPTIONBUDGET_ADDITIONAL_ANNOTATIONS="example.com/pdb-note=pdb-test"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"example.com/pdb-note: pdb-test"* ]] || return 1
}

# =============================================================================
# Name suffix
# =============================================================================

@test "suffix affects metadata.name" {
  export KUBERNETES_PODDISRUPTIONBUDGET_NAME_SUFFIX="backend"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_with_suffix "backend")
  [[ "$manifest" == *'name: ${ProjectName}-backend'* ]] || return 1
}

@test "suffix affects output filename" {
  export KUBERNETES_PODDISRUPTIONBUDGET_NAME_SUFFIX="backend"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget-backend.yaml" ]
}

@test "no suffix uses default filename" {
  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/poddisruptionbudget.yaml" ]
}

# =============================================================================
# Combined sub-path
# =============================================================================

@test "combined sub-path creates subdirectory in combined/" {
  export KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH="apps/backend"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/apps/backend/poddisruptionbudget.yaml" ]
}

@test "combined sub-path affects metadata.name" {
  export KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH="apps-backend"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_in_subpath "apps-backend")
  [[ "$manifest" == *'name: ${ProjectName}-apps-backend'* ]] || return 1
}

@test "combined sub-path with suffix: name is ProjectName-combined-suffix" {
  export KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH="apps"
  export KUBERNETES_PODDISRUPTIONBUDGET_NAME_SUFFIX="backend"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/combined/apps/poddisruptionbudget-backend.yaml" ]
  manifest=$(cat "$OUTPUT_SUB_PATH/manifests/combined/apps/poddisruptionbudget-backend.yaml")
  [[ "$manifest" == *'name: ${ProjectName}-apps-backend'* ]] || return 1
}

@test "nested combined sub-path replaces slashes with hyphens in name" {
  export KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH="omg/wtf"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/combined/omg/wtf/poddisruptionbudget.yaml" ]
  manifest=$(cat "$OUTPUT_SUB_PATH/manifests/combined/omg/wtf/poddisruptionbudget.yaml")
  [[ "$manifest" == *'name: ${ProjectName}-omg-wtf'* ]] || return 1
}

@test "combined sub-path validation rejects uppercase" {
  export KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH="Apps"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 5 ]
}

@test "combined sub-path validation rejects leading slash" {
  export KUBERNETES_PODDISRUPTIONBUDGET_COMBINED_SUB_PATH="/apps"

  run "$GENERATORS_DIR/generate-kubernetes-poddisruptionbudget"
  [ "$status" -eq 6 ]
}
