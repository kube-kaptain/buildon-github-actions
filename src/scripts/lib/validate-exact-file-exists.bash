#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# validate-filename-case.bash - Case-sensitive filename validation
#
# On case-insensitive filesystems (macOS HFS+/APFS), a file check for
# "KaptainPM.yaml" succeeds even if the actual file is "kaptainpm.yaml". This
# causes confusing failures when the same code runs on Linux and other OSes.
# This function catches the mismatch early with a clear error message.
#
# Validates that a file exists with the exact expected case.
#
# Usage: validate_exact_file_exists <directory> <expected-filename>
validate_exact_file_exists() {
  local dir="${1:?Usage: validate_exact_file_exists <directory> <expected-filename>}"
  local expected="${2:?Usage: validate_exact_file_exists <directory> <expected-filename>}"

  if [[ ! -d "${dir}" ]]; then
    log_error "Directory '${dir}' does not exist"
    return 1
  fi

  local entry basename expected_lower actual_lower
  local match_count=0
  local exact_found=false
  expected_lower=$(printf '%s' "${expected}" | tr '[:upper:]' '[:lower:]')

  for entry in "${dir}"/*; do
    [[ -e "${entry}" ]] || continue
    basename="${entry##*/}"
    actual_lower=$(printf '%s' "${basename}" | tr '[:upper:]' '[:lower:]')
    if [[ "${actual_lower}" = "${expected_lower}" ]]; then
      match_count=$((match_count + 1))
      if [[ "${basename}" = "${expected}" ]]; then
        exact_found=true
      fi
    fi
  done

  if [[ "${match_count}" -eq 0 ]]; then
    log_error "File '${expected}' not found in ${dir}/"
    return 1
  fi

  if [[ "${exact_found}" = "false" ]]; then
    log_error "File '${expected}' not found in ${dir}/ but a case-insensitive match exists (case mismatch)"
    log_error "Rename the file to exactly '${expected}' - Linux file systems are case-sensitive"
    return 1
  fi

  if [[ "${match_count}" -gt 1 ]]; then
    log_error "Multiple files matching '${expected}' with different case in ${dir}/ - remove or rename the duplicates"
    return 1
  fi

  return 0
}

# Returns 0 if any case variant of <expected-filename> exists in <directory>,
# 1 otherwise (including when the directory does not exist). No logging. Used
# for presence detection before calling validate_exact_file_exists for the
# strict check + clear error message.
#
# Usage: file_exists_any_case <directory> <expected-filename>
file_exists_any_case() {
  local dir="${1:?Usage: file_exists_any_case <directory> <expected-filename>}"
  local expected="${2:?Usage: file_exists_any_case <directory> <expected-filename>}"

  [[ -d "${dir}" ]] || return 1

  local entry basename expected_lower actual_lower
  expected_lower=$(printf '%s' "${expected}" | tr '[:upper:]' '[:lower:]')

  for entry in "${dir}"/*; do
    [[ -e "${entry}" ]] || continue
    basename="${entry##*/}"
    actual_lower=$(printf '%s' "${basename}" | tr '[:upper:]' '[:lower:]')
    if [[ "${actual_lower}" = "${expected_lower}" ]]; then
      return 0
    fi
  done

  return 1
}
