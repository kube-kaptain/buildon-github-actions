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

@test "contents/ PascalCase file copied verbatim" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token contents "ContentAppFooVersion" "1.2.3"

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

@test "templates/ file with Template prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token templates "TemplateTplFooVersion" "2.0.0"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/TemplateTplFooVersion" ]
}

@test "layers/ file with Layer prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token layers "LayerLayerFooVersion" "3.0.0"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/LayerLayerFooVersion" ]
}

@test "all nine dirs scanned in one run" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token contents   "ContentCVersion"     "1.0"
  seed_auto_token templates  "TemplateTVersion"    "2.0"
  seed_auto_token layers     "LayerLVersion"       "3.0"
  seed_auto_token build      "BuildTimestamp"      "2026-06-17T14:32:15Z"
  seed_auto_token image      "ImageBuildCommand"   "docker"
  seed_auto_token git        "GitBranch"           "main"
  seed_auto_token kaptainpm  "KaptainpmKind"       "kubernetes-app-docker-dockerfile"
  seed_auto_token repository "RepositoryOwner"     "kube-kaptain"
  seed_auto_token product    "ProductName"         "product-foo"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ContentCVersion" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/TemplateTVersion" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/LayerLVersion" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/BuildTimestamp" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ImageBuildCommand" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/GitBranch" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/KaptainpmKind" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/RepositoryOwner" ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ProductName" ]
}

@test "build/ file with Build prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token build "BuildTimestamp" "2026-06-17T14:32:15Z"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/BuildTimestamp" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/BuildTimestamp")" = "2026-06-17T14:32:15Z" ]
}

@test "image/ file with Image prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token image "ImageBuildCommand" "podman"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ImageBuildCommand" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/ImageBuildCommand")" = "podman" ]
}

@test "git/ file with Git prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token git "GitHashFull" "abc1234deadbeef"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/GitHashFull" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/GitHashFull")" = "abc1234deadbeef" ]
}

@test "kaptainpm/ file with Kaptainpm prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token kaptainpm "KaptainpmKind" "kubernetes-app-docker-dockerfile"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/KaptainpmKind" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/KaptainpmKind")" = "kubernetes-app-docker-dockerfile" ]
}

@test "repository/ file with Repository prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token repository "RepositoryName" "my-repo"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/RepositoryName" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/RepositoryName")" = "my-repo" ]
}

@test "product/ file with Product prefix is copied" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token product "ProductShortName" "foo"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/ProductShortName" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/ProductShortName")" = "foo" ]
}

@test "TargetNamespace token always written - empty when namespace unset" {
  export TOKEN_NAME_STYLE="PascalCase"
  unset TARGET_NAMESPACE 2>/dev/null || true

  run "$PSUB"
  [ "$status" -eq 0 ]
  # targetIncludeNamespace=false resolves to an empty namespace; the token
  # must substitute to "" rather than ship dangling.
  [ -f "${TOKENS_OUTPUT_SUB_PATH}/TargetNamespace" ]
  [ "$(cat "${TOKENS_OUTPUT_SUB_PATH}/TargetNamespace")" = "" ]
}

# Context scalars arrive via the disk scan only - env vars alone must NOT
# produce tokens (the per-call-site env path was removed; it silently missed
# call sites, shipping unsubstituted tokens in released manifests).
@test "REPOSITORY/PRODUCT env vars alone produce no tokens" {
  export TOKEN_NAME_STYLE="PascalCase"
  export REPOSITORY_OWNER="kube-kaptain"
  export REPOSITORY_NAME="my-repo"
  export PRODUCT_NAME="product-foo"
  export PRODUCT_SHORT_NAME="foo"

  run "$PSUB"
  [ "$status" -eq 0 ]
  [ ! -f "${TOKENS_OUTPUT_SUB_PATH}/RepositoryOwner" ]
  [ ! -f "${TOKENS_OUTPUT_SUB_PATH}/RepositoryName" ]
  [ ! -f "${TOKENS_OUTPUT_SUB_PATH}/ProductName" ]
  [ ! -f "${TOKENS_OUTPUT_SUB_PATH}/ProductShortName" ]
}

@test "file in build/ without Build prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token build "ContentWrongTimestamp" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'Build'"* ]]
}

@test "file in image/ without Image prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token image "BuildWrongCommand" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'Image'"* ]]
}

@test "file in git/ without Git prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token git "BuildWrongHash" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'Git'"* ]]
}

@test "file in kaptainpm/ without Kaptainpm prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token kaptainpm "BuildWrongKind" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'Kaptainpm'"* ]]
}

@test "file in repository/ without Repository prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token repository "BuildWrongOwner" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'Repository'"* ]]
}

@test "file in product/ without Product prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token product "BuildWrongName" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'Product'"* ]]
}

# =============================================================================
# Prefix mismatch: hard-fail
# =============================================================================

@test "file in contents/ without Content prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token contents "TemplateWrongVersion" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'Content'"* ]]
}

@test "file in layers/ without Layer prefix -> fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token layers "ContentWrongVersion" "x"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with required prefix 'Layer'"* ]]
}

# =============================================================================
# User config cannot override an auto-emitted token
# =============================================================================

@test "user config token that collides with auto token -> override fail" {
  export TOKEN_NAME_STYLE="PascalCase"
  seed_auto_token contents "ContentAppFooVersion" "1.2.3"
  printf '%s' "override" > "${CONFIG_SUB_PATH}/ContentAppFooVersion"

  run "$PSUB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"override built-in"* ]]
}
