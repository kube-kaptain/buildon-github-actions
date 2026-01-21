#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-job.bash - Default values for Kubernetes Job generation
#
# Source this file to get consistent defaults for Job-related variables.
#
# Jobs are versioned: metadata.name includes ${Version} so each version
# creates a new Job. Combined with job-checksum suffix, config changes
# within a version also trigger new Jobs.
#
# Defaults are applied to long-form variables (KUBERNETES_JOB_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Naming and paths
KUBERNETES_JOB_NAME_SUFFIX="${KUBERNETES_JOB_NAME_SUFFIX:-}"
KUBERNETES_JOB_COMBINED_SUB_PATH="${KUBERNETES_JOB_COMBINED_SUB_PATH:-}"

# Job execution settings
KUBERNETES_JOB_BACKOFF_LIMIT="${KUBERNETES_JOB_BACKOFF_LIMIT:-0}"
KUBERNETES_JOB_COMPLETIONS="${KUBERNETES_JOB_COMPLETIONS:-1}"
KUBERNETES_JOB_PARALLELISM="${KUBERNETES_JOB_PARALLELISM:-1}"
KUBERNETES_JOB_ACTIVE_DEADLINE_SECONDS="${KUBERNETES_JOB_ACTIVE_DEADLINE_SECONDS:-}"
KUBERNETES_JOB_TTL_SECONDS_AFTER_FINISHED="${KUBERNETES_JOB_TTL_SECONDS_AFTER_FINISHED:-86400}"

# Pod restart policy (Never or OnFailure - Jobs cannot use Always)
KUBERNETES_JOB_RESTART_POLICY="${KUBERNETES_JOB_RESTART_POLICY:-Never}"

# Environment source directory (for env vars from files)
KUBERNETES_JOB_ENV_SUB_PATH="${KUBERNETES_JOB_ENV_SUB_PATH:-}"

# Additional labels/annotations
KUBERNETES_JOB_ADDITIONAL_LABELS="${KUBERNETES_JOB_ADDITIONAL_LABELS:-}"
KUBERNETES_JOB_ADDITIONAL_ANNOTATIONS="${KUBERNETES_JOB_ADDITIONAL_ANNOTATIONS:-}"

# Ports (disabled by default for batch workloads)
KUBERNETES_JOB_PORTS_ENABLED="${KUBERNETES_JOB_PORTS_ENABLED:-false}"

# Probes (disabled by default for batch workloads, uses workload settings when enabled)
KUBERNETES_JOB_LIVENESS_PROBE_ENABLED="${KUBERNETES_JOB_LIVENESS_PROBE_ENABLED:-false}"
KUBERNETES_JOB_READINESS_PROBE_ENABLED="${KUBERNETES_JOB_READINESS_PROBE_ENABLED:-false}"
KUBERNETES_JOB_STARTUP_PROBE_ENABLED="${KUBERNETES_JOB_STARTUP_PROBE_ENABLED:-false}"

# =============================================================================
# Convenience short names (for single-purpose generator scripts only)
# =============================================================================

# Naming and paths
NAME_SUFFIX="${KUBERNETES_JOB_NAME_SUFFIX}"
COMBINED_SUB_PATH="${KUBERNETES_JOB_COMBINED_SUB_PATH}"

# Job execution settings
BACKOFF_LIMIT="${KUBERNETES_JOB_BACKOFF_LIMIT}"
COMPLETIONS="${KUBERNETES_JOB_COMPLETIONS}"
PARALLELISM="${KUBERNETES_JOB_PARALLELISM}"
ACTIVE_DEADLINE_SECONDS="${KUBERNETES_JOB_ACTIVE_DEADLINE_SECONDS}"
TTL_SECONDS_AFTER_FINISHED="${KUBERNETES_JOB_TTL_SECONDS_AFTER_FINISHED}"

# Pod settings
RESTART_POLICY="${KUBERNETES_JOB_RESTART_POLICY}"

# Environment source
BASE_ENV_SUB_PATH="${KUBERNETES_JOB_ENV_SUB_PATH}"

# Additional labels/annotations
SPECIFIC_LABELS="${KUBERNETES_JOB_ADDITIONAL_LABELS}"
SPECIFIC_ANNOTATIONS="${KUBERNETES_JOB_ADDITIONAL_ANNOTATIONS}"

# Ports
JOB_PORTS_ENABLED="${KUBERNETES_JOB_PORTS_ENABLED}"

# Probes
JOB_LIVENESS_PROBE_ENABLED="${KUBERNETES_JOB_LIVENESS_PROBE_ENABLED}"
JOB_READINESS_PROBE_ENABLED="${KUBERNETES_JOB_READINESS_PROBE_ENABLED}"
JOB_STARTUP_PROBE_ENABLED="${KUBERNETES_JOB_STARTUP_PROBE_ENABLED}"
