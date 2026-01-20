#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-workload-job

load helpers

setup() {
  export OUTPUT_SUB_PATH=$(create_test_dir "gen-job")
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"
  export KUBERNETES_JOB_GENERATION_ENABLED="true"
}

teardown() {
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
# Generation enabled/disabled
# =============================================================================

@test "skips generation when not enabled" {
  export KUBERNETES_JOB_GENERATION_ENABLED="false"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not enabled"* ]]
  [ ! -f "$OUTPUT_SUB_PATH/manifests/combined/job.yaml" ]
}

@test "skips generation when enabled not set" {
  unset KUBERNETES_JOB_GENERATION_ENABLED

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not enabled"* ]]
  [ ! -f "$OUTPUT_SUB_PATH/manifests/combined/job.yaml" ]
}

@test "generates when explicitly enabled" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/job.yaml" ]
}

# =============================================================================
# Basic Job structure
# =============================================================================

@test "generates valid Job structure" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"apiVersion: batch/v1"* ]]
  [[ "$manifest" == *"kind: Job"* ]]
  [[ "$manifest" == *"metadata:"* ]]
  [[ "$manifest" == *"spec:"* ]]
  [[ "$manifest" == *"template:"* ]]
}

@test "job name includes version token and job-checksum suffix" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # Pattern: ${ProjectName}-${Version}-job-checksum
  [[ "$manifest" == *'name: ${ProjectName}-${Version}-job-checksum'* ]]
}

@test "job name with suffix includes version before job-checksum" {
  export KUBERNETES_JOB_NAME_SUFFIX="migrate"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_with_suffix "migrate")
  # Pattern: ${ProjectName}-${suffix}-${Version}-job-checksum
  [[ "$manifest" == *'name: ${ProjectName}-migrate-${Version}-job-checksum'* ]]
}

@test "job name with combined-sub-path includes version before job-checksum" {
  export KUBERNETES_JOB_COMBINED_SUB_PATH="db"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_in_subpath "db")
  # Pattern: ${ProjectName}-${dir}-${Version}-job-checksum
  [[ "$manifest" == *'name: ${ProjectName}-db-${Version}-job-checksum'* ]]
}

@test "job name with combined-sub-path and suffix includes version before job-checksum" {
  export KUBERNETES_JOB_COMBINED_SUB_PATH="db"
  export KUBERNETES_JOB_NAME_SUFFIX="migrate"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/combined/db/job-migrate.yaml" ]
  manifest=$(cat "$OUTPUT_SUB_PATH/manifests/combined/db/job-migrate.yaml")
  # Pattern: ${ProjectName}-${dir}-${suffix}-${Version}-job-checksum
  [[ "$manifest" == *'name: ${ProjectName}-db-migrate-${Version}-job-checksum'* ]]
}

@test "includes namespace token" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'namespace: ${Environment}'* ]]
}

# =============================================================================
# Job execution settings
# =============================================================================

@test "includes default backoffLimit" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"backoffLimit: 6"* ]]
}

@test "respects custom backoffLimit" {
  export KUBERNETES_JOB_BACKOFF_LIMIT="3"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"backoffLimit: 3"* ]]
}

@test "includes default completions" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"completions: 1"* ]]
}

@test "respects custom completions" {
  export KUBERNETES_JOB_COMPLETIONS="5"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"completions: 5"* ]]
}

@test "includes default parallelism" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"parallelism: 1"* ]]
}

@test "respects custom parallelism" {
  export KUBERNETES_JOB_PARALLELISM="3"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"parallelism: 3"* ]]
}

@test "includes ttlSecondsAfterFinished by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"ttlSecondsAfterFinished: 86400"* ]]
}

@test "respects custom ttlSecondsAfterFinished" {
  export KUBERNETES_JOB_TTL_SECONDS_AFTER_FINISHED="3600"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"ttlSecondsAfterFinished: 3600"* ]]
}

@test "omits activeDeadlineSeconds when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"activeDeadlineSeconds"* ]]
}

@test "includes activeDeadlineSeconds when set" {
  export KUBERNETES_JOB_ACTIVE_DEADLINE_SECONDS="600"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"activeDeadlineSeconds: 600"* ]]
}

# =============================================================================
# Restart policy
# =============================================================================

@test "default restart policy is Never" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"restartPolicy: Never"* ]]
}

@test "allows OnFailure restart policy" {
  export KUBERNETES_JOB_RESTART_POLICY="OnFailure"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"restartPolicy: OnFailure"* ]]
}

