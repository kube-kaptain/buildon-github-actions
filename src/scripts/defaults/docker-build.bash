#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Docker build target defaults
#
# Defaults are applied to long-form variables (DOCKER_TARGET_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

# Docker registry logins
DOCKER_REGISTRY_LOGINS="${DOCKER_REGISTRY_LOGINS:-}"

# Docker target config
DOCKER_TARGET_REGISTRY="${DOCKER_TARGET_REGISTRY:-}"
DOCKER_TARGET_NAMESPACE="${DOCKER_TARGET_NAMESPACE:-}"

# Docker push targets
DOCKER_PUSH_TARGETS="${DOCKER_PUSH_TARGETS:-}"

# =============================================================================
# Convenience short names (for single-purpose scripts only)
# =============================================================================

TARGET_REGISTRY="${DOCKER_TARGET_REGISTRY}"
TARGET_NAMESPACE="${DOCKER_TARGET_NAMESPACE}"

# =============================================================================
# Validation and URI assembly
# =============================================================================
# Callers that don't have target vars (e.g. basic-quality-checks workflow)
# set SKIP_DOCKER_TARGET_VALIDATION=true before sourcing this file.

if [[ "${SKIP_DOCKER_TARGET_VALIDATION:-}" != "true" ]]; then
  if [[ -z "${DOCKER_TARGET_REGISTRY}" ]]; then
    log_error "DOCKER_TARGET_REGISTRY is required"
    exit 1
  fi
  if [[ -z "${DOCKER_IMAGE_NAME:-}" ]]; then
    log_error "DOCKER_IMAGE_NAME is required"
    exit 1
  fi
  if [[ -z "${DOCKER_TAG:-}" ]]; then
    log_error "DOCKER_TAG is required"
    exit 1
  fi

  # Registry cannot contain slashes
  if [[ "${TARGET_REGISTRY}" == */* ]]; then
    log_error "DOCKER_TARGET_REGISTRY cannot contain slashes - use DOCKER_TARGET_NAMESPACE for paths"
    exit 1
  fi

  # Namespace cannot have leading/trailing slashes
  if [[ -n "${DOCKER_TARGET_NAMESPACE}" ]]; then
    if [[ "${DOCKER_TARGET_NAMESPACE}" == /* || "${DOCKER_TARGET_NAMESPACE}" == */ ]]; then
      log_error "DOCKER_TARGET_NAMESPACE cannot have leading or trailing slashes"
      exit 1
    fi
  fi

  # Assemble full image URI
  if [[ -n "${TARGET_NAMESPACE}" ]]; then
    TARGET_IMAGE_FULL_URI="${TARGET_REGISTRY}/${TARGET_NAMESPACE}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
  else
    TARGET_IMAGE_FULL_URI="${TARGET_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
  fi
fi
