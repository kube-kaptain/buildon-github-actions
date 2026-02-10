#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for generate-kubernetes-workload-cronjob

load helpers

setup() {
  export OUTPUT_SUB_PATH=$(create_test_dir "gen-cronjob")
  export PROJECT_NAME="my-project"
  export TOKEN_NAME_STYLE="PascalCase"
  export TOKEN_DELIMITER_STYLE="shell"
}

teardown() {
  :
}

# Helper to read generated manifest
read_manifest() {
  cat "$OUTPUT_SUB_PATH/manifests/combined/cronjob.yaml"
}

read_manifest_with_suffix() {
  local suffix="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/cronjob-${suffix}.yaml"
}

read_manifest_in_subpath() {
  local subpath="$1"
  cat "$OUTPUT_SUB_PATH/manifests/combined/${subpath}/cronjob.yaml"
}

# =============================================================================
# Basic CronJob structure
# =============================================================================

@test "generates valid CronJob structure" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"apiVersion: batch/v1"* ]]
  [[ "$manifest" == *"kind: CronJob"* ]]
  [[ "$manifest" == *"metadata:"* ]]
  [[ "$manifest" == *"spec:"* ]]
  [[ "$manifest" == *"jobTemplate:"* ]]
}

@test "cronjob name does not include version (not versioned like Job)" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  # CronJob name should be just ${ProjectName}, no version token
  [[ "$manifest" == *'name: ${ProjectName}'* ]]
  # Should NOT contain version in the name
  [[ "$manifest" != *'name: ${ProjectName}-${Version}'* ]]
}

@test "cronjob name with suffix" {
  export KUBERNETES_CRONJOB_NAME_SUFFIX="backup"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_with_suffix "backup")
  [[ "$manifest" == *'name: ${ProjectName}-backup'* ]]
}

@test "cronjob name with combined-sub-path" {
  export KUBERNETES_CRONJOB_COMBINED_SUB_PATH="db"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_in_subpath "db")
  [[ "$manifest" == *'name: ${ProjectName}-db'* ]]
}

@test "includes namespace token" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'namespace: ${Environment}'* ]]
}

# =============================================================================
# Schedule and suspend tokens
# =============================================================================

@test "schedule is a token with project name prefix" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'schedule: ${MyProjectCronjobSchedule}'* ]]
}

@test "suspend is a token with project name prefix" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'suspend: ${MyProjectCronjobSuspend}'* ]]
}

@test "schedule token includes project name and suffix" {
  export KUBERNETES_CRONJOB_NAME_SUFFIX="backup"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_with_suffix "backup")
  [[ "$manifest" == *'schedule: ${MyProjectBackupCronjobSchedule}'* ]]
  [[ "$manifest" == *'suspend: ${MyProjectBackupCronjobSuspend}'* ]]
}

@test "schedule token includes project name and path" {
  export KUBERNETES_CRONJOB_COMBINED_SUB_PATH="db/primary"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest_in_subpath "db/primary")
  [[ "$manifest" == *'schedule: ${MyProjectDbPrimaryCronjobSchedule}'* ]]
  [[ "$manifest" == *'suspend: ${MyProjectDbPrimaryCronjobSuspend}'* ]]
}

@test "schedule token includes project name, path and suffix" {
  export KUBERNETES_CRONJOB_COMBINED_SUB_PATH="db"
  export KUBERNETES_CRONJOB_NAME_SUFFIX="migrate"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  [ -f "$OUTPUT_SUB_PATH/manifests/combined/db/cronjob-migrate.yaml" ]
  manifest=$(cat "$OUTPUT_SUB_PATH/manifests/combined/db/cronjob-migrate.yaml")
  [[ "$manifest" == *'schedule: ${MyProjectDbMigrateCronjobSchedule}'* ]]
  [[ "$manifest" == *'suspend: ${MyProjectDbMigrateCronjobSuspend}'* ]]
}

# =============================================================================
# CronJob execution settings
# =============================================================================

@test "default concurrency policy is Forbid" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"concurrencyPolicy: Forbid"* ]]
}

@test "respects custom concurrency policy Allow" {
  export KUBERNETES_CRONJOB_CONCURRENCY_POLICY="Allow"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"concurrencyPolicy: Allow"* ]]
}

