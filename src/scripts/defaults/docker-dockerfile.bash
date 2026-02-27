#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Dockerfile build defaults
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# shellcheck disable=SC2154 # OUTPUT_SUB_PATH set by output-sub-path.bash before sourcing
DOCKERFILE_SQUASH="${DOCKERFILE_SQUASH:-squash}"
DOCKERFILE_NO_CACHE="${DOCKERFILE_NO_CACHE:-true}"
DOCKERFILE_SUBSTITUTION_FILES="${DOCKERFILE_SUBSTITUTION_FILES:-Dockerfile}"

# Dirs to potentially source the D file and other files from
DOCKERFILE_SUB_PATH="${DOCKERFILE_SUB_PATH:-src/docker}"
DOCKERFILE_SUB_PATH_LINUX_AMD64="${DOCKERFILE_SUB_PATH_LINUX_AMD64:-src/docker-linux-amd64}"
DOCKERFILE_SUB_PATH_LINUX_ARM64="${DOCKERFILE_SUB_PATH_LINUX_ARM64:-src/docker-linux-arm64}"

# Dirs to dynamically place files into including generated D files
DOCKER_CONTEXT_SUB_PATH="${OUTPUT_SUB_PATH}/docker/substituted"
DOCKER_CONTEXT_SUB_PATH_LINUX_AMD64="${OUTPUT_SUB_PATH}/docker-linux-amd64/substituted"
DOCKER_CONTEXT_SUB_PATH_LINUX_ARM64="${OUTPUT_SUB_PATH}/docker-linux-arm64/substituted"
