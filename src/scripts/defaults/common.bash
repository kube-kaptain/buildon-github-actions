#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Common defaults shared across many scripts
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-target}"
MANIFESTS_SUB_PATH="${MANIFESTS_SUB_PATH:-src/kubernetes}"
