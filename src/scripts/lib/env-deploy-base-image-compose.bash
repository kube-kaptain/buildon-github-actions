# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# env-deploy-base-image-compose.bash: compose the env deploy base image
# reference used as FROM in the env image's Dockerfile.
#
# Format: '<registry>/[<namespace>/]image/image-environment-deploy-<family>:<version>'
#
# Inputs (positional; usually the ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_* vars):
#   $1 registry   - required, e.g. ghcr.io
#   $2 namespace  - optional; empty omits the segment
#   $3 family     - required
#   $4 version    - required
#
# Version: '<deploy-scripts-version>.<kube-major>.<kube-minor>.<patch>', e.g.
# 1.0.14.1.35.1. The Kubernetes segments pick a kubectl matching the cluster;
# patch moves for image rebuilds.
#
# Families (tags list available versions):
#   * trixie-slim: https://github.com/kube-kaptain/image-environment-deploy-trixie-slim/tags
#
# Returns non-zero on invalid input so the caller decides how to fail.
#
# Requires: log.bash sourced by the caller.

env_deploy_base_image_compose() {
  local registry="${1:-}"
  local namespace="${2:-}"
  local family="${3:-}"
  local version="${4:-}"

  if [[ -z "${registry}" ]]; then
    log_error "env_deploy_base_image_compose: registry is required"
    return 1
  fi
  if [[ -z "${family}" ]]; then
    log_error "env_deploy_base_image_compose: family is required"
    return 1
  fi
  if [[ -z "${version}" ]]; then
    log_error "env_deploy_base_image_compose: version is required"
    return 1
  fi
  if [[ "${registry}" == */* ]]; then
    log_error "env_deploy_base_image_compose: registry must not contain '/': ${registry}"
    return 1
  fi
  if [[ "${namespace}" == */* ]]; then
    log_error "env_deploy_base_image_compose: namespace must not contain '/': ${namespace}"
    return 1
  fi
  if [[ "${family}" == */* || "${family}" == *:* ]]; then
    log_error "env_deploy_base_image_compose: family must not contain '/' or ':': ${family}"
    return 1
  fi
  if [[ "${version}" == */* || "${version}" == *:* ]]; then
    log_error "env_deploy_base_image_compose: version must not contain '/' or ':': ${version}"
    return 1
  fi

  if [[ -n "${namespace}" ]]; then
    printf '%s/%s/image/image-environment-deploy-%s:%s\n' \
      "${registry}" "${namespace}" "${family}" "${version}"
  else
    printf '%s/image/image-environment-deploy-%s:%s\n' \
      "${registry}" "${family}" "${version}"
  fi
}

# INCLUDE_NAMESPACE=false drops the namespace segment even when a
# namespace (or its default) is set.
# Usage: env_deploy_base_image_configured
# shellcheck disable=SC2154 # ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_* set by defaults/environments.bash
env_deploy_base_image_configured() {
  local namespace=""
  if [[ "${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_INCLUDE_NAMESPACE}" == "true" ]]; then
    namespace="${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_NAMESPACE}"
  fi
  env_deploy_base_image_compose \
    "${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_REGISTRY}" \
    "${namespace}" \
    "${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_FAMILY}" \
    "${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_VERSION}"
}
