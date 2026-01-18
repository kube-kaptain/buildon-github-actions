#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# docker-build-shared - Shared code for docker build scripts
#
# Sourced by docker build scripts. Reads from environment:
# User set inputs (validated):
#   DOCKER_TARGET_REGISTRY   - Container registry (required)
#   DOCKER_TARGET_BASE_PATH  - Base path (optional)
# System generated:
#   DOCKER_IMAGE_NAME        - Image name (required)
#   DOCKER_TAG               - Tag for image (required)
#
# Sets these variables after validation:
#   TARGET_REGISTRY, TARGET_BASE_PATH - Cleaned values
#   TARGET_IMAGE_FULL_URI - Assembled full image reference
#
# Provides functions:
#   confirm_target_image_doesnt_exist - Check registry for existing image
#   output_var                        - Output variable for GitHub Actions
#
# Errors/warnings go to stderr using LOG_ERROR_PREFIX/SUFFIX, LOG_WARNING_PREFIX/SUFFIX.

# shellcheck disable=SC2034  # TARGET_IMAGE_FULL_URI used by caller

# Validate required inputs (caller must source docker-build.bash first)
if [[ -z "${DOCKER_TARGET_REGISTRY}" ]]; then
  echo "${LOG_ERROR_PREFIX:-}DOCKER_TARGET_REGISTRY is required${LOG_ERROR_SUFFIX:-}" >&2
  exit 1
fi
if [[ -z "${DOCKER_IMAGE_NAME:-}" ]]; then
  echo "${LOG_ERROR_PREFIX:-}DOCKER_IMAGE_NAME is required${LOG_ERROR_SUFFIX:-}" >&2
  exit 1
fi
if [[ -z "${DOCKER_TAG:-}" ]]; then
  echo "${LOG_ERROR_PREFIX:-}DOCKER_TAG is required${LOG_ERROR_SUFFIX:-}" >&2
  exit 1
fi

# Registry cannot contain slashes
if [[ "${TARGET_REGISTRY}" == */* ]]; then
  echo "${LOG_ERROR_PREFIX:-}DOCKER_TARGET_REGISTRY cannot contain slashes - use DOCKER_TARGET_BASE_PATH for paths${LOG_ERROR_SUFFIX:-}" >&2
  exit 1
fi

# Strip leading/trailing slashes from base path (internal slashes are valid)
TARGET_BASE_PATH="${INPUT_TARGET_BASE_PATH#/}"
TARGET_BASE_PATH="${TARGET_BASE_PATH%/}"
if [[ "${INPUT_TARGET_BASE_PATH}" != "${TARGET_BASE_PATH}" ]]; then
  echo "${LOG_WARNING_PREFIX:-}DOCKER_TARGET_BASE_PATH has leading/trailing slashes. Stripping.${LOG_WARNING_SUFFIX:-}" >&2
fi

# Assemble full image URI
if [[ -n "${TARGET_BASE_PATH}" ]]; then
  TARGET_IMAGE_FULL_URI="${TARGET_REGISTRY}/${TARGET_BASE_PATH}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
else
  TARGET_IMAGE_FULL_URI="${TARGET_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
fi

confirm_target_image_doesnt_exist() {
  if docker manifest inspect "${TARGET_IMAGE_FULL_URI}" &>/dev/null; then
    echo "${LOG_ERROR_PREFIX:-}Target image already exists in registry: ${TARGET_IMAGE_FULL_URI}${LOG_ERROR_SUFFIX:-}" >&2
    return 1
  fi
  echo "Confirmed target image does not exist in registry (safe to build and push)" >&2
  return 0
}

output_var() {
  local name="${1}"
  local value="${2}"

  echo "${name}=${value}"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "${name}=${value}" >> "${GITHUB_OUTPUT}"
  fi
}
