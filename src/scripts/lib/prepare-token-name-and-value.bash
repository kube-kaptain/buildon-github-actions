# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# prepare-token-name-and-value.bash - Shared helper for token substitution
#
# This script is SOURCED by style-specific substitution scripts.
# It reads a token file and prepares TOKEN_NAME and TOKEN_VALUE for substitution.
#
# Expected variables (set by caller before sourcing):
#   TOKEN_FILE - Path to the token file (relative, becomes token name)
#
# Environment:
#   CONFIG_VALUE_TRAILING_NEWLINE - How to handle trailing newlines:
#     - strip-for-single-line (default): Strip trailing newline from single-line values only
#     - preserve-all: Keep all trailing newlines exactly as in file
#     - always-strip-one-newline: Always strip exactly one trailing newline if present
#
# Sets:
#   TOKEN_NAME  - The token name (same as TOKEN_FILE path)
#   TOKEN_VALUE - The token value with trailing newline handling applied
#

# Validate TOKEN_FILE is set
if [[ -z "${TOKEN_FILE:-}" ]]; then
  echo "${LOG_ERROR_PREFIX:-}TOKEN_FILE must be set before sourcing prepare-token-name-and-value.bash${LOG_ERROR_SUFFIX:-}" >&2
  exit 1
fi

# Token name is the file path (relative)
# shellcheck disable=SC2034 # TOKEN_NAME is used by the sourcing script
TOKEN_NAME="${TOKEN_FILE}"

# Read file content preserving trailing newlines exactly
# Bash $() strips trailing newlines, so append 'x' as sentinel and remove after
# Using && ensures cat errors propagate (with ; the echo would mask failures)
raw_content=$(cat "${TOKEN_FILE}" && echo x)
raw_content="${raw_content%x}"

# Apply trailing newline handling based on CONFIG_VALUE_TRAILING_NEWLINE (from tokens.bash)

# shellcheck disable=SC2034 # TOKEN_VALUE is used by the sourcing script
if [[ "${CONFIG_VALUE_TRAILING_NEWLINE}" == "preserve-all" ]]; then
  TOKEN_VALUE="${raw_content}"
elif [[ "${CONFIG_VALUE_TRAILING_NEWLINE}" == "always-strip-one-newline" ]]; then
  # Strip exactly one trailing newline if present
  TOKEN_VALUE="${raw_content%$'\n'}"
else
  # Default: strip-for-single-line
  # Check if content contains a newline before the final position (multi-line)
  content_without_final_newline="${raw_content%$'\n'}"
  if [[ "${content_without_final_newline}" == *$'\n'* ]]; then
    # Multi-line: keep as-is (preserve all newlines)
    TOKEN_VALUE="${raw_content}"
  else
    # Single-line: strip trailing newline if present
    TOKEN_VALUE="${raw_content%$'\n'}"
  fi
fi
