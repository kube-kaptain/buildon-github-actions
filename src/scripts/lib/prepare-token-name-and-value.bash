# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# prepare-token-name-and-value.bash - Shared helper for token substitution
#
# Sourced once by substitute-tokens-from-dir. Defines
# prepare_token_name_and_value() which reads a token file and writes
# TOKEN_NAME and TOKEN_VALUE into the caller's scope (the substitute
# provider function declares them as locals so writes land there).
#
# Usage:
#   local TOKEN_NAME TOKEN_VALUE
#   prepare_token_name_and_value "${TOKEN_FILE}"
#
# Arguments:
#   $1 - Path to the token file (relative; the path itself becomes the name)
#
# Environment:
#   CONFIG_VALUE_TRAILING_NEWLINE - How to handle trailing newlines:
#     - strip-for-single-line (default): Strip trailing newline from
#       single-line values only
#     - preserve-all: Keep all trailing newlines exactly as in file
#     - always-strip-one-newline: Always strip exactly one trailing
#       newline if present

# shellcheck disable=SC2034  # TOKEN_NAME and TOKEN_VALUE consumed by sourcing caller

prepare_token_name_and_value() {
  local token_file="${1}"

  if [[ -z "${token_file}" ]]; then
    log_error "prepare_token_name_and_value: token file argument required"
    return 1
  fi

  # Token name is the file path (relative)
  TOKEN_NAME="${token_file}"

  # Read file content preserving trailing newlines exactly.
  # Bash $() strips trailing newlines, so append 'x' as sentinel and
  # remove after. && ensures cat errors propagate.
  local raw_content
  raw_content=$(cat "${token_file}" && echo x)
  raw_content="${raw_content%x}"

  # shellcheck disable=SC2154 # CONFIG_VALUE_TRAILING_NEWLINE set by caller
  if [[ "${CONFIG_VALUE_TRAILING_NEWLINE}" == "preserve-all" ]]; then
    TOKEN_VALUE="${raw_content}"
  elif [[ "${CONFIG_VALUE_TRAILING_NEWLINE}" == "always-strip-one-newline" ]]; then
    TOKEN_VALUE="${raw_content%$'\n'}"
  else
    # Default: strip-for-single-line
    local content_without_final_newline="${raw_content%$'\n'}"
    if [[ "${content_without_final_newline}" == *$'\n'* ]]; then
      # Multi-line: keep as-is (preserve all newlines)
      TOKEN_VALUE="${raw_content}"
    else
      # Single-line: strip trailing newline if present
      TOKEN_VALUE="${raw_content%$'\n'}"
    fi
  fi
}
