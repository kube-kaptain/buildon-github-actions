#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# tokens.bash - Default values for token substitution configuration
#
# Source this file to get consistent defaults for token-related variables.
# These control how tokens are formatted, validated, and substituted.
#
# Variables are set with defaults only if not already set, so callers can
# override by setting values before sourcing this file.
#

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Token formatting
TOKEN_NAME_STYLE="${TOKEN_NAME_STYLE:-PascalCase}"
TOKEN_DELIMITER_STYLE="${TOKEN_DELIMITER_STYLE:-shell}"

# Token validation
TOKEN_NAME_VALIDATION="${TOKEN_NAME_VALIDATION:-MATCH}"
ALLOW_BUILTIN_TOKEN_OVERRIDE="${ALLOW_BUILTIN_TOKEN_OVERRIDE:-false}"

# Config file handling
CONFIG_SUB_PATH="${CONFIG_SUB_PATH:-src/config}"
CONFIG_VALUE_TRAILING_NEWLINE="${CONFIG_VALUE_TRAILING_NEWLINE:-strip-for-single-line}"
