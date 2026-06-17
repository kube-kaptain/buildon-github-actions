#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for the auto-builtin scan added to util/prepare-substitution-tokens.
#
# Covers: missing dir = silent skip, files copied with TOKEN_NAME_STYLE
# conversion, prefix-mismatch hard-fails, user attempt to override an auto
# token hard-fails.

bats_require_minimum_version 1.5.0

load helpers

PSUB="$PROJECT_ROOT/src/scripts/util/prepare-substitution-tokens"

# Minimum env to drive prepare-substitution-tokens.
seed_required_env() {
  export PROJECT_NAME="my-project"
  export VERSION="1.0.0"
  export VERSION_MAJOR="1"
  export VERSION_MINOR="0"
  export VERSION_PATCH="0"
  export VERSION_2_PART="1.0"
  export VERSION_3_PART="1.0.0"
  export VERSION_4_PART="1.0.0.0"
  export VERSION_DNS_SAFE="1-0-0"
  export VERSION_2_PART_DNS_SAFE="1-0"
  export VERSION_3_PART_DNS_SAFE="1-0-0"
  export VERSION_4_PART_DNS_SAFE="1-0-0-0"
  export GIT_TAG="v1.0.0"
  export IS_RELEASE="true"
  export DOCKER_TAG="1.0.0"
  export DOCKER_IMAGE_NAME="my-project"
}

setup() {
  WORK=$(create_test_dir "psub-scan")
  export OUTPUT_SUB_PATH="${WORK}/out"
  mkdir -p "${OUTPUT_SUB_PATH}"
  export TOKENS_OUTPUT_SUB_PATH="${WORK}/tokens"
  export CONFIG_SUB_PATH="${WORK}/config"
  mkdir -p "${CONFIG_SUB_PATH}"
  seed_required_env
}

teardown() {
  dump_bats_result
}

# Create a token file under builtin-resolved-tokens/<flavour>/<name>.
seed_auto_token() {
  local flavour="$1"
  local name="$2"
  local value="$3"
  local dir="${OUTPUT_SUB_PATH}/builtin-resolved-tokens/${flavour}"
  mkdir -p "${dir}"
  printf '%s' "${value}" > "${dir}/${name}"
}

# =============================================================================
# Missing dirs = silent skip (no error, no output)
# =============================================================================

@test "no builtin-resolved-tokens dir -> silent skip" {
  export TOKEN_NAME_STYLE="PascalCase"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -d "${TOKENS_OUTPUT_SUB_PATH}" ]
}

@test "empty contents/ dir -> no auto tokens emitted" {
  export TOKEN_NAME_STYLE="PascalCase"
  mkdir -p "${OUTPUT_SUB_PATH}/builtin-resolved-tokens/contents"

  run "$PSUB"
  [ "$status" -eq 0 ]
  # No CONTENT_* / Content* token files.
  run find "${TOKENS_OUTPUT_SUB_PATH}" -name 'Content*' -type f
  [ -z "$output" ]
}

# =============================================================================
# Copy + TOKEN_NAME_STYLE conversion
# =============================================================================

@test "contents/ file copied and converted to PascalCase" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token contents "CONTENT_APP_FOO_VERSION" "1.2.3"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ContentAppFooVersion" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/ContentAppFooVersion")" = "1.2.3" ]
}

@test "contents/ file copied as-is under UPPER_SNAKE style" {
  export TOKEN_NAME_STYLE="UPPER_SNAKE"
  seed_auto_token contents "CONTENT_APP_FOO_VERSION" "1.2.3"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/CONTENT_APP_FOO_VERSION" ]
}

@test "templates/ file with TEMPLATE_ prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token templates "TEMPLATE_TPL_FOO_VERSION" "2.0.0"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/TemplateTplFooVersion" ]
}

@test "layers/ file with LAYER_ prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token layers "LAYER_LAYER_FOO_VERSION" "3.0.0"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/LayerLayerFooVersion" ]
}

@test "all seven dirs scanned in one run" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token contents  "CONTENT_C_VERSION"            "1.0"
  seed_auto_token templates "TEMPLATE_T_VERSION"           "2.0"
  seed_auto_token layers    "LAYER_L_VERSION"              "3.0"
  seed_auto_token build     "BUILD_TIMESTAMP"              "2026-06-17T14:32:15Z"
  seed_auto_token image     "IMAGE_BUILD_COMMAND"          "docker"
  seed_auto_token git       "GIT_BRANCH"                   "main"
  seed_auto_token kaptainpm "KAPTAINPM_KIND"               "kubernetes-app-docker-dockerfile"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ContentCVersion" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/TemplateTVersion" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/LayerLVersion" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/BuildTimestamp" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ImageBuildCommand" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/GitBranch" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/KaptainpmKind" ]
}

@test "build/ file with BUILD_ prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token build "BUILD_TIMESTAMP" "2026-06-17T14:32:15Z"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/BuildTimestamp" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/BuildTimestamp")" = "2026-06-17T14:32:15Z" ]
}

@test "image/ file with IMAGE_ prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token image "IMAGE_BUILD_COMMAND" "podman"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ImageBuildCommand" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/ImageBuildCommand")" = "podman" ]
}

@test "git/ file with GIT_ prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token git "GIT_HASH_FULL" "abc1234deadbeef"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/GitHashFull" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/GitHashFull")" = "abc1234deadbeef" ]
}

@test "kaptainpm/ file with KAPTAINPM_ prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token kaptainpm "KAPTAINPM_KIND" "kubernetes-app-docker-dockerfile"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/KaptainpmKind" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/KaptainpmKind")" = "kubernetes-app-docker-dockerfile" ]
}

@test "file in build/ without BUILD_ prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token build "CONTENT_WRONG_TIMESTAMP" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'BUILD_'"* ]]
}

@test "file in image/ without IMAGE_ prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token image "BUILD_WRONG_COMMAND" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'IMAGE_'"* ]]
}

@test "file in git/ without GIT_ prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token git "BUILD_WRONG_HASH" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'GIT_'"* ]]
}

@test "file in kaptainpm/ without KAPTAINPM_ prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token kaptainpm "BUILD_WRONG_KIND" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'KAPTAINPM_'"* ]]
}

# =============================================================================
# Prefix mismatch: hard-fail
# =============================================================================

@test "file in contents/ without CONTENT_ prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token contents "TEMPLATE_WRONG_VERSION" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'CONTENT_'"* ]]
}

@test "file in layers/ without LAYER_ prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token layers "CONTENT_WRONG_VERSION" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'LAYER_'"* ]]
}

# =============================================================================
# User config cannot override an auto-emitted token
# =============================================================================

@test "user config token that collides with auto token -> override fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token contents "CONTENT_APP_FOO_VERSION" "1.2.3"
  printf '%s' "override" > "${CONFIG_SUB_PATH}/ContentAppFooVersion"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"override built-in"* ]]
}
