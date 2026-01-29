#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Dockerfile build defaults
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# shellcheck disable=SC2154 # OUTPUT_SUB_PATH set by output-sub-path.bash before sourcing
DOCKERFILE_SUB_PATH="${DOCKERFILE_SUB_PATH:-src/docker}"
DOCKERFILE_SQUASH="${DOCKERFILE_SQUASH:-true}"
DOCKERFILE_NO_CACHE="${DOCKERFILE_NO_CACHE:-true}"
DOCKERFILE_SUBSTITUTION_FILES="${DOCKERFILE_SUBSTITUTION_FILES:-Dockerfile}"
DOCKERFILE_SQUASH_ALLOW_UNAVAILABLE="${DOCKERFILE_SQUASH_ALLOW_UNAVAILABLE:-false}"
DOCKER_CONTEXT_SUB_PATH="${OUTPUT_SUB_PATH}/docker/substituted"
