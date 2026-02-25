#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# platform.bash - Build platform and log provider defaults
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

BUILD_PLATFORM="${BUILD_PLATFORM:?BUILD_PLATFORM is required}"

BUILD_PLATFORM_LOG_PROVIDER="${BUILD_PLATFORM_LOG_PROVIDER:-stdout}"