@test "respects custom concurrency policy Replace" {
  export KUBERNETES_CRONJOB_CONCURRENCY_POLICY="Replace"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"concurrencyPolicy: Replace"* ]]
}

@test "rejects invalid concurrency policy" {
  export KUBERNETES_CRONJOB_CONCURRENCY_POLICY="invalid"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be 'Allow', 'Forbid', or 'Replace'"* ]]
}

@test "omits startingDeadlineSeconds when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"startingDeadlineSeconds"* ]]
}

@test "includes startingDeadlineSeconds when set" {
  export KUBERNETES_CRONJOB_STARTING_DEADLINE_SECONDS="300"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"startingDeadlineSeconds: 300"* ]]
}

# =============================================================================
# History limits
# =============================================================================

@test "default successfulJobsHistoryLimit is 1" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"successfulJobsHistoryLimit: 1"* ]]
}

@test "default failedJobsHistoryLimit is 5" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"failedJobsHistoryLimit: 5"* ]]
}

@test "respects custom successfulJobsHistoryLimit" {
  export KUBERNETES_CRONJOB_SUCCESSFUL_JOBS_HISTORY_LIMIT="3"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"successfulJobsHistoryLimit: 3"* ]]
}

@test "respects custom failedJobsHistoryLimit" {
  export KUBERNETES_CRONJOB_FAILED_JOBS_HISTORY_LIMIT="10"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"failedJobsHistoryLimit: 10"* ]]
}

# =============================================================================
# Job template settings
# =============================================================================

@test "includes default backoffLimit in job template" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"backoffLimit: 0"* ]]
}

@test "includes default completions in job template" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"completions: 1"* ]]
}

@test "includes default parallelism in job template" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"parallelism: 1"* ]]
}

@test "omits ttlSecondsAfterFinished by default (keep forever)" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"ttlSecondsAfterFinished"* ]]
}

@test "omits activeDeadlineSeconds when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"activeDeadlineSeconds"* ]]
}

@test "includes activeDeadlineSeconds when set" {
  export KUBERNETES_CRONJOB_ACTIVE_DEADLINE_SECONDS="600"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"activeDeadlineSeconds: 600"* ]]
}

# =============================================================================
# Restart policy
# =============================================================================

@test "default restart policy is Never" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"restartPolicy: Never"* ]]
}

@test "allows OnFailure restart policy" {
  export KUBERNETES_CRONJOB_RESTART_POLICY="OnFailure"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"restartPolicy: OnFailure"* ]]
}

@test "rejects Always restart policy" {
  export KUBERNETES_CRONJOB_RESTART_POLICY="Always"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be 'Never' or 'OnFailure'"* ]]
}

# =============================================================================
# Container command and args
# =============================================================================

@test "omits command when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"command:"* ]]
}

@test "includes command when set" {
  export KUBERNETES_WORKLOAD_CONTAINER_COMMAND='/bin/sh -c'

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"command:"* ]]
  [[ "$manifest" == *"/bin/sh"* ]]
  [[ "$manifest" == *"-c"* ]]
}

@test "omits args when not set" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"args:"* ]]
}

@test "includes args when set" {
  export KUBERNETES_WORKLOAD_CONTAINER_COMMAND='/bin/sh -c'
  export KUBERNETES_WORKLOAD_CONTAINER_ARGS='"echo hello"'

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"args:"* ]]
  [[ "$manifest" == *"echo hello"* ]]
}

# =============================================================================
# Standard labels and annotations
# =============================================================================

@test "includes standard labels" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"labels:"* ]]
  [[ "$manifest" == *'app: ${ProjectName}'* ]]
  [[ "$manifest" == *'app.kubernetes.io/version: "${Version}"'* ]]
  [[ "$manifest" == *"app.kubernetes.io/managed-by: Kaptain"* ]]
}

@test "includes kaptain annotations" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"annotations:"* ]]
  [[ "$manifest" == *'kaptain/project-name: ${ProjectName}'* ]]
  [[ "$manifest" == *'kaptain/version: "${Version}"'* ]]
  [[ "$manifest" == *"kaptain/build-timestamp:"* ]]
  [[ "$manifest" == *'kaptain/generated-by: "Generated by Kaptain generate-kubernetes-workload-cronjob"'* ]]
}

