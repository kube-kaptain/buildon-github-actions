#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# tag-versioning.bash - Default values for tag version calculation
#
# Source this file to get consistent defaults for TAG_VERSION_* variables.
# These control how version tags are calculated and formatted.
#
# Variables are set with defaults only if not already set, so callers can
# override by setting values before sourcing this file.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Maximum number of version parts (e.g., 3 for "1.2.3")
TAG_VERSION_MAX_PARTS="${TAG_VERSION_MAX_PARTS:-3}"

# Strategy for calculating version (plugin name)
TAG_VERSION_CALCULATION_STRATEGY="${TAG_VERSION_CALCULATION_STRATEGY:-git-auto-closest-highest}"

# Pattern type for extracting version from source files
TAG_VERSION_PATTERN_TYPE="${TAG_VERSION_PATTERN_TYPE:-dockerfile-env-kubectl}"

# Number of prefix parts to preserve from source version
TAG_VERSION_PREFIX_PARTS="${TAG_VERSION_PREFIX_PARTS:-}"

# Source file location for version extraction (pattern-match strategy)
TAG_VERSION_SOURCE_SUB_PATH="${TAG_VERSION_SOURCE_SUB_PATH:-}"
TAG_VERSION_SOURCE_FILE_NAME="${TAG_VERSION_SOURCE_FILE_NAME:-}"

# Custom regex pattern for version extraction
TAG_VERSION_SOURCE_CUSTOM_PATTERN="${TAG_VERSION_SOURCE_CUSTOM_PATTERN:-}"
