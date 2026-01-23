#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# build-mode.bash - Default for build mode (local vs build_server)
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

BUILD_MODE="${BUILD_MODE:-local}"