# =============================================================================
# Token styles
# =============================================================================

@test "respects PascalCase token name style" {
  export TOKEN_NAME_STYLE="PascalCase"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${ProjectName}'* ]]
  [[ "$manifest" == *'${MyProjectCronjobSchedule}'* ]]
  [[ "$manifest" == *'${MyProjectCronjobSuspend}'* ]]
}

@test "respects lower-kebab token name style" {
  export TOKEN_NAME_STYLE="lower-kebab"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'${project-name}'* ]]
  [[ "$manifest" == *'${my-project-cronjob-schedule}'* ]]
  [[ "$manifest" == *'${my-project-cronjob-suspend}'* ]]
}

@test "respects mustache substitution style" {
  export TOKEN_DELIMITER_STYLE="mustache"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'{{ ProjectName }}'* ]]
  [[ "$manifest" == *'{{ MyProjectCronjobSchedule }}'* ]]
  [[ "$manifest" == *'{{ MyProjectCronjobSuspend }}'* ]]
}

# =============================================================================
# Pod template spec
# =============================================================================

@test "includes container section" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"containers:"* ]]
  [[ "$manifest" == *"- name: default-app"* ]]
  [[ "$manifest" == *"image:"* ]]
  [[ "$manifest" == *"imagePullPolicy:"* ]]
}

@test "includes termination grace period" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"terminationGracePeriodSeconds:"* ]]
}

@test "includes resource requests and limits" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"resources:"* ]]
  [[ "$manifest" == *"requests:"* ]]
  [[ "$manifest" == *"limits:"* ]]
}

@test "includes security context" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"securityContext:"* ]]
}

# =============================================================================
# Output paths
# =============================================================================

@test "creates output directory if missing" {
  export OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH}/fresh-subdir"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/cronjob.yaml" ]
}

@test "suffix affects output filename" {
  export KUBERNETES_CRONJOB_NAME_SUFFIX="cleanup"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/cronjob-cleanup.yaml" ]
}

@test "combined sub-path creates subdirectory" {
  export KUBERNETES_CRONJOB_COMBINED_SUB_PATH="scheduled"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_SUB_PATH/manifests/combined/scheduled/cronjob.yaml" ]
}

# =============================================================================
# Additional labels and annotations
# =============================================================================

@test "adds global additional labels" {
  export KUBERNETES_GLOBAL_ADDITIONAL_LABELS="team=platform,cost-center=123"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"team: platform"* ]]
  [[ "$manifest" == *"cost-center: 123"* ]]
}

@test "adds cronjob-specific additional labels" {
  export KUBERNETES_CRONJOB_ADDITIONAL_LABELS="schedule-type=nightly"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"schedule-type: nightly"* ]]
}

@test "cronjob labels override global labels" {
  export KUBERNETES_GLOBAL_ADDITIONAL_LABELS="team=platform"
  export KUBERNETES_CRONJOB_ADDITIONAL_LABELS="team=override"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"team: override"* ]]
  [[ "$manifest" != *"team: platform"* ]]
}

# =============================================================================
# Probes (optional, disabled by default)
# =============================================================================

@test "probes disabled by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]]
  [[ "$manifest" != *"readinessProbe:"* ]]
  [[ "$manifest" != *"startupProbe:"* ]]
}

@test "enables liveness probe when requested" {
  export KUBERNETES_CRONJOB_LIVENESS_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"httpGet:"* ]]
  [[ "$manifest" == *"path: /liveness"* ]]
  [[ "$manifest" != *"readinessProbe:"* ]]
  [[ "$manifest" != *"startupProbe:"* ]]
}

@test "enables readiness probe when requested" {
  export KUBERNETES_CRONJOB_READINESS_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]]
  [[ "$manifest" == *"readinessProbe:"* ]]
  [[ "$manifest" == *"httpGet:"* ]]
  [[ "$manifest" == *"path: /readiness"* ]]
  [[ "$manifest" != *"startupProbe:"* ]]
}

