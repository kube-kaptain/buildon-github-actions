#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for token-format.bash library
#
# This library provides:
#   convert_token_name  - Convert UPPER_SNAKE to target name style
#   format_token_reference - Wrap name with substitution delimiters
#   format_canonical_token - Convenience combining both

load helpers

# Source the library under test
LIB_DIR="$PROJECT_ROOT/src/scripts/lib"

setup() {
  # Library must exist and be sourceable
  if [[ -f "$LIB_DIR/token-format.bash" ]]; then
    source "$LIB_DIR/token-format.bash"
  fi
}

# =============================================================================
# convert_token_name tests - UPPER_SNAKE to target style
# =============================================================================

# --- PascalCase ---

@test "convert_token_name: PascalCase - PROJECT_NAME" {
  result=$(convert_token_name PascalCase PROJECT_NAME)
  [ "$result" = "ProjectName" ]
}

@test "convert_token_name: PascalCase - single word" {
  result=$(convert_token_name PascalCase VERSION)
  [ "$result" = "Version" ]
}

@test "convert_token_name: PascalCase - three words" {
  result=$(convert_token_name PascalCase DOCKER_IMAGE_NAME)
  [ "$result" = "DockerImageName" ]
}

@test "convert_token_name: PascalCase - with numbers" {
  result=$(convert_token_name PascalCase VERSION_2_PART)
  [ "$result" = "Version2Part" ]
}

# --- camelCase ---

@test "convert_token_name: camelCase - PROJECT_NAME" {
  result=$(convert_token_name camelCase PROJECT_NAME)
  [ "$result" = "projectName" ]
}

@test "convert_token_name: camelCase - single word" {
  result=$(convert_token_name camelCase VERSION)
  [ "$result" = "version" ]
}

@test "convert_token_name: camelCase - three words" {
  result=$(convert_token_name camelCase DOCKER_IMAGE_NAME)
  [ "$result" = "dockerImageName" ]
}

# --- UPPER_SNAKE (identity) ---

@test "convert_token_name: UPPER_SNAKE - passthrough" {
  result=$(convert_token_name UPPER_SNAKE PROJECT_NAME)
  [ "$result" = "PROJECT_NAME" ]
}

@test "convert_token_name: UPPER_SNAKE - already correct" {
  result=$(convert_token_name UPPER_SNAKE DOCKER_IMAGE_FULL_URI)
  [ "$result" = "DOCKER_IMAGE_FULL_URI" ]
}

# --- lower_snake ---

@test "convert_token_name: lower_snake - PROJECT_NAME" {
  result=$(convert_token_name lower_snake PROJECT_NAME)
  [ "$result" = "project_name" ]
}

@test "convert_token_name: lower_snake - single word" {
  result=$(convert_token_name lower_snake VERSION)
  [ "$result" = "version" ]
}

# --- lower-kebab ---

@test "convert_token_name: lower-kebab - PROJECT_NAME" {
  result=$(convert_token_name lower-kebab PROJECT_NAME)
  [ "$result" = "project-name" ]
}

@test "convert_token_name: lower-kebab - three words" {
  result=$(convert_token_name lower-kebab DOCKER_IMAGE_NAME)
  [ "$result" = "docker-image-name" ]
}

# --- UPPER-KEBAB ---

@test "convert_token_name: UPPER-KEBAB - PROJECT_NAME" {
  result=$(convert_token_name UPPER-KEBAB PROJECT_NAME)
  [ "$result" = "PROJECT-NAME" ]
}

@test "convert_token_name: UPPER-KEBAB - three words" {
  result=$(convert_token_name UPPER-KEBAB DOCKER_IMAGE_NAME)
  [ "$result" = "DOCKER-IMAGE-NAME" ]
}

# --- lower.dot ---

@test "convert_token_name: lower.dot - PROJECT_NAME" {
  result=$(convert_token_name lower.dot PROJECT_NAME)
  [ "$result" = "project.name" ]
}

@test "convert_token_name: lower.dot - three words" {
  result=$(convert_token_name lower.dot DOCKER_IMAGE_NAME)
  [ "$result" = "docker.image.name" ]
}

# --- UPPER.DOT ---

@test "convert_token_name: UPPER.DOT - PROJECT_NAME" {
  result=$(convert_token_name UPPER.DOT PROJECT_NAME)
  [ "$result" = "PROJECT.NAME" ]
}

