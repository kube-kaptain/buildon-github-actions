#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Token formatting library - name conversion and reference formatting
#
# Functions:
#   is_valid_token_name_style        - Check if name style is valid
#   is_valid_substitution_token_style - Check if substitution style is valid
#   convert_token_name               - Convert UPPER_SNAKE to target name style
#   convert_kebab_name               - Convert lower-kebab to target name style
#   format_token_reference           - Wrap name with substitution delimiters
#   format_canonical_token           - Convenience combining both
#   format_project_suffixed_token    - Combine project name + suffix into delimited token
#   validate_token_styles            - Validate both styles and exit on error

# Internal: lowercase a string (bash 3.2 compatible)
_lowercase() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Internal: uppercase first char, lowercase rest (bash 3.2 compatible)
_capitalize() {
  local word="$1"
  local first rest
  first=$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')
  rest=$(_lowercase "${word:1}")
  echo "${first}${rest}"
}

# Check if a token name style is valid
# Usage: is_valid_token_name_style <style>
# Returns: 0 if valid, 1 if invalid
is_valid_token_name_style() {
  if [[ $# -ne 1 ]]; then
    echo "Error: is_valid_token_name_style requires exactly 1 argument, got $#" >&2
    return 1
  fi
  case "${1:-}" in
    PascalCase|camelCase|UPPER_SNAKE|lower_snake|lower-kebab|UPPER-KEBAB|lower.dot|UPPER.DOT)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Check if a substitution token style is valid
# Usage: is_valid_substitution_token_style <style>
# Returns: 0 if valid, 1 if invalid
is_valid_substitution_token_style() {
  if [[ $# -ne 1 ]]; then
    echo "Error: is_valid_substitution_token_style requires exactly 1 argument, got $#" >&2
    return 1
  fi
  case "${1:-}" in
    shell|mustache|helm|erb|github-actions|blade|stringtemplate|ognl|t4|swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Validate both token styles and exit on error
# Usage: validate_token_styles
# Reads from caller's scope: TOKEN_NAME_STYLE, TOKEN_DELIMITER_STYLE
# Also uses: LOG_ERROR_PREFIX, LOG_ERROR_SUFFIX (optional)
# Exits: 2 for invalid name style, 3 for invalid delimiter style
validate_token_styles() {
  if ! is_valid_token_name_style "${TOKEN_NAME_STYLE:-}"; then
    echo "${LOG_ERROR_PREFIX:-}Unknown token name style: ${TOKEN_NAME_STYLE:-}${LOG_ERROR_SUFFIX:-}" >&2
    exit 2
  fi

  if ! is_valid_substitution_token_style "${TOKEN_DELIMITER_STYLE:-}"; then
    echo "${LOG_ERROR_PREFIX:-}Unknown substitution token style: ${TOKEN_DELIMITER_STYLE:-}${LOG_ERROR_SUFFIX:-}" >&2
    exit 3
  fi
}

# Convert UPPER_SNAKE_CASE name to target style
# Usage: convert_token_name <style> <UPPER_SNAKE_NAME>
# Styles: PascalCase, camelCase, UPPER_SNAKE, lower_snake, lower-kebab, UPPER-KEBAB, lower.dot, UPPER.DOT
convert_token_name() {
  if [[ $# -ne 2 ]]; then
    echo "Error: convert_token_name requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local style="${1:-}"
  local name="${2:-}"

  # Validate inputs
  if [[ -z "${style}" ]]; then
    echo "Error: name style is required" >&2
    return 1
  fi
  if [[ -z "${name}" || "${name}" =~ ^[[:space:]]+$ ]]; then
    echo "Error: canonical name is required and cannot be whitespace-only" >&2
    return 1
  fi

  case "${style}" in
    PascalCase)
      _to_pascal_case "${name}"
      ;;
    camelCase)
      _to_camel_case "${name}"
      ;;
    UPPER_SNAKE)
      echo "${name}"
      ;;
    lower_snake)
      _lowercase "${name}"
      ;;
    lower-kebab)
      _lowercase "${name}" | tr '_' '-'
      ;;
    UPPER-KEBAB)
      echo "${name}" | tr '_' '-'
      ;;
    lower.dot)
      _lowercase "${name}" | tr '_' '.'
      ;;
    UPPER.DOT)
      echo "${name}" | tr '_' '.'
      ;;
    *)
      echo "Error: Unknown name style: ${style}" >&2
      return 1
      ;;
  esac
}

# Format a name with substitution delimiters
# Usage: format_token_reference <style> <name>
# Styles: shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift
format_token_reference() {
  if [[ $# -ne 2 ]]; then
    echo "Error: format_token_reference requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local style="${1:-}"
  local name="${2:-}"

  # Validate inputs
  if [[ -z "${style}" ]]; then
    echo "Error: substitution style is required" >&2
    return 1
  fi
  if [[ -z "${name}" ]]; then
    echo "Error: name is required" >&2
    return 1
  fi

  case "${style}" in
    shell)
      echo "\${${name}}"
      ;;
    mustache)
      echo "{{ ${name} }}"
      ;;
    helm)
      echo "{{ .Values.${name} }}"
      ;;
    erb)
      echo "<%= ${name} %>"
      ;;
    github-actions)
      echo "\${{ ${name} }}"
      ;;
    blade)
      echo "{{ \$${name} }}"
      ;;
    stringtemplate)
      echo "\$${name}\$"
      ;;
    ognl)
      echo "%{${name}}"
      ;;
    t4)
      echo "<#= ${name} #>"
      ;;
    swift)
      echo "\\(${name})"
      ;;
    *)
      echo "Error: Unknown substitution style: ${style}" >&2
      return 1
      ;;
  esac
}

