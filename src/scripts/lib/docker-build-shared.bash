#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# docker-build-shared - Shared functions for docker build scripts
#
# Provides:
#   confirm_target_image_doesnt_exist <uri> - Check local storage and registry for existing image
#   create_local_manifest_if_supported - Create local multi-arch manifest (podman only)
#
# shellcheck disable=SC2154 # Variables set by callers before sourcing

confirm_target_image_doesnt_exist() {
  local image_uri="${1:?Usage: confirm_target_image_doesnt_exist <image-uri>}"
  if [[ "${BUILD_MODE}" == "local" ]]; then
    log "Skipping existence checks for local build: ${image_uri}"
    return 0
  fi
  # Local storage first: a pulled copy or leftover tag on a build server is
  # an anomaly - never silently re-tag over it. image inspect never pulls,
  # and matches manifest lists too (they register as images).
  if ${IMAGE_BUILD_COMMAND} image inspect "${image_uri}" &>/dev/null; then
    log_error "Target image already exists in local storage: ${image_uri}"
    return 1
  fi
  if ${IMAGE_BUILD_COMMAND} manifest inspect "${image_uri}" &>/dev/null; then
    log_error "Target image already exists in registry: ${image_uri}"
    return 1
  fi
  log "Confirmed target image does not exist locally or in registry: ${image_uri}"
  return 0
}

# Create a local multi-arch manifest list after a multi-platform build.
# Only podman supports this — docker requires images to be pushed first,
# so docker users get a warning and manifests are created during push instead.
#
# The manifest name must be unbound before create: podman refuses a name
# bound to a manifest list OR a plain image ("already associated with
# image"). Local builds clear whichever stale binding holds the name;
# build servers fail loudly - a bound name on a fresh runner is an anomaly
# (remote existence was already checked up front by
# confirm_target_image_doesnt_exist).
create_local_manifest_if_supported() {
  local manifest_uri="${1}"
  if [[ "${IMAGE_BUILD_COMMAND}" == "podman" ]]; then
    log ""
    if [[ "${BUILD_MODE}" == "build_server" ]]; then
      if ${IMAGE_BUILD_COMMAND} manifest exists "${manifest_uri}" &>/dev/null; then
        log_error "Manifest name already bound to a local manifest list on the build server: ${manifest_uri}"
        return 1
      fi
      if ${IMAGE_BUILD_COMMAND} image exists "${manifest_uri}" &>/dev/null; then
        log_error "Manifest name already bound to a local image on the build server: ${manifest_uri}"
        return 1
      fi
    else
      # untag, never rmi: an image carrying other tags must survive.
      # Manifest check first: manifest lists also register as images.
      if ${IMAGE_BUILD_COMMAND} manifest exists "${manifest_uri}" &>/dev/null; then
        log "Removing stale local manifest list before creating: ${manifest_uri}"
        ${IMAGE_BUILD_COMMAND} manifest rm "${manifest_uri}"
      elif ${IMAGE_BUILD_COMMAND} image exists "${manifest_uri}" &>/dev/null; then
        log "Untagging stale local image before creating: ${manifest_uri}"
        ${IMAGE_BUILD_COMMAND} untag "${manifest_uri}"
      fi
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
