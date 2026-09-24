#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/resource-checksum.bash secret input set: which secret-template
# tokens need an encrypted value and feed the hash.

bats_require_minimum_version 1.5.0

load helpers

setup() {
  TEST_DIR=$(create_test_dir "resource-checksum")
  source "${LIB_DIR}/token-format.bash"
  source "${LIB_DIR}/token-markers.bash"
  source "${LIB_DIR}/secret-encryption-types.bash"
  source "${LIB_DIR}/resource-checksum.bash"
  export TOKEN_DELIMITER_STYLE="shell"
  export TOKEN_NAME_STYLE="PascalCase"
  # Preset to avoid needing a container runtime.
  SECRET_ENCRYPTION_TYPES="age"
  export RESOURCE_CHECKSUM_AUDIT_DIR="${TEST_DIR}/audit"
  mkdir -p "${TEST_DIR}/tree" "${TEST_DIR}/secrets"
  cd "${TEST_DIR}"
}

teardown() {
  dump_bats_result
}

write_template() {
  cat > "${TEST_DIR}/tree/thing.template.yaml"
}

@test "secret input set: every token needs an encrypted value" {
  write_template << 'EOF'
stringData:
  password: ${DbPassword}
EOF
  printf 'ciphertext' > secrets/DbPassword.age
  checksum_secret_input_set "${TEST_DIR}/tree" "${TEST_DIR}/tree/thing.template.yaml" secrets 5
  [ "${SECRET_TOKEN_COUNT}" -eq 1 ]
  [ -n "${SECRET_HASH}" ]
}

@test "secret input set: a missing encrypted value fails" {
  write_template << 'EOF'
stringData:
  password: ${DbPassword}
EOF
  run checksum_secret_input_set "${TEST_DIR}/tree" "${TEST_DIR}/tree/thing.template.yaml" secrets 5
  [ "$status" -ne 0 ]
  assert_output_contains "references token 'DbPassword'"
}

@test "secret input set: a token an IgnoreUnresolved marker covers needs no value" {
  write_template << 'EOF'
stringData:
  script: echo ${HOME} # IgnoreUnresolved
  password: ${DbPassword}
EOF
  printf 'ciphertext' > secrets/DbPassword.age
  checksum_secret_input_set "${TEST_DIR}/tree" "${TEST_DIR}/tree/thing.template.yaml" secrets 5
  [ "${SECRET_TOKEN_COUNT}" -eq 1 ]
}