@test "convert_token_name: UPPER.DOT - three words" {
  result=$(convert_token_name UPPER.DOT DOCKER_IMAGE_NAME)
  [ "$result" = "DOCKER.IMAGE.NAME" ]
}

# --- Error cases ---

@test "convert_token_name: unknown style fails" {
  run convert_token_name UnknownStyle PROJECT_NAME
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown"
}

@test "convert_token_name: missing arguments fails" {
  run convert_token_name PascalCase
  [ "$status" -ne 0 ]
}

# =============================================================================
# format_token_reference tests - wrap name with delimiters
# =============================================================================

# --- shell style ---

@test "format_token_reference: shell - simple name" {
  result=$(format_token_reference shell ProjectName)
  [ "$result" = "\${ProjectName}" ]
}

@test "format_token_reference: shell - kebab name" {
  result=$(format_token_reference shell project-name)
  [ "$result" = "\${project-name}" ]
}

# --- mustache style ---

@test "format_token_reference: mustache - simple name" {
  result=$(format_token_reference mustache ProjectName)
  [ "$result" = "{{ ProjectName }}" ]
}

@test "format_token_reference: mustache - kebab name" {
  result=$(format_token_reference mustache project-name)
  [ "$result" = "{{ project-name }}" ]
}

# --- helm style ---

@test "format_token_reference: helm - simple name" {
  result=$(format_token_reference helm ProjectName)
  [ "$result" = "{{ .Values.ProjectName }}" ]
}

@test "format_token_reference: helm - kebab name" {
  result=$(format_token_reference helm project-name)
  [ "$result" = "{{ .Values.project-name }}" ]
}

# --- erb style ---

@test "format_token_reference: erb - simple name" {
  result=$(format_token_reference erb ProjectName)
  [ "$result" = "<%= ProjectName %>" ]
}

@test "format_token_reference: erb - snake name" {
  result=$(format_token_reference erb PROJECT_NAME)
  [ "$result" = "<%= PROJECT_NAME %>" ]
}

# --- github-actions style ---

@test "format_token_reference: github-actions - simple name" {
  result=$(format_token_reference github-actions ProjectName)
  [ "$result" = "\${{ ProjectName }}" ]
}

# --- blade style ---

@test "format_token_reference: blade - simple name" {
  result=$(format_token_reference blade ProjectName)
  [ "$result" = "{{ \$ProjectName }}" ]
}

# --- stringtemplate style ---

@test "format_token_reference: stringtemplate - simple name" {
  result=$(format_token_reference stringtemplate ProjectName)
  [ "$result" = "\$ProjectName\$" ]
}

# --- ognl style ---

@test "format_token_reference: ognl - simple name" {
  result=$(format_token_reference ognl ProjectName)
  [ "$result" = "%{ProjectName}" ]
}

# --- t4 style ---

@test "format_token_reference: t4 - simple name" {
  result=$(format_token_reference t4 ProjectName)
  [ "$result" = "<#= ProjectName #>" ]
}

# --- swift style ---

@test "format_token_reference: swift - simple name" {
  result=$(format_token_reference swift ProjectName)
  [ "$result" = "\\(ProjectName)" ]
}

# --- Error cases ---

@test "format_token_reference: unknown style fails" {
  run format_token_reference unknown-style ProjectName
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown"
}

@test "format_token_reference: missing name fails" {
  run format_token_reference shell
  [ "$status" -ne 0 ]
}

# =============================================================================
# format_canonical_token tests - convenience combining both
# =============================================================================

@test "format_canonical_token: shell + PascalCase" {
  result=$(format_canonical_token shell PascalCase PROJECT_NAME)
  [ "$result" = "\${ProjectName}" ]
}

@test "format_canonical_token: mustache + lower-kebab" {
  result=$(format_canonical_token mustache lower-kebab PROJECT_NAME)
  [ "$result" = "{{ project-name }}" ]
}

@test "format_canonical_token: helm + PascalCase + three words" {
  result=$(format_canonical_token helm PascalCase DOCKER_IMAGE_NAME)
  [ "$result" = "{{ .Values.DockerImageName }}" ]
}

