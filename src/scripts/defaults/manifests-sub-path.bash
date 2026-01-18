#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# manifests-sub-path.bash - Default for source manifests directory
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

MANIFESTS_SUB_PATH="${MANIFESTS_SUB_PATH:-src/kubernetes}"
