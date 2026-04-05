#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/version-range.bash
# Thorough coverage of Maven-style version range resolution

load helpers

setup() {
  source "$LIB_DIR/version-range.bash"
}

teardown() {
  :
}

# =============================================================================
# version_compare - basic equality
# =============================================================================

@test "version_compare: equal simple versions" {
  version_compare "1.0" "1.0"
  [[ $? -eq 0 ]]
}

@test "version_compare: equal three-part versions" {
  version_compare "1.2.3" "1.2.3"
  [[ $? -eq 0 ]]
}

@test "version_compare: equal with trailing zero" {
  version_compare "1.2" "1.2.0"
  [[ $? -eq 0 ]]
}

@test "version_compare: equal with multiple trailing zeros" {
  version_compare "1.0.0" "1"
  [[ $? -eq 0 ]]
}

# =============================================================================
# version_compare - greater than
# =============================================================================

@test "version_compare: major version greater" {
  run version_compare "2.0" "1.0"
  [[ "$status" -eq 1 ]]
}

@test "version_compare: minor version greater" {
  run version_compare "1.2" "1.1"
  [[ "$status" -eq 1 ]]
}

@test "version_compare: patch version greater" {
  run version_compare "1.2.4" "1.2.3"
  [[ "$status" -eq 1 ]]
}

@test "version_compare: 1.10 is greater than 1.9 (numeric not lexicographic)" {
  run version_compare "1.10" "1.9"
  [[ "$status" -eq 1 ]]
}

@test "version_compare: longer version greater when prefix equal" {
  run version_compare "1.2.1" "1.2"
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# version_compare - less than
# =============================================================================

@test "version_compare: major version less" {
  run version_compare "1.0" "2.0"
  [[ "$status" -eq 2 ]]
}

@test "version_compare: minor version less" {
  run version_compare "1.1" "1.2"
  [[ "$status" -eq 2 ]]
}

@test "version_compare: patch version less" {
  run version_compare "1.2.3" "1.2.4"
  [[ "$status" -eq 2 ]]
}

@test "version_compare: 1.9 is less than 1.10" {
  run version_compare "1.9" "1.10"
  [[ "$status" -eq 2 ]]
}

# =============================================================================
# version_gt, version_ge, version_lt, version_le
# =============================================================================

@test "version_gt: returns true when greater" {
  version_gt "2.0" "1.0"
}

@test "version_gt: returns false when equal" {
  ! version_gt "1.0" "1.0"
}

@test "version_gt: returns false when less" {
  ! version_gt "1.0" "2.0"
}

@test "version_ge: returns true when greater" {
  version_ge "2.0" "1.0"
}

@test "version_ge: returns true when equal" {
  version_ge "1.0" "1.0"
}

@test "version_ge: returns false when less" {
  ! version_ge "1.0" "2.0"
}

@test "version_lt: returns true when less" {
  version_lt "1.0" "2.0"
}

@test "version_lt: returns false when equal" {
  ! version_lt "1.0" "1.0"
}

@test "version_lt: returns false when greater" {
  ! version_lt "2.0" "1.0"
}

@test "version_le: returns true when less" {
  version_le "1.0" "2.0"
}

@test "version_le: returns true when equal" {
  version_le "1.0" "1.0"
}

@test "version_le: returns false when greater" {
  ! version_le "2.0" "1.0"
}

# =============================================================================
# version_is_exact
# =============================================================================

@test "version_is_exact: simple version" {
  version_is_exact "1.0"
}

@test "version_is_exact: three-part version" {
  version_is_exact "1.2.3"
}

@test "version_is_exact: single number" {
  version_is_exact "3"
}

@test "version_is_exact: false for square bracket range" {
  ! version_is_exact "[1.0,2.0)"
}

@test "version_is_exact: false for round bracket range" {
  ! version_is_exact "(1.0,2.0]"
}

@test "version_is_exact: false for open-ended range" {
  ! version_is_exact "[1.0,)"
}

# =============================================================================
# version_resolve_range - exact match
# =============================================================================

@test "resolve_range: exact version found" {
  local versions
  versions=$(printf "1.0\n1.1\n1.2\n2.0\n")
  version_resolve_range "1.1" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.1" ]]
}

@test "resolve_range: exact version not found" {
  local versions
  versions=$(printf "1.0\n1.1\n1.2\n")
  run version_resolve_range "1.5" "${versions}"
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# version_resolve_range - inclusive lower, exclusive upper [a,b)
# =============================================================================

@test "resolve_range: [1.0,2.0) returns highest below 2.0" {
  local versions
  versions=$(printf "0.9\n1.0\n1.5\n1.9\n2.0\n2.1\n")
  version_resolve_range "[1.0,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.9" ]]
}

