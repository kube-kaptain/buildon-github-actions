#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-run-substitute.
#
# The post-substitution gate is tested in kubernetes-run-finalise.bats.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-run-substitute"

setup() {
  TEST_DIR=$(create_test_dir "kubernetes-run-substitute")
  PRUNED="${TEST_DIR}/kaptain-out/run-environment/manifests-pruned"
  mkdir -p "${PRUNED}" "${TEST_DIR}/src/config" "${TEST_DIR}/src/secrets"

  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"

  export OUTPUT_SUB_PATH="kaptain-out"
  export PROJECT_NAME="run-env-test"
  export ENVIRONMENT_SHORT_NAME="test"
  export BUILD_MODE="build_server"
  # Keeps fixtures minimal; unreferenced-value tests turn it back on.
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="false"

  # prepare-substitution-tokens requires the full version/docker family.
  export VERSION="1.0.0"
  export VERSION_MAJOR="1" VERSION_MINOR="0" VERSION_PATCH="0"
  export VERSION_2_PART="1.0" VERSION_3_PART="1.0.0" VERSION_4_PART="1.0.0.0"
  export VERSION_DNS_SAFE="1-0-0" VERSION_2_PART_DNS_SAFE="1-0"
  export VERSION_3_PART_DNS_SAFE="1-0-0" VERSION_4_PART_DNS_SAFE="1-0-0-0"
  export GIT_TAG="v1.0.0" IS_RELEASE="false"
  export DOCKER_TAG="testtag" DOCKER_IMAGE_NAME="testimage"

  setup_mock_decryption_providers

  cd "${TEST_DIR}"
}

write_manifest() {
  local name="${1}"
  cat > "${PRUNED}/${name}"
}

# =============================================================================
# The gate is not here
# =============================================================================

@test "run-substitute: unresolved tokens are left for the finalise gate" {
  write_manifest plain.yaml << 'EOF'
leftover: ${Unknown}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qF 'leftover: ${Unknown}' kaptain-out/run-environment/manifests-substituted/plain.yaml
  [ ! -f kaptain-out/run-environment/substitution-gate-ignores.tsv ]
}

# =============================================================================
# Nested token names and encrypted value suffixes
# =============================================================================

@test "run-substitute: reads the pruned tree, so a deleted manifest is neither substituted nor counted" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  printf '%s' 'gone' > src/config/OnlyInDeleted
  # Present in the merged tree, removed from the pruned one by a delete.
  mkdir -p kaptain-out/run-environment/manifests-aggregated
  printf 'value: ${OnlyInDeleted}\n' > kaptain-out/run-environment/manifests-aggregated/deleted.yaml
  write_manifest kept.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced config value 'OnlyInDeleted'"
  [ ! -e kaptain-out/run-environment/manifests-substituted/deleted.yaml ]
  [ -f kaptain-out/run-environment/manifests-substituted/kept.yaml ]
}

@test "run-substitute: referenced nested config and secret values are not unreferenced" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  mkdir -p src/config/Vendor src/secrets/Vendor
  printf '%s' 'db.internal' > src/config/Vendor/DbHost
  printf '%s' 'ciphertext' > src/secrets/Vendor/DbPassword.age
  write_manifest plain.yaml << 'EOF'
host: ${Vendor/DbHost}
EOF
  write_manifest thing.template.yaml << 'EOF'
secret: ${Vendor/DbPassword}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx '  - Vendor/DbHost' kaptain-out/run-environment/token-usage.yaml
}

@test "run-substitute: unreferenced values are named by token, nested path kept, suffix dropped" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  mkdir -p src/config/Vendor src/secrets/Vendor
  printf '%s' 'db.internal' > src/config/Vendor/DbHost
  printf '%s' 'ciphertext' > src/secrets/Vendor/DbPassword.age
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced config value 'Vendor/DbHost'"
  assert_output_contains "unreferenced secret value 'Vendor/DbPassword'"
  assert_output_not_contains "DbPassword.age"
  assert_output_contains "2 unreferenced config/secret value(s)"
}

@test "run-substitute: references are counted in the configured delimiter style" {
  export TOKEN_DELIMITER_STYLE="mustache"
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  mkdir -p src/config/Vendor
  printf '%s' 'db.internal' > src/config/Vendor/DbHost
  write_manifest plain.yaml << 'EOF'
host: {{ Vendor/DbHost }}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx '  - Vendor/DbHost' kaptain-out/run-environment/token-usage.yaml
}

@test "run-substitute: image pull secret values are left for finalise while generation is on" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  mkdir -p src/secrets/ImagePullSecrets/GhcrIo
  printf '%s' 'ciphertext' > src/secrets/ImagePullSecrets/GhcrIo/Password.age
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "1 ImagePullSecrets/ secret value(s) left for the generated image pull Secrets (finalise)."
}

@test "run-substitute: image pull secret values are unreferenced when generation is off" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  export ENV_AUTO_GENERATE_IMAGE_PULL_SECRETS="false"
  mkdir -p src/secrets/ImagePullSecrets/GhcrIo
  printf '%s' 'ciphertext' > src/secrets/ImagePullSecrets/GhcrIo/Password.age
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced secret value 'ImagePullSecrets/GhcrIo/Password'"
}

@test "run-substitute: only the image pull secrets root is left for finalise" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  mkdir -p src/secrets/ImagePullSecrets/GhcrIo
  printf '%s' 'ciphertext' > src/secrets/ImagePullSecrets/GhcrIo/Password.age
  printf '%s' 'ciphertext' > src/secrets/ImagePullSecretsOther.age
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced secret value 'ImagePullSecretsOther'"
  assert_output_contains "1 unreferenced config/secret value(s)"
}

teardown() {
  dump_bats_result
}
