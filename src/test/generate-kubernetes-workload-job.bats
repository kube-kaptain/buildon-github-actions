#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-workload-job

bats_require_minimum_version 1.5.0

load helpers

setup() {
  export OUTPUT_SUB_PATH=$(create_test_dir "gen-job")
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"
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
  cat "$OUTPUT_SUB_PATH/manifests/combined/job.yaml"
}

read_manifest_with_suffix() {
  local suffix="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/job-${suffix}.yaml"
}

read_manifest_in_subpath() {
  local subpath="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/${subpath}/job.yaml"
}

# =============================================================================
# Basic Job structure
# =============================================================================

@test "generates valid Job structure" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"apiVersion: batch/v1"* ]] || return 1
  [[ "$manifest" == *"kind: Job"* ]] || return 1
  [[ "$manifest" == *"metadata:"* ]] || return 1
  [[ "$manifest" == *"spec:"* ]] || return 1
  [[ "$manifest" == *"template:"* ]] || return 1
}

@test "job name includes version token and job-checksum suffix" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # Pattern: ${ProjectName}-${Version}-job-checksum
  [[ "$manifest" == *'name: ${ProjectName}-${Version}-job-checksum'* ]] || return 1
}

@test "job name with suffix includes version before job-checksum" {
  export KUBERNETES_JOB_NAME_SUFFIX="migrate"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_with_suffix "migrate")
  # Pattern: ${ProjectName}-${suffix}-${Version}-job-checksum
  [[ "$manifest" == *'name: ${ProjectName}-migrate-${Version}-job-checksum'* ]] || return 1
}

@test "job name with combined-sub-path includes version before job-checksum" {
  export KUBERNETES_JOB_COMBINED_SUB_PATH="db"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_in_subpath "db")
  # Pattern: ${ProjectName}-${dir}-${Version}-job-checksum
  [[ "$manifest" == *'name: ${ProjectName}-db-${Version}-job-checksum'* ]] || return 1
}

@test "job name with combined-sub-path and suffix includes version before job-checksum" {
  export KUBERNETES_JOB_COMBINED_SUB_PATH="db"
  export KUBERNETES_JOB_NAME_SUFFIX="migrate"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/combined/db/job-migrate.yaml" ]
  manifest=$(cat "$OUTPUT_SUB_PATH/manifests/combined/db/job-migrate.yaml")
  # Pattern: ${ProjectName}-${dir}-${suffix}-${Version}-job-checksum
  [[ "$manifest" == *'name: ${ProjectName}-db-migrate-${Version}-job-checksum'* ]] || return 1
}

@test "includes namespace token" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'namespace: ${Environment}'* ]] || return 1
}

# =============================================================================
# Job execution settings
# =============================================================================

@test "includes default backoffLimit" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"backoffLimit: 0"* ]] || return 1
}

@test "respects custom backoffLimit" {
  export KUBERNETES_JOB_BACKOFF_LIMIT="3"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"backoffLimit: 3"* ]] || return 1
}

@test "includes default completions" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"completions: 1"* ]] || return 1
}

@test "respects custom completions" {
  export KUBERNETES_JOB_COMPLETIONS="5"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"completions: 5"* ]] || return 1
}

@test "includes default parallelism" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"parallelism: 1"* ]] || return 1
}

@test "respects custom parallelism" {
  export KUBERNETES_JOB_PARALLELISM="3"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"parallelism: 3"* ]] || return 1
}

@test "includes ttlSecondsAfterFinished by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"ttlSecondsAfterFinished: 86400"* ]] || return 1
}

@test "respects custom ttlSecondsAfterFinished" {
  export KUBERNETES_JOB_TTL_SECONDS_AFTER_FINISHED="3600"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"ttlSecondsAfterFinished: 3600"* ]] || return 1
}

@test "omits activeDeadlineSeconds when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"activeDeadlineSeconds"* ]] || return 1
}

