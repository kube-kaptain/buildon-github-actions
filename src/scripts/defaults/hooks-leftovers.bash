#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Hook-specific defaults that don't belong in shared defaults files
# These are pass-through vars only needed by hooks, not by the scripts they call
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Manifests packaging
MANIFESTS_REPO_PROVIDER_TYPE="${MANIFESTS_REPO_PROVIDER_TYPE:-}"
MANIFESTS_PACKAGING_BASE_IMAGE="${MANIFESTS_PACKAGING_BASE_IMAGE:-}"