# Convenience: convert name and wrap with delimiters
# Usage: format_canonical_token <substitution-style> <name-style> <UPPER_SNAKE_NAME>
format_canonical_token() {
  if [[ $# -ne 3 ]]; then
    echo "Error: format_canonical_token requires exactly 3 arguments, got $#" >&2
    return 1
  fi

  local subst_style="${1:-}"
  local name_style="${2:-}"
  local canonical_name="${3:-}"

  # Validate inputs
  if [[ -z "${subst_style}" ]]; then
    echo "Error: substitution style is required" >&2
    return 1
  fi
  if [[ -z "${name_style}" ]]; then
    echo "Error: name style is required" >&2
    return 1
  fi
  if [[ -z "${canonical_name}" ]]; then
    echo "Error: canonical name is required" >&2
    return 1
  fi

  local converted_name
  converted_name=$(convert_token_name "${name_style}" "${canonical_name}") || return 1
  format_token_reference "${subst_style}" "${converted_name}"
}

# Convert lower-kebab-case name to target style
# Usage: convert_kebab_name <style> <lower-kebab-name>
# Converts repo-style names (my-cool-project) to any supported style
# Example: convert_kebab_name "PascalCase" "my-cool-project" → "MyCoolProject"
convert_kebab_name() {
  if [[ $# -ne 2 ]]; then
    echo "Error: convert_kebab_name requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local style="${1:-}"
  local kebab_name="${2:-}"

  # Validate inputs
  if [[ -z "${style}" ]]; then
    echo "Error: name style is required" >&2
    return 1
  fi
  if [[ -z "${kebab_name}" || "${kebab_name}" =~ ^[[:space:]]+$ ]]; then
    echo "Error: kebab name is required and cannot be whitespace-only" >&2
    return 1
  fi

  # Convert lower-kebab to UPPER_SNAKE, then use existing converter
  local upper_snake
  upper_snake=$(echo "${kebab_name}" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
  convert_token_name "${style}" "${upper_snake}"
}

# Combine project name with suffix into a formatted, delimited token
# Usage: format_project_suffixed_token <delimiter-style> <name-style> <project-name-kebab> <SUFFIX_UPPER_SNAKE>
# Useful for creating compound tokens like ${MyProjectAffinityColocateApp}
# Example: format_project_suffixed_token "shell" "PascalCase" "my-project" "AFFINITY_COLOCATE_APP"
#          Returns: ${MyProjectAffinityColocateApp}
format_project_suffixed_token() {
  if [[ $# -ne 4 ]]; then
    echo "Error: format_project_suffixed_token requires exactly 4 arguments, got $#" >&2
    return 1
  fi

  local delim_style="${1:-}"
  local name_style="${2:-}"
  local project_kebab="${3:-}"
  local suffix_upper_snake="${4:-}"

  # Validate inputs
  if [[ -z "${delim_style}" ]]; then
    echo "Error: delimiter style is required" >&2
    return 1
  fi
  if [[ -z "${name_style}" ]]; then
    echo "Error: name style is required" >&2
    return 1
  fi
  if [[ -z "${project_kebab}" ]]; then
    echo "Error: project name (kebab) is required" >&2
    return 1
  fi
  if [[ -z "${suffix_upper_snake}" ]]; then
    echo "Error: suffix (UPPER_SNAKE) is required" >&2
    return 1
  fi

  local project_converted suffix_converted combined
  project_converted=$(convert_kebab_name "${name_style}" "${project_kebab}") || return 1
  # Suffix is always PascalCase when joining - ensures proper compound identifier
  # e.g., myProject + AffinityColocateApp = myProjectAffinityColocateApp
  suffix_converted=$(convert_token_name "PascalCase" "${suffix_upper_snake}") || return 1
  combined="${project_converted}${suffix_converted}"

  format_token_reference "${delim_style}" "${combined}"
}

# Internal: Convert UPPER_SNAKE to PascalCase
_to_pascal_case() {
  local input="$1"
  local result=""
  local IFS='_'
  local word

  for word in ${input}; do
    if [[ -n "${word}" ]]; then
      result+=$(_capitalize "${word}")
    fi
  done

  echo "${result}"
}

# Internal: Convert UPPER_SNAKE to camelCase
_to_camel_case() {
  local input="$1"
  local result=""
  local IFS='_'
  local word
  local first=true

  for word in ${input}; do
    if [[ -n "${word}" ]]; then
      if ${first}; then
        # First word: all lowercase
        result+=$(_lowercase "${word}")
        first=false
      else
        # Subsequent words: capitalize first letter, lowercase rest
        result+=$(_capitalize "${word}")
      fi
    fi
  done

  echo "${result}"
}