@test "includes activeDeadlineSeconds when set" {
  export KUBERNETES_JOB_ACTIVE_DEADLINE_SECONDS="600"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"activeDeadlineSeconds: 600"* ]] || return 1
}

# =============================================================================
# Restart policy
# =============================================================================

@test "default restart policy is Never" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"restartPolicy: Never"* ]] || return 1
}

@test "allows OnFailure restart policy" {
  export KUBERNETES_JOB_RESTART_POLICY="OnFailure"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"restartPolicy: OnFailure"* ]] || return 1
}

@test "rejects Always restart policy" {
  export KUBERNETES_JOB_RESTART_POLICY="Always"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be 'Never' or 'OnFailure'"* ]] || return 1
}

@test "rejects invalid restart policy" {
  export KUBERNETES_JOB_RESTART_POLICY="invalid"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be 'Never' or 'OnFailure'"* ]] || return 1
}

# =============================================================================
# Container command and args
# =============================================================================

@test "omits command when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"command:"* ]] || return 1
}

@test "includes command when set" {
  export KUBERNETES_WORKLOAD_CONTAINER_COMMAND='/bin/sh -c'

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"command:"* ]] || return 1
  [[ "$manifest" == *"/bin/sh"* ]] || return 1
  [[ "$manifest" == *"-c"* ]] || return 1
}

@test "omits args when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"args:"* ]] || return 1
}

@test "includes args when set" {
  export KUBERNETES_WORKLOAD_CONTAINER_COMMAND='/bin/sh -c'
  export KUBERNETES_WORKLOAD_CONTAINER_ARGS='"echo hello"'

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"args:"* ]] || return 1
  [[ "$manifest" == *"echo hello"* ]] || return 1
}

# =============================================================================
# Standard labels and annotations
# =============================================================================

@test "includes standard labels" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"labels:"* ]] || return 1
  # app label includes version in job name
  [[ "$manifest" == *'app: "${ProjectName}-${Version}-job-checksum"'* ]] || return 1
  [[ "$manifest" == *'app.kubernetes.io/version: "${Version}"'* ]] || return 1
  [[ "$manifest" == *'app.kubernetes.io/managed-by: "Kaptain"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/version: "${Version}"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/project-name: "${ProjectName}"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/owner: "kube-kaptain"'* ]] || return 1
}

@test "includes kaptain annotations" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"annotations:"* ]] || return 1
  [[ "$manifest" == *'kaptain.org/project-name: "${ProjectName}"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/version: "${Version}"'* ]] || return 1
  [[ "$manifest" == *"kaptain.org/build-timestamp:"* ]] || return 1
  [[ "$manifest" == *'kaptain.org/generated-by: "Generated by Kaptain generate-kubernetes-workload-job"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/built-by: "test"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/source-repository: "kube-kaptain/test-project"'* ]] || return 1
  [[ "$manifest" == *'kaptain.org/image-uri: "ghcr.io/kube-kaptain/test-project:1.0.0"'* ]] || return 1
}

# =============================================================================
# Token styles
# =============================================================================

@test "respects PascalCase token name style" {
  export TOKEN_NAME_STYLE="PascalCase"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${ProjectName}'* ]] || return 1
  [[ "$manifest" == *'${Version}'* ]] || return 1
  [[ "$manifest" == *'${Environment}'* ]] || return 1
}

@test "respects lower-kebab token name style" {
  export TOKEN_NAME_STYLE="lower-kebab"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${project-name}'* ]] || return 1
  [[ "$manifest" == *'${version}'* ]] || return 1
  [[ "$manifest" == *'${environment}'* ]] || return 1
}

@test "respects mustache substitution style" {
  export TOKEN_DELIMITER_STYLE="mustache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'{{ ProjectName }}'* ]] || return 1
  [[ "$manifest" == *'{{ Version }}'* ]] || return 1
  [[ "$manifest" == *'{{ Environment }}'* ]] || return 1
}

