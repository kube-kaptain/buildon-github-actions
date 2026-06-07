#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# templates-layout.bash - Default for spec.main.manifests.templatesLayout.
#
# flat: imported template manifests are flattened into the additional-manifests
#       drop dir, with the per-bundle lineage CM(s) lifted into the parent's
#       lineage data dir under a bundle-prefixed name.
# hierarchy: imported template manifests stay in per-bundle subdirs under the
#            additional-manifests drop dir, lineage CMs travel inside them.
#
# shellcheck disable=SC2034  # Variable used by sourcing scripts
TEMPLATES_LAYOUT="${TEMPLATES_LAYOUT:-flat}"
