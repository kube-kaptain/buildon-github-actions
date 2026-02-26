#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# docker-build-shared - Shared code for docker build scripts
#
# Sourced by docker build scripts. Reads from environment:
# User set inputs (validated):
#   DOCKER_TARGET_REGISTRY   - Container registry (required)
#   DOCKER_TARGET_NAMESPACE  - Namespace (optional)
# System generated:
#   DOCKER_IMAGE_NAME        - Image name (required)
#   DOCKER_TAG               - Tag for image (required)
#
# Sets these variables after validation:
#   TARGET_REGISTRY, TARGET_NAMESPACE - Cleaned values
#   TARGET_IMAGE_FULL_URI - Assembled full image reference
#
# Provides functions:
#   confirm_target_image_doesnt_exist - Check registry for existing image
#
# Errors/warnings go to stderr using log_error/log_warning functions.

# shellcheck disable=SC2034  # TARGET_IMAGE_FULL_URI used by caller
# shellcheck disable=SC2154 # TARGET_REGISTRY, INPUT_TARGET_NAMESPACE set by docker-build.bash before sourcing

# Validate required inputs (caller must source docker-build.bash first)
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

# Strip leading/trailing slashes from namespace (internal slashes are valid)
TARGET_NAMESPACE="${INPUT_TARGET_NAMESPACE#/}"
TARGET_NAMESPACE="${TARGET_NAMESPACE%/}"
if [[ "${INPUT_TARGET_NAMESPACE}" != "${TARGET_NAMESPACE}" ]]; then
  log_warning "DOCKER_TARGET_NAMESPACE has leading/trailing slashes. Stripping."
fi

# Assemble full image URI
if [[ -n "${TARGET_NAMESPACE}" ]]; then
  TARGET_IMAGE_FULL_URI="${TARGET_REGISTRY}/${TARGET_NAMESPACE}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
else
  TARGET_IMAGE_FULL_URI="${TARGET_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
fi

confirm_target_image_doesnt_exist() {
  if ${IMAGE_BUILD_COMMAND} manifest inspect "${TARGET_IMAGE_FULL_URI}" &>/dev/null; then
    log_error "Target image already exists in registry: ${TARGET_IMAGE_FULL_URI}"
    return 1
  fi
  log "Confirmed target image does not exist in registry (safe to build and push)"
  return 0
}