# =============================================================================
# Pod template spec
# =============================================================================

@test "includes container section" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"containers:"* ]] || return 1
  [[ "$manifest" == *"- name: default-app"* ]] || return 1
  [[ "$manifest" == *"image:"* ]] || return 1
  [[ "$manifest" == *"imagePullPolicy:"* ]] || return 1
}

@test "includes termination grace period" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"terminationGracePeriodSeconds:"* ]] || return 1
}

@test "includes resource requests and limits" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"resources:"* ]] || return 1
  [[ "$manifest" == *"requests:"* ]] || return 1
  [[ "$manifest" == *"limits:"* ]] || return 1
}

@test "includes security context" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"securityContext:"* ]] || return 1
}

# =============================================================================
# Output paths
# =============================================================================

@test "creates output directory if missing" {
  export OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH}/fresh-subdir"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/job.yaml" ]
}

@test "suffix affects output filename" {
  export KUBERNETES_JOB_NAME_SUFFIX="migrate"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/job-migrate.yaml" ]
}

@test "combined sub-path creates subdirectory" {
  export KUBERNETES_JOB_COMBINED_SUB_PATH="migrations"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/migrations/job.yaml" ]
}

# =============================================================================
# Additional labels and annotations
# =============================================================================

@test "adds global additional labels" {
  export KUBERNETES_GLOBAL_ADDITIONAL_LABELS="team=platform,cost-center=123"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'team: "platform"'* ]] || return 1
  [[ "$manifest" == *'cost-center: "123"'* ]] || return 1
}

@test "adds job-specific additional labels" {
  export KUBERNETES_JOB_ADDITIONAL_LABELS="job-type=migration"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'job-type: "migration"'* ]] || return 1
}

@test "job labels override global labels" {
  export KUBERNETES_GLOBAL_ADDITIONAL_LABELS="team=platform"
  export KUBERNETES_JOB_ADDITIONAL_LABELS="team=override"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'team: "override"'* ]] || return 1
  [[ "$manifest" != *'team: "platform"'* ]] || return 1
}

# =============================================================================
# Probes (optional, disabled by default)
# =============================================================================

@test "probes disabled by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]] || return 1
  [[ "$manifest" != *"readinessProbe:"* ]] || return 1
  [[ "$manifest" != *"startupProbe:"* ]] || return 1
}

@test "enables liveness probe when requested" {
  export KUBERNETES_JOB_LIVENESS_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]] || return 1
  [[ "$manifest" == *"httpGet:"* ]] || return 1
  [[ "$manifest" == *"path: /liveness"* ]] || return 1
  [[ "$manifest" != *"readinessProbe:"* ]] || return 1
  [[ "$manifest" != *"startupProbe:"* ]] || return 1
}

@test "enables readiness probe when requested" {
  export KUBERNETES_JOB_READINESS_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]] || return 1
  [[ "$manifest" == *"readinessProbe:"* ]] || return 1
  [[ "$manifest" == *"httpGet:"* ]] || return 1
  [[ "$manifest" == *"path: /readiness"* ]] || return 1
  [[ "$manifest" != *"startupProbe:"* ]] || return 1
}

@test "enables startup probe when requested" {
  export KUBERNETES_JOB_STARTUP_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]] || return 1
  [[ "$manifest" != *"readinessProbe:"* ]] || return 1
  [[ "$manifest" == *"startupProbe:"* ]] || return 1
  [[ "$manifest" == *"httpGet:"* ]] || return 1
  [[ "$manifest" == *"path: /startup"* ]] || return 1
}

@test "enables all probes when requested" {
  export KUBERNETES_JOB_LIVENESS_PROBE_ENABLED="true"
  export KUBERNETES_JOB_READINESS_PROBE_ENABLED="true"
  export KUBERNETES_JOB_STARTUP_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]] || return 1
  [[ "$manifest" == *"readinessProbe:"* ]] || return 1
  [[ "$manifest" == *"startupProbe:"* ]] || return 1
}

