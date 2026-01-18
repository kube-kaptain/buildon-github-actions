#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Hook-specific defaults that don't belong in shared defaults files
# These are pass-through vars only needed by hooks, not by the scripts they call
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Docker config (defaults come from workflow/action layer)
DOCKER_TARGET_REGISTRY="${DOCKER_TARGET_REGISTRY:-}"
DOCKER_TARGET_BASE_PATH="${DOCKER_TARGET_BASE_PATH:-}"
DOCKER_REGISTRY_LOGINS="${DOCKER_REGISTRY_LOGINS:-}"
DOCKER_PUSH_TARGETS="${DOCKER_PUSH_TARGETS:-}"

# Manifests packaging
MANIFESTS_REPO_PROVIDER_TYPE="${MANIFESTS_REPO_PROVIDER_TYPE:-}"
MANIFESTS_PACKAGING_BASE_IMAGE="${MANIFESTS_PACKAGING_BASE_IMAGE:-}"

# Release branches
RELEASE_BRANCH="${RELEASE_BRANCH:-}"
ADDITIONAL_RELEASE_BRANCHES="${ADDITIONAL_RELEASE_BRANCHES:-}"
