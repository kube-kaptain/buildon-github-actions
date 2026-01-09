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
#   format_token_reference           - Wrap name with substitution delimiters
#   format_canonical_token           - Convenience combining both

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
  case "${1:-}" in
    shell|mustache|helm|erb|github-actions|blade|stringtemplate|ognl|t4|swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Convert UPPER_SNAKE_CASE name to target style
# Usage: convert_token_name <style> <UPPER_SNAKE_NAME>
# Styles: PascalCase, camelCase, UPPER_SNAKE, lower_snake, lower-kebab, UPPER-KEBAB, lower.dot, UPPER.DOT
convert_token_name() {
  local style="${1:-}"
  local name="${2:-}"

  # Validate inputs
  if [[ -z "$style" ]]; then
    echo "Error: name style is required" >&2
    return 1
  fi
  if [[ -z "$name" || "$name" =~ ^[[:space:]]+$ ]]; then
    echo "Error: canonical name is required and cannot be whitespace-only" >&2
    return 1
  fi

  case "$style" in
    PascalCase)
      _to_pascal_case "$name"
      ;;
    camelCase)
      _to_camel_case "$name"
      ;;
    UPPER_SNAKE)
      echo "$name"
      ;;
    lower_snake)
      _lowercase "$name"
      ;;
    lower-kebab)
      _lowercase "$name" | tr '_' '-'
      ;;
    UPPER-KEBAB)
      echo "$name" | tr '_' '-'
      ;;
    lower.dot)
      _lowercase "$name" | tr '_' '.'
      ;;
    UPPER.DOT)
      echo "$name" | tr '_' '.'
      ;;
    *)
      echo "Error: Unknown name style: $style" >&2
      return 1
      ;;
  esac
}

# Format a name with substitution delimiters
# Usage: format_token_reference <style> <name>
# Styles: shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift
format_token_reference() {
  local style="${1:-}"
  local name="${2:-}"

  # Validate inputs
  if [[ -z "$style" ]]; then
    echo "Error: substitution style is required" >&2
    return 1
  fi
  if [[ -z "$name" ]]; then
    echo "Error: name is required" >&2
    return 1
  fi

  case "$style" in
    shell)
      echo "\${$name}"
      ;;
    mustache)
      echo "{{ $name }}"
      ;;
    helm)
      echo "{{ .Values.$name }}"
      ;;
    erb)
      echo "<%= $name %>"
      ;;
    github-actions)
      echo "\${{ $name }}"
      ;;
    blade)
      echo "{{ \$$name }}"
      ;;
    stringtemplate)
      echo "\$$name\$"
      ;;
    ognl)
      echo "%{$name}"
      ;;
    t4)
      echo "<#= $name #>"
      ;;
    swift)
      echo "\\($name)"
      ;;
    *)
      echo "Error: Unknown substitution style: $style" >&2
      return 1
      ;;
  esac
}

# Convenience: convert name and wrap with delimiters
# Usage: format_canonical_token <substitution-style> <name-style> <UPPER_SNAKE_NAME>
format_canonical_token() {
  local subst_style="${1:-}"
  local name_style="${2:-}"
  local canonical_name="${3:-}"

  # Validate inputs
  if [[ -z "$subst_style" ]]; then
    echo "Error: substitution style is required" >&2
    return 1
  fi
  if [[ -z "$name_style" ]]; then
    echo "Error: name style is required" >&2
    return 1
  fi
  if [[ -z "$canonical_name" ]]; then
    echo "Error: canonical name is required" >&2
    return 1
  fi

  local converted_name
  converted_name=$(convert_token_name "$name_style" "$canonical_name") || return 1
  format_token_reference "$subst_style" "$converted_name"
}

# Internal: Convert UPPER_SNAKE to PascalCase
_to_pascal_case() {
  local input="$1"
  local result=""
  local IFS='_'
  local word

  for word in $input; do
    if [[ -n "$word" ]]; then
      result+=$(_capitalize "$word")
    fi
  done

  echo "$result"
}

# Internal: Convert UPPER_SNAKE to camelCase
_to_camel_case() {
  local input="$1"
  local result=""
  local IFS='_'
  local word
  local first=true

  for word in $input; do
    if [[ -n "$word" ]]; then
      if $first; then
        # First word: all lowercase
        result+=$(_lowercase "$word")
        first=false
      else
        # Subsequent words: capitalize first letter, lowercase rest
        result+=$(_capitalize "$word")
      fi
    fi
  done

  echo "$result"
}