@test "probes use workload probe settings" {
  export KUBERNETES_JOB_LIVENESS_PROBE_ENABLED="true"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_CHECK_TYPE="tcp-socket"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_TCP_PORT="5432"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_INITIAL_DELAY_SECONDS="15"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]] || return 1
  [[ "$manifest" == *"tcpSocket:"* ]] || return 1
  [[ "$manifest" == *"port: 5432"* ]] || return 1
  [[ "$manifest" == *"initialDelaySeconds: 15"* ]] || return 1
}

# =============================================================================
# Affinity
# =============================================================================

@test "default affinity strategy generates affinity block" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]] || return 1
  [[ "$manifest" == *"podAntiAffinity:"* ]] || return 1
}

@test "affinity strategy none omits affinity block" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="none"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"affinity:"* ]] || return 1
}

@test "affinity strategy spread-nodes generates node spread" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="spread-nodes"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]] || return 1
  [[ "$manifest" == *"topologyKey: kubernetes.io/hostname"* ]] || return 1
}

@test "affinity strategy colocate-app generates pod affinity" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="colocate-app"
  export COLOCATE_WITH_APP="database"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]] || return 1
  [[ "$manifest" == *"podAffinity:"* ]] || return 1
}

# =============================================================================
# Ports (optional, disabled by default)
# =============================================================================

@test "ports disabled by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"ports:"* ]] || return 1
  [[ "$manifest" != *"containerPort:"* ]] || return 1
}

@test "enables ports when requested" {
  export KUBERNETES_JOB_PORTS_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"ports:"* ]] || return 1
  [[ "$manifest" == *"containerPort:"* ]] || return 1
}

@test "ports use workload container port setting" {
  export KUBERNETES_JOB_PORTS_ENABLED="true"
  export KUBERNETES_WORKLOAD_CONTAINER_PORT="9090"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"containerPort: 9090"* ]] || return 1
}

# =============================================================================
# Lifecycle hooks (optional)
# =============================================================================

@test "lifecycle hook omitted by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"lifecycle:"* ]] || return 1
  [[ "$manifest" != *"preStop:"* ]] || return 1
}

@test "includes lifecycle hook when prestop command set" {
  export KUBERNETES_WORKLOAD_PRESTOP_COMMAND="echo cleanup"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"lifecycle:"* ]] || return 1
  [[ "$manifest" == *"preStop:"* ]] || return 1
  [[ "$manifest" == *"echo cleanup"* ]] || return 1
}

# =============================================================================
# Node selector
# =============================================================================

@test "node selector omitted by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"nodeSelector:"* ]] || return 1
}

@test "includes node selector when set" {
  export KUBERNETES_WORKLOAD_NODE_SELECTOR="disktype=ssd"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"nodeSelector:"* ]] || return 1
  [[ "$manifest" == *'disktype: "ssd"'* ]] || return 1
}

@test "node selector supports multiple values" {
  export KUBERNETES_WORKLOAD_NODE_SELECTOR="disktype=ssd,zone=us-east-1a"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'disktype: "ssd"'* ]] || return 1
  [[ "$manifest" == *'zone: "us-east-1a"'* ]] || return 1
}

# =============================================================================
# DNS policy
# =============================================================================

@test "dns policy omitted by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"dnsPolicy:"* ]] || return 1
}

@test "includes dns policy when set" {
  export KUBERNETES_WORKLOAD_DNS_POLICY="ClusterFirst"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"dnsPolicy: ClusterFirst"* ]] || return 1
}

@test "rejects invalid dns policy" {
  export KUBERNETES_WORKLOAD_DNS_POLICY="InvalidPolicy"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 4 ]
  [[ "$output" == *"must be"* ]] || return 1
}
