#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# docker-build-shared - Shared functions for docker build scripts
#
# Provides:
#   confirm_target_image_doesnt_exist <uri> - Check registry for existing image
#   create_local_manifest_if_supported - Create local multi-arch manifest (podman only)
#
# shellcheck disable=SC2154 # Variables set by callers before sourcing

confirm_target_image_doesnt_exist() {
  local image_uri="${1:?Usage: confirm_target_image_doesnt_exist <image-uri>}"
  if [[ "${BUILD_MODE}" == "local" ]]; then
    log "Skipping registry existence check for local build: ${image_uri}"
    return 0
  fi
  if ${IMAGE_BUILD_COMMAND} manifest inspect "${image_uri}" &>/dev/null; then
    log_error "Target image already exists in registry: ${image_uri}"
    return 1
  fi
  log "Confirmed target image does not exist in registry: ${image_uri}"
  return 0
}

# Create a local multi-arch manifest list after a multi-platform build.
# Only podman supports this — docker requires images to be pushed first,
# so docker users get a warning and manifests are created during push instead.
create_local_manifest_if_supported() {
  local manifest_uri="${1}"
  if [[ "${IMAGE_BUILD_COMMAND}" == "podman" ]]; then
    log ""
    # Local builds may re-run without a clean context — remove stale manifest
    if [[ "${BUILD_MODE:-local}" != "build_server" ]]; then
      log "Removing existing manifest before creating for local build: ${manifest_uri}"
      ${IMAGE_BUILD_COMMAND} manifest rm "${manifest_uri}" &>/dev/null || true
    fi
    log "Creating local manifest: ${manifest_uri}"
    if ${IMAGE_BUILD_COMMAND} manifest create "${manifest_uri}" \
        "containers-storage:${manifest_uri}-linux-amd64" \
        "containers-storage:${manifest_uri}-linux-arm64"; then
      log "Local multi-arch manifest created."
    else
      log_error "Failed to create local manifest for multi arch build, bailing."
      return 1
    fi
  else
    log ""
    log_warning "Docker cannot create local multi-arch manifests without also pushing!"
    log_warning "Only per-platform images are available. Switch to podman, for full builds."
    log_warning "Docker is dead. No --squash, no local multi arch builds, no reason to keep."
  fi
}
