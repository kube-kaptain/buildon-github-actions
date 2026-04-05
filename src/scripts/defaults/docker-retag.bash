#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Docker source image configuration
#
# Defaults are applied to long-form variables (DOCKER_SOURCE_*) which are
# unique and safe to use when multiple defaults files are sourced together.
# Short names are provided as convenience aliases for single-purpose scripts.
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# =============================================================================
# Apply defaults to long-form variables (collision-safe)
# =============================================================================

DOCKER_SOURCE_REGISTRY="${DOCKER_SOURCE_REGISTRY:-}"
DOCKER_SOURCE_NAMESPACE="${DOCKER_SOURCE_NAMESPACE:-}"
DOCKER_SOURCE_IMAGE_NAME="${DOCKER_SOURCE_IMAGE_NAME:-}"
DOCKER_SOURCE_TAG="${DOCKER_SOURCE_TAG:-}"

# =============================================================================
# Convenience short names (for single-purpose scripts only)
# =============================================================================

SOURCE_REGISTRY="${DOCKER_SOURCE_REGISTRY}"
SOURCE_NAMESPACE="${DOCKER_SOURCE_NAMESPACE}"
SOURCE_IMAGE_NAME="${DOCKER_SOURCE_IMAGE_NAME}"
SOURCE_TAG="${DOCKER_SOURCE_TAG}"

# =============================================================================
# Validation and URI assembly
# =============================================================================
# Only the retag workflow uses these vars. All other workflows set
# SKIP_RETAG_SOURCE_VALIDATION=true before sourcing this file.

if [[ "${SKIP_RETAG_SOURCE_VALIDATION:-}" != "true" ]]; then
  if [[ -z "${DOCKER_SOURCE_REGISTRY}" ]]; then
    log_error "DOCKER_SOURCE_REGISTRY is required"
    exit 1
  fi
  if [[ -z "${DOCKER_SOURCE_IMAGE_NAME}" ]]; then
    log_error "DOCKER_SOURCE_IMAGE_NAME is required"
    exit 1
  fi
  if [[ -z "${DOCKER_SOURCE_TAG}" ]]; then
    log_error "DOCKER_SOURCE_TAG is required"
    exit 1
  fi

  # Registry cannot contain slashes
  if [[ "${SOURCE_REGISTRY}" == */* ]]; then
    log_error "DOCKER_SOURCE_REGISTRY cannot contain slashes - use DOCKER_SOURCE_NAMESPACE for paths"
    exit 1
  fi

  # Image name cannot have leading/trailing slashes
  if [[ -n "${SOURCE_IMAGE_NAME}" ]]; then
    if [[ "${SOURCE_IMAGE_NAME}" == /* || "${SOURCE_IMAGE_NAME}" == */ ]]; then
      log_error "DOCKER_SOURCE_IMAGE_NAME cannot have leading or trailing slashes"
      exit 1
    fi
  fi

  # Namespace cannot have leading/trailing slashes
  if [[ -n "${SOURCE_NAMESPACE}" ]]; then
    if [[ "${SOURCE_NAMESPACE}" == /* || "${SOURCE_NAMESPACE}" == */ ]]; then
      log_error "DOCKER_SOURCE_NAMESPACE cannot have leading or trailing slashes"
      exit 1
    fi
  fi

  # Assemble source image URI
  if [[ -n "${SOURCE_NAMESPACE}" ]]; then
    SOURCE_IMAGE_FULL_URI="${SOURCE_REGISTRY}/${SOURCE_NAMESPACE}/${SOURCE_IMAGE_NAME}:${SOURCE_TAG}"
  else
    SOURCE_IMAGE_FULL_URI="${SOURCE_REGISTRY}/${SOURCE_IMAGE_NAME}:${SOURCE_TAG}"
  fi
fi
