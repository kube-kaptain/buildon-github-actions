#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kaptain contributors (Fred Cooke)
#
# docker-target.bash - Defaults for spec.main.docker YAML settings
#
# Single-sourced so kaptain-init and load-final-kaptainpm-yaml cannot drift:
# both read these settings independently (init from the project file before
# layers exist, load from the merged final) and MUST interpret absence
# identically - for targetIncludeNamespace a disagreement would mean layer
# resolution and the rest of the build using different namespaces.
#
# NOT env-overridable (unlike the rest of defaults/) - these mirror the
# documented schema defaults, and a platform override would silently
# contradict the published schema contract.
#
# shellcheck disable=SC2034  # Consumed by sourcing scripts

DOCKER_TARGET_INCLUDE_NAMESPACE_DEFAULT="true"
DOCKER_TARGET_ALLOW_NO_REGISTRY_DEFAULT="false"
