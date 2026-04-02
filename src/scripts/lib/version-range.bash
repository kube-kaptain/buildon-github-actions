#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# version-range.bash - Maven-style version range resolution
#
# Reusable library for resolving version ranges against a set of available versions.
# Sourced by artifact provider plugins that need version range support.
#
# Supports Maven 2/3 range syntax:
#   [1.0,2.0)  - >= 1.0, < 2.0
#   [1.0,2.0]  - >= 1.0, <= 2.0
#   (1.0,2.0)  - > 1.0, < 2.0
#   (1.0,2.0]  - > 1.0, <= 2.0
#   [1.0,)     - >= 1.0 (no upper bound)
#   (1.0,)     - > 1.0 (no upper bound)
#   (,2.0]     - <= 2.0 (no lower bound)
#   (,2.0)     - < 2.0 (no lower bound)
#   1.0        - exact match
#
# Versions are compared numerically part by part (1.10 > 1.9).
# Missing parts are treated as 0 (1.2 == 1.2.0).

# Compare two version strings numerically.
# Returns via exit code: 0 = equal, 1 = v1 > v2, 2 = v1 < v2
version_compare() {
  local v1="${1}" v2="${2}"

  if [[ "${v1}" == "${v2}" ]]; then
    return 0
  fi

  local -a parts1 parts2
  IFS='.' read -ra parts1 <<< "${v1}"
  IFS='.' read -ra parts2 <<< "${v2}"

  local max=${#parts1[@]}
  if [[ ${#parts2[@]} -gt ${max} ]]; then
    max=${#parts2[@]}
  fi

  local i
  for ((i = 0; i < max; i++)); do
    local p1=${parts1[i]:-0}
    local p2=${parts2[i]:-0}
    if ((p1 > p2)); then
      return 1
    elif ((p1 < p2)); then
      return 2
    fi
  done

  return 0
}

# Check if v1 > v2
version_gt() {
  local rc=0
  version_compare "${1}" "${2}" || rc=$?
  [[ ${rc} -eq 1 ]]
}

# Check if v1 >= v2
version_ge() {
  local rc=0
  version_compare "${1}" "${2}" || rc=$?
  [[ ${rc} -eq 1 || ${rc} -eq 0 ]]
}

# Check if v1 < v2
version_lt() {
  local rc=0
  version_compare "${1}" "${2}" || rc=$?
  [[ ${rc} -eq 2 ]]
}

# Check if v1 <= v2
version_le() {
  local rc=0
  version_compare "${1}" "${2}" || rc=$?
  [[ ${rc} -eq 2 || ${rc} -eq 0 ]]
}

# Check if a version is an exact version (no range syntax)
version_is_exact() {
  local version="${1}"
  [[ "${version}" != *"["* && "${version}" != *"("* && "${version}" != *"]"* && "${version}" != *")"* && "${version}" != *","* ]]
}

# Resolve a version range against a newline-delimited list of available versions.
# For exact versions, validates the version exists in the list.
# For ranges, returns the highest version satisfying the range.
#
# Usage: version_resolve_range "<range>" "<newline-delimited-versions>"
# stdout: resolved version
# exit 1: no match found
version_resolve_range() {
  local range="${1}"
  local available="${2}"

  if [[ -z "${available}" ]]; then
    echo "No available versions provided" >&2
    return 1
  fi

  # Exact version: just check it exists
  if version_is_exact "${range}"; then
    if echo "${available}" | grep -qx "${range}"; then
      echo "${range}"
      return 0
    else
      echo "Exact version ${range} not found in available versions" >&2
      return 1
    fi
  fi

  # Parse range syntax
  local lower_bracket lower_version upper_version upper_bracket

  lower_bracket="${range:0:1}"
  upper_bracket="${range: -1}"

  # Strip brackets
  local inner="${range:1:${#range}-2}"

  # Split on comma
  lower_version="${inner%%,*}"
  upper_version="${inner#*,}"

  # Trim whitespace
  lower_version="${lower_version// /}"
  upper_version="${upper_version// /}"

  # Validate bracket characters
  if [[ "${lower_bracket}" != "[" && "${lower_bracket}" != "(" ]]; then
    echo "Invalid range syntax: must start with [ or ( : ${range}" >&2
    return 1
  fi
  if [[ "${upper_bracket}" != "]" && "${upper_bracket}" != ")" ]]; then
    echo "Invalid range syntax: must end with ] or ) : ${range}" >&2
    return 1
  fi

  # Find the highest matching version
  local best=""
  local version
  while IFS= read -r version; do
    [[ -z "${version}" ]] && continue

    # Check lower bound
    if [[ -n "${lower_version}" ]]; then
      if [[ "${lower_bracket}" == "[" ]]; then
        version_ge "${version}" "${lower_version}" || continue
      else
        version_gt "${version}" "${lower_version}" || continue
      fi
    fi

    # Check upper bound
    if [[ -n "${upper_version}" ]]; then
      if [[ "${upper_bracket}" == "]" ]]; then
        version_le "${version}" "${upper_version}" || continue
      else
        version_lt "${version}" "${upper_version}" || continue
      fi
    fi

    # Track highest match
    if [[ -z "${best}" ]]; then
      best="${version}"
    elif version_gt "${version}" "${best}"; then
      best="${version}"
    fi
  done <<< "${available}"

  if [[ -z "${best}" ]]; then
    echo "No version matching range ${range} found in available versions" >&2
    return 1
  fi

  echo "${best}"
}