@test "enables startup probe when requested" {
  export KUBERNETES_CRONJOB_STARTUP_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"livenessProbe:"* ]]
  [[ "$manifest" != *"readinessProbe:"* ]]
  [[ "$manifest" == *"startupProbe:"* ]]
  [[ "$manifest" == *"httpGet:"* ]]
  [[ "$manifest" == *"path: /startup"* ]]
}

@test "enables all probes when requested" {
  export KUBERNETES_CRONJOB_LIVENESS_PROBE_ENABLED="true"
  export KUBERNETES_CRONJOB_READINESS_PROBE_ENABLED="true"
  export KUBERNETES_CRONJOB_STARTUP_PROBE_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"livenessProbe:"* ]]
  [[ "$manifest" == *"readinessProbe:"* ]]
  [[ "$manifest" == *"startupProbe:"* ]]
}

@test "probes use workload probe settings" {
  export KUBERNETES_CRONJOB_LIVENESS_PROBE_ENABLED="true"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_CHECK_TYPE="tcp-socket"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_TCP_PORT="5432"
  export KUBERNETES_WORKLOAD_PROBE_LIVENESS_INITIAL_DELAY_SECONDS="15"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
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
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]]
  [[ "$manifest" == *"podAntiAffinity:"* ]]
}

@test "affinity strategy none omits affinity block" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="none"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"affinity:"* ]]
}

@test "affinity strategy spread-nodes generates node spread" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="spread-nodes"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]]
  [[ "$manifest" == *"topologyKey: kubernetes.io/hostname"* ]]
}

@test "affinity strategy colocate-app generates pod affinity" {
  export KUBERNETES_WORKLOAD_AFFINITY_STRATEGY="colocate-app"
  export COLOCATE_WITH_APP="database"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"affinity:"* ]]
  [[ "$manifest" == *"podAffinity:"* ]]
}

# =============================================================================
# Ports (optional, disabled by default)
# =============================================================================

@test "ports disabled by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"ports:"* ]]
  [[ "$manifest" != *"containerPort:"* ]]
}

@test "enables ports when requested" {
  export KUBERNETES_CRONJOB_PORTS_ENABLED="true"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"ports:"* ]]
  [[ "$manifest" == *"containerPort:"* ]]
}

@test "ports use workload container port setting" {
  export KUBERNETES_CRONJOB_PORTS_ENABLED="true"
  export KUBERNETES_WORKLOAD_CONTAINER_PORT="9090"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"containerPort: 9090"* ]]
}

# =============================================================================
# Lifecycle hooks (optional)
# =============================================================================

@test "lifecycle hook omitted by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"lifecycle:"* ]]
  [[ "$manifest" != *"preStop:"* ]]
}

@test "includes lifecycle hook when prestop command set" {
  export KUBERNETES_WORKLOAD_PRESTOP_COMMAND="echo cleanup"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
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
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"nodeSelector:"* ]]
}

@test "includes node selector when set" {
  export KUBERNETES_WORKLOAD_NODE_SELECTOR="disktype=ssd"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"nodeSelector:"* ]]
  [[ "$manifest" == *'disktype: "ssd"'* ]]
}

@test "node selector supports multiple values" {
  export KUBERNETES_WORKLOAD_NODE_SELECTOR="disktype=ssd,zone=us-east-1a"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *'disktype: "ssd"'* ]]
  [[ "$manifest" == *'zone: "us-east-1a"'* ]]
}

# =============================================================================
# DNS policy
# =============================================================================

@test "dns policy omitted by default" {
  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" != *"dnsPolicy:"* ]]
}

@test "includes dns policy when set" {
  export KUBERNETES_WORKLOAD_DNS_POLICY="ClusterFirst"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 0 ]

  manifest=$(read_manifest)
  [[ "$manifest" == *"dnsPolicy: ClusterFirst"* ]]
}

@test "rejects invalid dns policy" {
  export KUBERNETES_WORKLOAD_DNS_POLICY="InvalidPolicy"

  run "$GENERATORS_DIR/generate-kubernetes-workload-cronjob"
  [ "$status" -eq 4 ]
  [[ "$output" == *"must be"* ]]
}