@test "format_canonical_token: erb + UPPER_SNAKE" {
  result=$(format_canonical_token erb UPPER_SNAKE PROJECT_NAME)
  [ "$result" = "<%= PROJECT_NAME %>" ]
}

@test "format_canonical_token: shell + camelCase" {
  result=$(format_canonical_token shell camelCase DOCKER_TAG)
  [ "$result" = "\${dockerTag}" ]
}

@test "format_canonical_token: github-actions + lower.dot" {
  result=$(format_canonical_token github-actions lower.dot PROJECT_NAME)
  [ "$result" = "\${{ project.name }}" ]
}

# --- Error propagation ---

@test "format_canonical_token: bad substitution style fails" {
  run format_canonical_token bad-style PascalCase PROJECT_NAME
  [ "$status" -ne 0 ]
}

@test "format_canonical_token: bad name style fails" {
  run format_canonical_token shell BadNameStyle PROJECT_NAME
  [ "$status" -ne 0 ]
}

@test "format_canonical_token: missing arguments fails" {
  run format_canonical_token shell PascalCase
  [ "$status" -ne 0 ]
}

# =============================================================================
# Edge cases - valid inputs
# =============================================================================

@test "convert_token_name: single letter word - PascalCase" {
  result=$(convert_token_name PascalCase A)
  [ "$result" = "A" ]
}

@test "convert_token_name: single letter word - camelCase" {
  result=$(convert_token_name camelCase A)
  [ "$result" = "a" ]
}

@test "convert_token_name: single letter word - lower_snake" {
  result=$(convert_token_name lower_snake A)
  [ "$result" = "a" ]
}

@test "convert_token_name: single letter word - lower-kebab" {
  result=$(convert_token_name lower-kebab A)
  [ "$result" = "a" ]
}

@test "convert_token_name: single letter word - lower.dot" {
  result=$(convert_token_name lower.dot A)
  [ "$result" = "a" ]
}

@test "convert_token_name: single letter word - UPPER_SNAKE" {
  result=$(convert_token_name UPPER_SNAKE A)
  [ "$result" = "A" ]
}

@test "convert_token_name: single letter word - UPPER-KEBAB" {
  result=$(convert_token_name UPPER-KEBAB A)
  [ "$result" = "A" ]
}

@test "convert_token_name: single letter word - UPPER.DOT" {
  result=$(convert_token_name UPPER.DOT A)
  [ "$result" = "A" ]
}

@test "all name styles produce valid output for ENVIRONMENT" {
  # ENVIRONMENT is an important token that will be used in ConfigMap namespace
  for style in PascalCase camelCase UPPER_SNAKE lower_snake lower-kebab UPPER-KEBAB lower.dot UPPER.DOT; do
    result=$(convert_token_name "$style" ENVIRONMENT)
    [ -n "$result" ] || { echo "Empty result for style: $style"; return 1; }
  done
}

@test "all substitution styles produce valid output" {
  for style in shell mustache helm erb github-actions blade stringtemplate ognl t4 swift; do
    result=$(format_token_reference "$style" TestName)
    [ -n "$result" ] || { echo "Empty result for style: $style"; return 1; }
  done
}

# =============================================================================
# Edge cases - invalid inputs must fail
# =============================================================================

@test "convert_token_name: empty name fails" {
  run convert_token_name PascalCase ""
  [ "$status" -ne 0 ]
}

@test "convert_token_name: empty style fails" {
  run convert_token_name "" PROJECT_NAME
  [ "$status" -ne 0 ]
}

@test "convert_token_name: whitespace-only name fails" {
  run convert_token_name PascalCase "   "
  [ "$status" -ne 0 ]
}

@test "format_token_reference: empty name fails" {
  run format_token_reference shell ""
  [ "$status" -ne 0 ]
}

@test "format_token_reference: empty style fails" {
  run format_token_reference "" ProjectName
  [ "$status" -ne 0 ]
}

@test "format_canonical_token: empty canonical name fails" {
  run format_canonical_token shell PascalCase ""
  [ "$status" -ne 0 ]
}

@test "format_canonical_token: empty substitution style fails" {
  run format_canonical_token "" PascalCase PROJECT_NAME
  [ "$status" -ne 0 ]
}

@test "format_canonical_token: empty name style fails" {
  run format_canonical_token shell "" PROJECT_NAME
  [ "$status" -ne 0 ]
}