@test "resolve_range: [1.0,2.0) includes lower bound" {
  local versions
  versions=$(printf "1.0\n2.0\n")
  version_resolve_range "[1.0,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.0" ]]
}

@test "resolve_range: [1.0,2.0) excludes upper bound" {
  local versions
  versions=$(printf "2.0\n3.0\n")
  run version_resolve_range "[1.0,2.0)" "${versions}"
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# version_resolve_range - inclusive both [a,b]
# =============================================================================

@test "resolve_range: [1.0,2.0] includes upper bound" {
  local versions
  versions=$(printf "1.0\n1.5\n2.0\n2.1\n")
  version_resolve_range "[1.0,2.0]" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "2.0" ]]
}

@test "resolve_range: [1.0,1.0] matches single version" {
  local versions
  versions=$(printf "0.9\n1.0\n1.1\n")
  version_resolve_range "[1.0,1.0]" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.0" ]]
}

# =============================================================================
# version_resolve_range - exclusive lower, inclusive upper (a,b]
# =============================================================================

@test "resolve_range: (1.0,2.0] excludes lower bound" {
  local versions
  versions=$(printf "1.0\n1.1\n2.0\n")
  version_resolve_range "(1.0,2.0]" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "2.0" ]]
}

@test "resolve_range: (1.0,2.0] with only lower bound fails" {
  local versions
  versions=$(printf "1.0\n")
  run version_resolve_range "(1.0,2.0]" "${versions}"
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# version_resolve_range - exclusive both (a,b)
# =============================================================================

@test "resolve_range: (1.0,2.0) excludes both bounds" {
  local versions
  versions=$(printf "1.0\n1.5\n2.0\n")
  version_resolve_range "(1.0,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.5" ]]
}

@test "resolve_range: (1.0,2.0) with only bounds fails" {
  local versions
  versions=$(printf "1.0\n2.0\n")
  run version_resolve_range "(1.0,2.0)" "${versions}"
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# version_resolve_range - open-ended ranges
# =============================================================================

@test "resolve_range: [1.0,) returns highest >= 1.0" {
  local versions
  versions=$(printf "0.5\n1.0\n2.0\n3.5\n")
  version_resolve_range "[1.0,)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "3.5" ]]
}

@test "resolve_range: (1.0,) returns highest > 1.0" {
  local versions
  versions=$(printf "1.0\n1.1\n5.0\n")
  version_resolve_range "(1.0,)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "5.0" ]]
}

@test "resolve_range: (,2.0] returns highest <= 2.0" {
  local versions
  versions=$(printf "0.1\n1.0\n1.9\n2.0\n3.0\n")
  version_resolve_range "(,2.0]" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "2.0" ]]
}

@test "resolve_range: (,2.0) returns highest < 2.0" {
  local versions
  versions=$(printf "0.1\n1.0\n1.9\n2.0\n")
  version_resolve_range "(,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.9" ]]
}

# =============================================================================
# version_resolve_range - picks highest match
# =============================================================================

@test "resolve_range: picks highest from multiple matches" {
  local versions
  versions=$(printf "1.0\n1.1\n1.2\n1.3\n1.4\n")
  version_resolve_range "[1.0,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.4" ]]
}

@test "resolve_range: handles unsorted input" {
  local versions
  versions=$(printf "1.3\n1.1\n1.4\n1.0\n1.2\n")
  version_resolve_range "[1.0,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.4" ]]
}

@test "resolve_range: handles multi-part versions in range" {
  local versions
  versions=$(printf "1.0.0\n1.0.1\n1.1.0\n1.2.0\n2.0.0\n")
  version_resolve_range "[1.0.0,1.2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.1.0" ]]
}

# =============================================================================
# version_resolve_range - error cases
# =============================================================================

@test "resolve_range: empty version list fails" {
  run version_resolve_range "[1.0,2.0)" ""
  [[ "$status" -eq 1 ]]
}

@test "resolve_range: no matching version fails" {
  local versions
  versions=$(printf "3.0\n4.0\n5.0\n")
  run version_resolve_range "[1.0,2.0)" "${versions}"
  [[ "$status" -eq 1 ]]
}

@test "resolve_range: invalid bracket syntax fails" {
  local versions
  versions=$(printf "1.0\n")
  run version_resolve_range "{1.0,2.0}" "${versions}"
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# version_resolve_range - edge cases
# =============================================================================

@test "resolve_range: single-part versions" {
  local versions
  versions=$(printf "1\n2\n3\n4\n")
  version_resolve_range "[2,4)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "3" ]]
}

@test "resolve_range: many-part versions" {
  local versions
  versions=$(printf "1.2.3.4\n1.2.3.5\n1.2.4.0\n")
  version_resolve_range "[1.2.3.4,1.2.4.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.2.3.5" ]]
}

