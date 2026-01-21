#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-cronjob.bash - Default values for Kubernetes CronJob generation
#
# Source this file to get consistent defaults for CronJob-related variables.
#
# CronJobs are NOT versioned (unlike Jobs). They run repeatedly on schedule,
# so the name pattern is: ${ProjectName}[-dir][-suffix]
#
# Schedule and suspend are deferred to environment tokens, not build-time values.
#
# Defaults are applied to long-form variables (KUBERNETES_CRONJOB_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Naming and paths
KUBERNETES_CRONJOB_NAME_SUFFIX="${KUBERNETES_CRONJOB_NAME_SUFFIX:-}"
KUBERNETES_CRONJOB_COMBINED_SUB_PATH="${KUBERNETES_CRONJOB_COMBINED_SUB_PATH:-}"

# CronJob scheduling (deferred to environment via tokens)
# These are NOT defaulted - they become tokens for environment-specific values
# KUBERNETES_CRONJOB_SCHEDULE - set at deploy time
# KUBERNETES_CRONJOB_SUSPEND - set at deploy time

# CronJob execution settings
KUBERNETES_CRONJOB_CONCURRENCY_POLICY="${KUBERNETES_CRONJOB_CONCURRENCY_POLICY:-Forbid}"
KUBERNETES_CRONJOB_STARTING_DEADLINE_SECONDS="${KUBERNETES_CRONJOB_STARTING_DEADLINE_SECONDS:-}"

# History limits (for cleanup)
# 1 successful = enough for log collection
# 5 failed = show patterns, make a mess, get attention
KUBERNETES_CRONJOB_SUCCESSFUL_JOBS_HISTORY_LIMIT="${KUBERNETES_CRONJOB_SUCCESSFUL_JOBS_HISTORY_LIMIT:-1}"
KUBERNETES_CRONJOB_FAILED_JOBS_HISTORY_LIMIT="${KUBERNETES_CRONJOB_FAILED_JOBS_HISTORY_LIMIT:-5}"

# Job template settings
KUBERNETES_CRONJOB_BACKOFF_LIMIT="${KUBERNETES_CRONJOB_BACKOFF_LIMIT:-0}"
KUBERNETES_CRONJOB_COMPLETIONS="${KUBERNETES_CRONJOB_COMPLETIONS:-1}"
KUBERNETES_CRONJOB_PARALLELISM="${KUBERNETES_CRONJOB_PARALLELISM:-1}"
KUBERNETES_CRONJOB_ACTIVE_DEADLINE_SECONDS="${KUBERNETES_CRONJOB_ACTIVE_DEADLINE_SECONDS:-}"
# TTL deliberately empty - keep jobs forever, let history limits handle cleanup
KUBERNETES_CRONJOB_TTL_SECONDS_AFTER_FINISHED="${KUBERNETES_CRONJOB_TTL_SECONDS_AFTER_FINISHED:-}"

# Pod restart policy (Never or OnFailure - Jobs cannot use Always)
KUBERNETES_CRONJOB_RESTART_POLICY="${KUBERNETES_CRONJOB_RESTART_POLICY:-Never}"

# Environment source directory (for env vars from files)
KUBERNETES_CRONJOB_ENV_SUB_PATH="${KUBERNETES_CRONJOB_ENV_SUB_PATH:-}"

# Additional labels/annotations
KUBERNETES_CRONJOB_ADDITIONAL_LABELS="${KUBERNETES_CRONJOB_ADDITIONAL_LABELS:-}"
KUBERNETES_CRONJOB_ADDITIONAL_ANNOTATIONS="${KUBERNETES_CRONJOB_ADDITIONAL_ANNOTATIONS:-}"

# Ports (disabled by default for batch workloads)
KUBERNETES_CRONJOB_PORTS_ENABLED="${KUBERNETES_CRONJOB_PORTS_ENABLED:-false}"

# Probes (disabled by default for batch workloads, uses workload settings when enabled)
KUBERNETES_CRONJOB_LIVENESS_PROBE_ENABLED="${KUBERNETES_CRONJOB_LIVENESS_PROBE_ENABLED:-false}"
KUBERNETES_CRONJOB_READINESS_PROBE_ENABLED="${KUBERNETES_CRONJOB_READINESS_PROBE_ENABLED:-false}"
KUBERNETES_CRONJOB_STARTUP_PROBE_ENABLED="${KUBERNETES_CRONJOB_STARTUP_PROBE_ENABLED:-false}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Naming and paths
NAME_SUFFIX="${KUBERNETES_CRONJOB_NAME_SUFFIX}"
COMBINED_SUB_PATH="${KUBERNETES_CRONJOB_COMBINED_SUB_PATH}"

# CronJob execution settings
CONCURRENCY_POLICY="${KUBERNETES_CRONJOB_CONCURRENCY_POLICY}"
STARTING_DEADLINE_SECONDS="${KUBERNETES_CRONJOB_STARTING_DEADLINE_SECONDS}"

# History limits
SUCCESSFUL_JOBS_HISTORY_LIMIT="${KUBERNETES_CRONJOB_SUCCESSFUL_JOBS_HISTORY_LIMIT}"
FAILED_JOBS_HISTORY_LIMIT="${KUBERNETES_CRONJOB_FAILED_JOBS_HISTORY_LIMIT}"

# Job template settings
BACKOFF_LIMIT="${KUBERNETES_CRONJOB_BACKOFF_LIMIT}"
COMPLETIONS="${KUBERNETES_CRONJOB_COMPLETIONS}"
PARALLELISM="${KUBERNETES_CRONJOB_PARALLELISM}"
ACTIVE_DEADLINE_SECONDS="${KUBERNETES_CRONJOB_ACTIVE_DEADLINE_SECONDS}"
TTL_SECONDS_AFTER_FINISHED="${KUBERNETES_CRONJOB_TTL_SECONDS_AFTER_FINISHED}"

# Pod settings
RESTART_POLICY="${KUBERNETES_CRONJOB_RESTART_POLICY}"

# Environment source
BASE_ENV_SUB_PATH="${KUBERNETES_CRONJOB_ENV_SUB_PATH}"

# Additional labels/annotations
SPECIFIC_LABELS="${KUBERNETES_CRONJOB_ADDITIONAL_LABELS}"
SPECIFIC_ANNOTATIONS="${KUBERNETES_CRONJOB_ADDITIONAL_ANNOTATIONS}"

# Ports
CRONJOB_PORTS_ENABLED="${KUBERNETES_CRONJOB_PORTS_ENABLED}"

# Probes
CRONJOB_LIVENESS_PROBE_ENABLED="${KUBERNETES_CRONJOB_LIVENESS_PROBE_ENABLED}"
CRONJOB_READINESS_PROBE_ENABLED="${KUBERNETES_CRONJOB_READINESS_PROBE_ENABLED}"
CRONJOB_STARTUP_PROBE_ENABLED="${KUBERNETES_CRONJOB_STARTUP_PROBE_ENABLED}"