@test "rejects Always restart policy" {
  export KUBERNETES_JOB_RESTART_POLICY="Always"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be 'Never' or 'OnFailure'"* ]]
}

@test "rejects invalid restart policy" {
  export KUBERNETES_JOB_RESTART_POLICY="invalid"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be 'Never' or 'OnFailure'"* ]]
}

# =============================================================================
# Container command and args
# =============================================================================

@test "omits command when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"command:"* ]]
}

@test "includes command when set" {
  export KUBERNETES_WORKLOAD_CONTAINER_COMMAND='/bin/sh -c'

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"command:"* ]]
  [[ "$manifest" == *"/bin/sh"* ]]
  [[ "$manifest" == *"-c"* ]]
}

@test "omits args when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"args:"* ]]
}

@test "includes args when set" {
  export KUBERNETES_WORKLOAD_CONTAINER_COMMAND='/bin/sh -c'
  export KUBERNETES_WORKLOAD_CONTAINER_ARGS='"echo hello"'

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"args:"* ]]
  [[ "$manifest" == *"echo hello"* ]]
}

# =============================================================================
# Standard labels and annotations
# =============================================================================

@test "includes standard labels" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"labels:"* ]]
  # app label includes version in job name
  [[ "$manifest" == *'app: ${ProjectName}-${Version}-job-checksum'* ]]
  [[ "$manifest" == *'app.kubernetes.io/version: ${Version}'* ]]
  [[ "$manifest" == *"app.kubernetes.io/managed-by: Kaptain"* ]]
}

@test "includes kaptain annotations" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"annotations:"* ]]
  [[ "$manifest" == *'kaptain/project-name: ${ProjectName}'* ]]
  [[ "$manifest" == *'kaptain/version: ${Version}'* ]]
  [[ "$manifest" == *"kaptain/build-timestamp:"* ]]
  [[ "$manifest" == *'kaptain/generated-by: "Generated by Kaptain generate-kubernetes-workload-job"'* ]]
}

# =============================================================================
# Token styles
# =============================================================================

@test "respects PascalCase token name style" {
  export TOKEN_NAME_STYLE="PascalCase"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${ProjectName}'* ]]
  [[ "$manifest" == *'${Version}'* ]]
  [[ "$manifest" == *'${Environment}'* ]]
}

@test "respects lower-kebab token name style" {
  export TOKEN_NAME_STYLE="lower-kebab"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${project-name}'* ]]
  [[ "$manifest" == *'${version}'* ]]
  [[ "$manifest" == *'${environment}'* ]]
}

@test "respects mustache substitution style" {
  export TOKEN_DELIMITER_STYLE="mustache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'{{ ProjectName }}'* ]]
  [[ "$manifest" == *'{{ Version }}'* ]]
  [[ "$manifest" == *'{{ Environment }}'* ]]
}

# =============================================================================
# Pod template spec
# =============================================================================

@test "includes container section" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"containers:"* ]]
  [[ "$manifest" == *"- name: default-app"* ]]
  [[ "$manifest" == *"image:"* ]]
  [[ "$manifest" == *"imagePullPolicy:"* ]]
}

@test "includes termination grace period" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"terminationGracePeriodSeconds:"* ]]
}

@test "includes resource requests and limits" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"resources:"* ]]
  [[ "$manifest" == *"requests:"* ]]
  [[ "$manifest" == *"limits:"* ]]
}

@test "includes security context" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"securityContext:"* ]]
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
  [[ "$manifest" == *"team: platform"* ]]
  [[ "$manifest" == *"cost-center: 123"* ]]
}

@test "adds job-specific additional labels" {
  export KUBERNETES_JOB_ADDITIONAL_LABELS="job-type=migration"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"job-type: migration"* ]]
}

@test "job labels override global labels" {
  export KUBERNETES_GLOBAL_ADDITIONAL_LABELS="team=platform"
  export KUBERNETES_JOB_ADDITIONAL_LABELS="team=override"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"team: override"* ]]
  [[ "$manifest" != *"team: platform"* ]]
}

# =============================================================================
# Probes (optional, disabled by default)
# =============================================================================

@test "probes disabled by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]]
  [[ "$manifest" != *"readinessProbe:"* ]]
  [[ "$manifest" != *"startupProbe:"* ]]
}

@test "enables liveness probe when requested" {
  export KUBERNETES_JOB_LIVENESS_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"httpGet:"* ]]
  [[ "$manifest" == *"path: /liveness"* ]]
  [[ "$manifest" != *"readinessProbe:"* ]]
  [[ "$manifest" != *"startupProbe:"* ]]
}

