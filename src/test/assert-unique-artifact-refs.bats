#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/assert-unique-artifact-refs.bash.
#
# Covers both identity modes ('name' last-segment-only, 'path' keeps
# registry/path qualification) and the no-duplicate / duplicate paths.

load helpers

# shellcheck source=src/scripts/lib/assert-unique-artifact-refs.bash
source "${LIB_DIR}/assert-unique-artifact-refs.bash"

setup() {
  TEST_DIR=$(create_test_dir "assert-unique-artifact-refs")
  YAML_FILE="${TEST_DIR}/input.yaml"
}

write_yaml() {
  : > "${YAML_FILE}"
  cat > "${YAML_FILE}" << 'EOF'
spec:
  contents:
EOF
  local entry
  for entry in "$@"; do
    printf '    - %s\n' "${entry}" >> "${YAML_FILE}"
  done
}

# =============================================================================
# Argument validation
# =============================================================================

@test "rejects wrong arg count" {
  run assert_unique_artifact_refs only-one
  [ "${status}" -ne 0 ]
  assert_output_contains "requires exactly 4 arguments"
}

@test "rejects unknown mode" {
  write_yaml "alpha:1.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" bogus
  [ "${status}" -ne 0 ]
  assert_output_contains "unknown mode 'bogus'"
}

@test "rejects missing yaml file" {
  run assert_unique_artifact_refs "${TEST_DIR}/does-not-exist.yaml" \
      '.spec.contents[]' "ctx" name
  [ "${status}" -ne 0 ]
  assert_output_contains "file not found"
}

# =============================================================================
# Empty / single
# =============================================================================

@test "missing yq path passes (no entries)" {
  cat > "${YAML_FILE}" << 'EOF'
spec: {}
EOF
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -eq 0 ]
}

@test "empty list passes" {
  cat > "${YAML_FILE}" << 'EOF'
spec:
  contents: []
EOF
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -eq 0 ]
}

@test "single entry passes" {
  write_yaml "alpha:1.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -eq 0 ]
}

@test "distinct entries pass" {
  write_yaml "alpha:1.0" "beta:1.0" "gamma:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -eq 0 ]
}

# =============================================================================
# 'name' mode (last-segment identity)
# =============================================================================

@test "name mode: identical refs fail" {
  write_yaml "alpha:1.0" "alpha:1.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' \
      "Product spec.contents" name
  [ "${status}" -ne 0 ]
  assert_output_contains "Product spec.contents contains duplicate"
  assert_output_contains "alpha"
}

@test "name mode: differing version fails" {
  write_yaml "alpha:1.0" "alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -ne 0 ]
  assert_output_contains "alpha"
}

@test "name mode: differing path qualification fails" {
  write_yaml "org-a/alpha:1.0" "org-b/alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -ne 0 ]
  assert_output_contains "alpha"
}

@test "name mode: provider prefix differs but name matches fails" {
  write_yaml "docker|alpha:1.0" "alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -ne 0 ]
  assert_output_contains "alpha"
}

@test "name mode: full registry refs collapse on last segment" {
  write_yaml "ghcr.io/org-a/alpha:1.0" "registry.example.com/team/alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -ne 0 ]
  assert_output_contains "alpha"
}

@test "name mode: error message mentions registry/path qualification" {
  write_yaml "alpha:1.0" "alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -ne 0 ]
  assert_output_contains "registry/path qualification"
}

# =============================================================================
# 'path' mode (registry/path kept)
# =============================================================================

@test "path mode: identical refs fail" {
  write_yaml "alpha:1.0" "alpha:1.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' \
      "Layerset spec.layers" path
  [ "${status}" -ne 0 ]
  assert_output_contains "Layerset spec.layers contains duplicate"
  assert_output_contains "alpha"
}

@test "path mode: differing version fails" {
  write_yaml "alpha:1.0" "alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" path
  [ "${status}" -ne 0 ]
  assert_output_contains "alpha"
}

@test "path mode: differing path qualification passes (loose)" {
  write_yaml "org-a/alpha:1.0" "org-b/alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" path
  [ "${status}" -eq 0 ]
}

@test "path mode: same fully-qualified ref differing only in version fails" {
  write_yaml "ghcr.io/org/alpha:1.0" "ghcr.io/org/alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" path
  [ "${status}" -ne 0 ]
  assert_output_contains "ghcr.io/org/alpha"
}

@test "path mode: provider prefix stripped before comparison" {
  write_yaml "docker|alpha:1.0" "alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" path
  [ "${status}" -ne 0 ]
  assert_output_contains "alpha"
}

@test "path mode: error message does not mention registry/path qualification" {
  write_yaml "alpha:1.0" "alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" path
  [ "${status}" -ne 0 ]
  assert_output_not_contains "registry/path qualification"
}

# =============================================================================
# host:port refs not eaten by tag-strip
# =============================================================================

@test "name mode: host:port ref not eaten by tag-strip" {
  write_yaml "localhost:5000/org/alpha:1.0" "localhost:5000/org/alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" name
  [ "${status}" -ne 0 ]
  assert_output_contains "alpha"
}

@test "path mode: host:port ref not eaten by tag-strip" {
  write_yaml "localhost:5000/org/alpha:1.0" "localhost:5000/org/alpha:2.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" path
  [ "${status}" -ne 0 ]
  assert_output_contains "localhost:5000/org/alpha"
}

@test "path mode: host:port distinct from no-port survives" {
  write_yaml "localhost:5000/alpha:1.0" "localhost/alpha:1.0"
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.contents[]' "ctx" path
  [ "${status}" -eq 0 ]
}

# =============================================================================
# Custom yq expressions
# =============================================================================

@test "works against spec.layers path" {
  cat > "${YAML_FILE}" << 'EOF'
spec:
  layers:
    - docker|quality-strict:1.0
    - docker|quality-strict:2.0
EOF
  run assert_unique_artifact_refs "${YAML_FILE}" '.spec.layers[]' \
      "Layerset spec.layers" path
  [ "${status}" -ne 0 ]
  assert_output_contains "quality-strict"
}
