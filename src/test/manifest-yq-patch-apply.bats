#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/manifest-yq-patch-apply.bash. See YqPatches.md. Orphan
# patches are rejected earlier, by lib/manifest-file-kinds.bash.

bats_require_minimum_version 1.5.0

load helpers

setup() {
  TEST_DIR=$(create_test_dir "manifest-yq-patch-apply")
  source "${LIB_DIR}/manifest-file-kinds.bash"
  source "${LIB_DIR}/manifest-yq-patch-apply.bash"
  TREE="${TEST_DIR}/tree"
  SANDBOX="${TEST_DIR}/sandbox"
  mkdir -p "${TREE}/app"
  cat > "${TREE}/app/configmap.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm
data:
  mode: original
EOF
}

teardown() {
  dump_bats_result
}

patch() {
  cat > "${TREE}/app/configmap.yaml.yq-$1"
}

value() {
  yq e "$1" "${TREE}/app/configmap.yaml"
}

# =============================================================================
# The three types
# =============================================================================

@test "merge-yaml: the fragment is merged into the target" {
  patch merge-yaml-labels << 'EOF'
metadata:
  labels:
    team: platform
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -eq 0 ]
  [ "$(value '.metadata.labels.team')" = "platform" ]
  [ "$(value '.data.mode')" = "original" ]
}

@test "expression-list: each line applies in turn, blanks and comments skipped" {
  patch expression-list-two << 'EOF'
# set the mode
.data.mode = "patched"

.data.extra = "yes"
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -eq 0 ]
  [ "$(value '.data.mode')" = "patched" ]
  [ "$(value '.data.extra')" = "yes" ]
}

@test "from-file: one expression spanning lines" {
  patch from-file-multi << 'EOF'
.data.mode = "patched"
| .data.extra = "yes"
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -eq 0 ]
  [ "$(value '.data.mode')" = "patched" ]
  [ "$(value '.data.extra')" = "yes" ]
}

# =============================================================================
# Ordering and scope
# =============================================================================

@test "order: patches apply by description, not by type" {
  # Sorted by full filename the merge would run last; by description the
  # expression ('zzz') does.
  patch merge-yaml-aaa << 'EOF'
data:
  mode: from-aaa
EOF
  patch expression-list-zzz << 'EOF'
.data.mode = "from-zzz"
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -eq 0 ]
  [ "$(value '.data.mode')" = "from-zzz" ]
}

@test "scope: a patch touches only its own target and counts are kept" {
  cp "${TREE}/app/configmap.yaml" "${TREE}/app/other.yaml"
  patch expression-list-one << 'EOF'
.data.mode = "patched"
EOF
  manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$(value '.data.mode')" = "patched" ]
  [ "$(yq e '.data.mode' "${TREE}/app/other.yaml")" = "original" ]
  [ "${MANIFEST_PATCH_APPLIED_COUNT}" -eq 1 ]
  [ "${MANIFEST_PATCH_TARGET_COUNT}" -eq 1 ]
}

@test "scope: a tree with no patches is a no-op" {
  manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "${MANIFEST_PATCH_APPLIED_COUNT}" -eq 0 ]
  [ "${MANIFEST_PATCH_TARGET_COUNT}" -eq 0 ]
  [ "$(value '.data.mode')" = "original" ]
}

@test "provenance: the before and after states are kept in the sandbox" {
  patch expression-list-one << 'EOF'
.data.mode = "patched"
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -eq 0 ]
  [ "$(yq e '.data.mode' "${SANDBOX}/app_configmap.yaml/before-001-line-001.yaml")" = "original" ]
  [ "$(yq e '.data.mode' "${SANDBOX}/app_configmap.yaml/after-001.yaml")" = "patched" ]
}

# =============================================================================
# Failures leave the target unchanged
# =============================================================================

@test "fail: a patch that changes nothing" {
  patch expression-list-noop << 'EOF'
.data.missing |= "x" | del(.data.missing)
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -ne 0 ]
  assert_output_contains "changed nothing"
  [ "$(value '.data.mode')" = "original" ]
}

@test "fail: an expression yq rejects" {
  patch expression-list-bad << 'EOF'
.data.mode = = "x"
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -ne 0 ]
  assert_output_contains "yq rejected the expression"
  [ "$(value '.data.mode')" = "original" ]
}

@test "fail: a merge-yaml patch that is not valid YAML" {
  patch merge-yaml-broken << 'EOF'
data: [unclosed
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -ne 0 ]
  assert_output_contains "not valid YAML"
}

@test "fail: a patch that leaves the manifest without kind" {
  patch expression-list-destroy << 'EOF'
del(.kind)
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -ne 0 ]
  assert_output_contains "left the manifest without kind or apiVersion"
  [ "$(value '.kind')" = "ConfigMap" ]
}

@test "fail: an expression-list with only blanks and comments" {
  patch expression-list-empty << 'EOF'
# nothing here

EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -ne 0 ]
  assert_output_contains "no expressions, only blanks and comments"
}

@test "fail: an empty from-file patch" {
  : > "${TREE}/app/configmap.yaml.yq-from-file-empty"
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -ne 0 ]
  assert_output_contains "empty patch file"
}

@test "fail: an operator that reads outside the patch" {
  patch expression-list-leak << 'EOF'
.data.mode = strenv(HOME)
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -ne 0 ]
  assert_output_contains "uses 'strenv(', which reads outside the patch"
  [ "$(value '.data.mode')" = "original" ]
}

@test "operators: a merge-yaml fragment may hold keys named like operators" {
  patch merge-yaml-keys << 'EOF'
data:
  env: production
  load: high
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -eq 0 ]
  [ "$(value '.data.env')" = "production" ]
}

@test "fail: one bad patch fails the tree but the others still apply" {
  cp "${TREE}/app/configmap.yaml" "${TREE}/app/other.yaml"
  patch expression-list-bad << 'EOF'
.data.mode = = "x"
EOF
  cat > "${TREE}/app/other.yaml.yq-expression-list-good" << 'EOF'
.data.mode = "patched"
EOF
  run manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "$status" -ne 0 ]
  [ "$(yq e '.data.mode' "${TREE}/app/other.yaml")" = "patched" ]
}

@test "scope: delete modifiers are not patches and are left alone" {
  printf '# consumed by aggregate, never here\n' > "${TREE}/app/configmap.yaml.delete-gone"
  manifest_patch_tree "${TREE}" "${SANDBOX}"
  [ "${MANIFEST_PATCH_APPLIED_COUNT}" -eq 0 ]
  [ -f "${TREE}/app/configmap.yaml" ]
  [ -f "${TREE}/app/configmap.yaml.delete-gone" ]
}

# =============================================================================
# Orphans: rejected by the classifier before application
# =============================================================================

@test "orphan: a patch with no target beside it is rejected by the classifier" {
  : > "${TREE}/app/missing.yaml.yq-expression-list-x"
  run manifest_file_classify "${TREE}/app/missing.yaml.yq-expression-list-x"
  [ "$status" -ne 0 ]
  manifest_file_classify "${TREE}/app/missing.yaml.yq-expression-list-x" || true
  [ "${MANIFEST_FILE_REASON}" = "modifier has no target manifest 'missing.yaml' beside it" ]
}