@test "enables readiness probe when requested" {
  export KUBERNETES_JOB_READINESS_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]]
  [[ "$manifest" == *"readinessProbe:"* ]]
  [[ "$manifest" == *"httpGet:"* ]]
  [[ "$manifest" == *"path: /readiness"* ]]
  [[ "$manifest" != *"startupProbe:"* ]]
}

@test "enables startup probe when requested" {
  export KUBERNETES_JOB_STARTUP_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]]
  [[ "$manifest" != *"readinessProbe:"* ]]
  [[ "$manifest" == *"startupProbe:"* ]]
  [[ "$manifest" == *"httpGet:"* ]]
  [[ "$manifest" == *"path: /startup"* ]]
}

@test "enables all probes when requested" {
  export KUBERNETES_JOB_LIVENESS_PROBE_ENABLED="true"
  export KUBERNETES_JOB_READINESS_PROBE_ENABLED="true"
  export KUBERNETES_JOB_STARTUP_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"readinessProbe:"* ]]
  [[ "$manifest" == *"startupProbe:"* ]]
}

@test "probes use workload probe settings" {
  export KUBERNETES_JOB_LIVENESS_PROBE_ENABLED="true"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_CHECK_TYPE="tcp-socket"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_TCP_PORT="5432"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_INITIAL_DELAY_SECONDS="15"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"tcpSocket:"* ]]
  [[ "$manifest" == *"port: 5432"* ]]
  [[ "$manifest" == *"initialDelaySeconds: 15"* ]]
}

# =============================================================================
# Affinity
# =============================================================================

@test "default affinity strategy generates affinity block" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]]
  [[ "$manifest" == *"podAntiAffinity:"* ]]
}

@test "affinity strategy none omits affinity block" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="none"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"affinity:"* ]]
}

@test "affinity strategy spread-nodes generates node spread" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="spread-nodes"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]]
  [[ "$manifest" == *"topologyKey: kubernetes.io/hostname"* ]]
}

@test "affinity strategy colocate-app generates pod affinity" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="colocate-app"
  export COLOCATE_WITH_APP="database"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]]
  [[ "$manifest" == *"podAffinity:"* ]]
}

# =============================================================================
# Ports (optional, disabled by default)
# =============================================================================

@test "ports disabled by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"ports:"* ]]
  [[ "$manifest" != *"containerPort:"* ]]
}

@test "enables ports when requested" {
  export KUBERNETES_JOB_PORTS_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"ports:"* ]]
  [[ "$manifest" == *"containerPort:"* ]]
}

@test "ports use workload container port setting" {
  export KUBERNETES_JOB_PORTS_ENABLED="true"
  export KUBERNETES_WORKLOAD_CONTAINER_PORT="9090"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"containerPort: 9090"* ]]
}

# =============================================================================
# Lifecycle hooks (optional)
# =============================================================================

@test "lifecycle hook omitted by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"lifecycle:"* ]]
  [[ "$manifest" != *"preStop:"* ]]
}

@test "includes lifecycle hook when prestop command set" {
  export KUBERNETES_WORKLOAD_PRESTOP_COMMAND="echo cleanup"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"lifecycle:"* ]]
  [[ "$manifest" == *"preStop:"* ]]
  [[ "$manifest" == *"echo cleanup"* ]]
}

# =============================================================================
# Node selector
# =============================================================================

@test "node selector omitted by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"nodeSelector:"* ]]
}

@test "includes node selector when set" {
  export KUBERNETES_WORKLOAD_NODE_SELECTOR="disktype=ssd"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"nodeSelector:"* ]]
  [[ "$manifest" == *'disktype: "ssd"'* ]]
}

@test "node selector supports multiple values" {
  export KUBERNETES_WORKLOAD_NODE_SELECTOR="disktype=ssd,zone=us-east-1a"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'disktype: "ssd"'* ]]
  [[ "$manifest" == *'zone: "us-east-1a"'* ]]
}

# =============================================================================
# DNS policy
# =============================================================================

@test "dns policy omitted by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"dnsPolicy:"* ]]
}

@test "includes dns policy when set" {
  export KUBERNETES_WORKLOAD_DNS_POLICY="ClusterFirst"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"dnsPolicy: ClusterFirst"* ]]
}

@test "rejects invalid dns policy" {
  export KUBERNETES_WORKLOAD_DNS_POLICY="InvalidPolicy"

  run "$GENERATORS_DIR/generate-kubernetes-workload-job"
  [ "$status" -eq 4 ]
  [[ "$output" == *"must be"* ]]
}