@test "resolve_range: numeric comparison 1.10 > 1.9 in range" {
  local versions
  versions=$(printf "1.8\n1.9\n1.10\n1.11\n2.0\n")
  version_resolve_range "[1.0,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.11" ]]
}

# =============================================================================
# Suffixed versions (e.g. 1.1-PRERELEASE) - must not crash
# =============================================================================

@test "version_compare: suffixed version produces valid exit code" {
  # In real scripts with set -u, "1-PRERELEASE" in arithmetic causes unbound
  # variable crash. Even without -u, the comparison must produce a valid result.
  run version_compare "1.1-PRERELEASE" "1.1"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]] || [[ "$status" -eq 2 ]]
}

@test "version_compare: suffixed less than unsuffixed at same numeric" {
  run version_compare "1.1-PRERELEASE" "1.1"
  [[ "$status" -eq 2 ]]
}

@test "version_compare: unsuffixed greater than suffixed at same numeric" {
  run version_compare "1.1" "1.1-PRERELEASE"
  [[ "$status" -eq 1 ]]
}

@test "version_compare: two identical suffixed versions are equal" {
  run version_compare "1.1-PRERELEASE" "1.1-PRERELEASE"
  [[ "$status" -eq 0 ]]
}

@test "version_compare: suffixed version with higher numeric still wins" {
  run version_compare "1.2-PRERELEASE" "1.1"
  [[ "$status" -eq 1 ]]
}

@test "resolve_range: available list with suffixed versions does not crash" {
  local versions
  versions=$(printf "1.0\n1.1-PRERELEASE\n1.1\n1.2\n")
  version_resolve_range "[1.1,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.2" ]]
}

@test "resolve_range: suffixed-only versions still resolve when in range" {
  local versions
  versions=$(printf "1.1-PRERELEASE\n1.2-PRERELEASE\n")
  version_resolve_range "[1.0,2.0)" "${versions}"
  [[ -n "${VERSION_RESOLVE_RESULT}" ]]
}

@test "resolve_range: local prerelease higher than latest release picks prerelease" {
  # Scenario: 2.1 released remotely, 2.2-PRERELEASE built locally
  # 2.2-PRERELEASE > 2.1 numerically, so it should be picked
  local versions
  versions=$(printf "2.0\n2.1\n2.2-PRERELEASE\n")
  version_resolve_range "[2.0,3.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "2.2-PRERELEASE" ]]
}

@test "resolve_range: release preferred over prerelease at same numeric" {
  # Both 1.1 and 1.1-PRERELEASE exist - 1.1 wins (unsuffixed > suffixed)
  local versions
  versions=$(printf "1.1-PRERELEASE\n1.1\n")
  version_resolve_range "[1.0,2.0)" "${versions}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.1" ]]
}

@test "version_is_exact: suffixed version is exact" {
  version_is_exact "1.2.3-PRERELEASE"
}

# =============================================================================
# version_filter_release - exclude suffixed versions for release builds
# =============================================================================

@test "version_filter_release: strips suffixed versions" {
  local versions
  versions=$(printf "1.0\n1.1-PRERELEASE\n1.1\n1.2-PRERELEASE\n2.0\n")
  run version_filter_release "${versions}"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "$(printf '1.0\n1.1\n2.0')" ]]
}

@test "version_filter_release: keeps all pure numeric versions" {
  local versions
  versions=$(printf "1.0\n1.1\n2.0\n")
  run version_filter_release "${versions}"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "$(printf '1.0\n1.1\n2.0')" ]]
}

@test "version_filter_release: returns empty when all suffixed" {
  local versions
  versions=$(printf "1.0-PRERELEASE\n1.1-SNAPSHOT\n")
  run version_filter_release "${versions}"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "version_filter_release: strips arch-suffixed tags" {
  local versions
  versions=$(printf "1.1\n1.1-linux-amd64\n1.1-linux-arm64\n1.1-release-change-data\n")
  run version_filter_release "${versions}"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "1.1" ]]
}

@test "resolve_range: IS_RELEASE=true excludes suffixed versions" {
  # When IS_RELEASE is true, only release (unsuffixed) versions should be candidates
  export IS_RELEASE="true"
  local versions
  versions=$(printf "1.0\n1.1-PRERELEASE\n1.2-PRERELEASE\n")
  local filtered
  filtered=$(version_filter_release "${versions}")
  version_resolve_range "[1.0,2.0)" "${filtered}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.0" ]]
}

@test "resolve_range: IS_RELEASE=true picks highest release ignoring higher prerelease" {
  export IS_RELEASE="true"
  local versions
  versions=$(printf "1.0\n1.1\n1.2-PRERELEASE\n2.0\n")
  local filtered
  filtered=$(version_filter_release "${versions}")
  version_resolve_range "[1.0,2.0)" "${filtered}"
  [[ "${VERSION_RESOLVE_RESULT}" == "1.1" ]]
}
