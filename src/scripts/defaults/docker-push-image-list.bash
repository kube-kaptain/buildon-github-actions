#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# docker-push-image-list.bash - Requires DOCKER_PUSH_IMAGE_LIST_FILE from docker-registry-logins
#

DOCKER_PUSH_IMAGE_LIST_FILE="${DOCKER_PUSH_IMAGE_LIST_FILE:?DOCKER_PUSH_IMAGE_LIST_FILE is required - set by docker-registry-logins}"
