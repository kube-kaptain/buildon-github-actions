#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for token-format.bash library
#
# This library provides:
#   convert_token_name  - Convert UPPER_SNAKE to target name style
#   convert_kebab_name  - Convert lower-kebab to target name style
#   format_token_reference - Wrap name with substitution delimiters
#   format_canonical_token - Convenience combining both
#   format_project_suffixed_token - Combine project + suffix into delimited token
#   unresolved_token_regex - grep-E regex matching unresolved tokens

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

# =============================================================================
# convert_kebab_name tests - lower-kebab to target style
# =============================================================================

@test "convert_kebab_name: PascalCase - simple" {
  result=$(convert_kebab_name PascalCase my-project)
  [ "$result" = "MyProject" ]
}

@test "convert_kebab_name: PascalCase - three words" {
  result=$(convert_kebab_name PascalCase my-cool-project)
  [ "$result" = "MyCoolProject" ]
}

@test "convert_kebab_name: camelCase - simple" {
  result=$(convert_kebab_name camelCase my-project)
  [ "$result" = "myProject" ]
}

@test "convert_kebab_name: camelCase - three words" {
  result=$(convert_kebab_name camelCase my-cool-project)
  [ "$result" = "myCoolProject" ]
}

@test "convert_kebab_name: UPPER_SNAKE - simple" {
  result=$(convert_kebab_name UPPER_SNAKE my-project)
  [ "$result" = "MY_PROJECT" ]
}

@test "convert_kebab_name: lower_snake - three words" {
  result=$(convert_kebab_name lower_snake my-cool-project)
  [ "$result" = "my_cool_project" ]
}

@test "convert_kebab_name: lower-kebab - passthrough" {
  result=$(convert_kebab_name lower-kebab my-project)
  [ "$result" = "my-project" ]
}

@test "convert_kebab_name: UPPER-KEBAB - simple" {
  result=$(convert_kebab_name UPPER-KEBAB my-project)
  [ "$result" = "MY-PROJECT" ]
}

@test "convert_kebab_name: lower.dot - three words" {
  result=$(convert_kebab_name lower.dot my-cool-project)
  [ "$result" = "my.cool.project" ]
}

@test "convert_kebab_name: UPPER.DOT - simple" {
  result=$(convert_kebab_name UPPER.DOT my-project)
  [ "$result" = "MY.PROJECT" ]
}

@test "convert_kebab_name: single word" {
  result=$(convert_kebab_name PascalCase project)
  [ "$result" = "Project" ]
}

# --- Error cases ---

@test "convert_kebab_name: missing arguments fails" {
  run convert_kebab_name PascalCase
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 2 arguments"
}

@test "convert_kebab_name: empty name fails" {
  run convert_kebab_name PascalCase ""
  [ "$status" -ne 0 ]
}

@test "convert_kebab_name: unknown style fails" {
  run convert_kebab_name UnknownStyle my-project
  [ "$status" -ne 0 ]
}

# =============================================================================
# format_project_suffixed_token tests - project + suffix combined
# =============================================================================

@test "format_project_suffixed_token: shell + PascalCase" {
  result=$(format_project_suffixed_token shell PascalCase my-project AFFINITY_COLOCATE_APP)
  [ "$result" = "\${MyProjectAffinityColocateApp}" ]
}

@test "format_project_suffixed_token: mustache + PascalCase" {
  result=$(format_project_suffixed_token mustache PascalCase my-project AFFINITY_COLOCATE_APP)
  [ "$result" = "{{ MyProjectAffinityColocateApp }}" ]
}

@test "format_project_suffixed_token: shell + camelCase" {
  result=$(format_project_suffixed_token shell camelCase my-project AFFINITY_COLOCATE_APP)
  [ "$result" = "\${myProjectAffinityColocateApp}" ]
}

@test "format_project_suffixed_token: helm + PascalCase" {
  result=$(format_project_suffixed_token helm PascalCase my-cool-service DATABASE_URL)
  [ "$result" = "{{ .Values.MyCoolServiceDatabaseUrl }}" ]
}

@test "format_project_suffixed_token: shell + lower_snake" {
  result=$(format_project_suffixed_token shell lower_snake my-project SOME_CONFIG)
  [ "$result" = "\${my_projectSomeConfig}" ]
}

@test "format_project_suffixed_token: suffix always PascalCase when joining" {
  # Even with camelCase, suffix joins with capital letter
  result=$(format_project_suffixed_token shell camelCase my-service CONFIG_VALUE)
  [ "$result" = "\${myServiceConfigValue}" ]
}

# --- Error cases ---

@test "format_project_suffixed_token: missing argument fails" {
  run format_project_suffixed_token shell PascalCase my-project
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 4 arguments"
}

@test "format_project_suffixed_token: empty project name fails" {
  run format_project_suffixed_token shell PascalCase "" SOME_SUFFIX
  [ "$status" -ne 0 ]
}

@test "format_project_suffixed_token: empty suffix fails" {
  run format_project_suffixed_token shell PascalCase my-project ""
  [ "$status" -ne 0 ]
}

@test "format_project_suffixed_token: invalid delimiter style fails" {
  run format_project_suffixed_token invalid PascalCase my-project SOME_SUFFIX
  [ "$status" -ne 0 ]
}

@test "format_project_suffixed_token: invalid name style fails" {
  run format_project_suffixed_token shell InvalidStyle my-project SOME_SUFFIX
  [ "$status" -ne 0 ]
}

# =============================================================================
# Argument count validation tests
# =============================================================================

@test "is_valid_token_name_style: wrong arg count fails" {
  run is_valid_token_name_style
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 1 argument"
}

@test "is_valid_substitution_token_style: wrong arg count fails" {
  run is_valid_substitution_token_style
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 1 argument"
}

@test "convert_token_name: wrong arg count fails" {
  run convert_token_name PascalCase
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 2 arguments"
}

@test "format_token_reference: wrong arg count fails" {
  run format_token_reference shell
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 2 arguments"
}

@test "format_canonical_token: wrong arg count fails" {
  run format_canonical_token shell PascalCase
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 3 arguments"
}

@test "convert_kebab_name: wrong arg count fails" {
  run convert_kebab_name PascalCase
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 2 arguments"
}

@test "format_project_suffixed_token: wrong arg count fails" {
  run format_project_suffixed_token shell PascalCase my-project
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 4 arguments"
}

# =============================================================================
# validate_token_styles tests - combined validation with exit
# =============================================================================

@test "validate_token_styles: passes with valid styles" {
  TOKEN_NAME_STYLE="PascalCase"
  TOKEN_DELIMITER_STYLE="shell"
  run validate_token_styles
  [ "$status" -eq 0 ]
}

@test "validate_token_styles: exits 2 for invalid name style" {
  TOKEN_NAME_STYLE="InvalidStyle"
  TOKEN_DELIMITER_STYLE="shell"
  run validate_token_styles
  [ "$status" -eq 2 ]
  assert_output_contains "Unknown token name style"
}

@test "validate_token_styles: exits 3 for invalid delimiter style" {
  TOKEN_NAME_STYLE="PascalCase"
  TOKEN_DELIMITER_STYLE="invalid-delim"
  run validate_token_styles
  [ "$status" -eq 3 ]
  assert_output_contains "Unknown substitution token style"
}

@test "validate_token_styles: checks name style first" {
  TOKEN_NAME_STYLE="InvalidStyle"
  TOKEN_DELIMITER_STYLE="invalid-delim"
  run validate_token_styles
  [ "$status" -eq 2 ]
}

@test "validate_token_styles: formats errors through log provider" {
  TOKEN_NAME_STYLE="InvalidStyle"
  TOKEN_DELIMITER_STYLE="shell"
  run validate_token_styles
  [ "$status" -eq 2 ]
  assert_output_contains "ERROR: "
}

# =============================================================================
# unresolved_token_regex tests - grep-E regex for detecting leftover tokens
# =============================================================================

# --- shell delimiter style ---

@test "unresolved_token_regex: shell + PascalCase matches token" {
  pattern=$(unresolved_token_regex shell PascalCase)
  echo '${ProjectName}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + PascalCase rejects plain text" {
  pattern=$(unresolved_token_regex shell PascalCase)
  ! echo 'my-actual-project' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + PascalCase rejects lowercase start" {
  pattern=$(unresolved_token_regex shell PascalCase)
  ! echo '${projectName}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + UPPER_SNAKE matches token" {
  pattern=$(unresolved_token_regex shell UPPER_SNAKE)
  echo '${PROJECT_NAME}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + UPPER_SNAKE rejects lowercase" {
  pattern=$(unresolved_token_regex shell UPPER_SNAKE)
  ! echo '${project_name}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + camelCase matches token" {
  pattern=$(unresolved_token_regex shell camelCase)
  echo '${projectName}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + camelCase rejects uppercase start" {
  pattern=$(unresolved_token_regex shell camelCase)
  ! echo '${ProjectName}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + lower_snake matches token" {
  pattern=$(unresolved_token_regex shell lower_snake)
  echo '${project_name}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + lower-kebab matches token" {
  pattern=$(unresolved_token_regex shell lower-kebab)
  echo '${project-name}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + UPPER-KEBAB matches token" {
  pattern=$(unresolved_token_regex shell UPPER-KEBAB)
  echo '${PROJECT-NAME}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + lower.dot matches token" {
  pattern=$(unresolved_token_regex shell lower.dot)
  echo '${project.name}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + UPPER.DOT matches token" {
  pattern=$(unresolved_token_regex shell UPPER.DOT)
  echo '${PROJECT.NAME}' | grep -Eq "$pattern"
}

# --- mustache delimiter style ---

@test "unresolved_token_regex: mustache + PascalCase matches token" {
  pattern=$(unresolved_token_regex mustache PascalCase)
  echo '{{ ProjectName }}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: mustache + PascalCase rejects plain text" {
  pattern=$(unresolved_token_regex mustache PascalCase)
  ! echo 'ProjectName' | grep -Eq "$pattern"
}

# --- helm delimiter style ---

@test "unresolved_token_regex: helm + PascalCase matches token" {
  pattern=$(unresolved_token_regex helm PascalCase)
  echo '{{ .Values.ProjectName }}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: helm + PascalCase rejects mustache without .Values" {
  pattern=$(unresolved_token_regex helm PascalCase)
  ! echo '{{ ProjectName }}' | grep -Eq "$pattern"
}

# --- erb delimiter style ---

@test "unresolved_token_regex: erb + PascalCase matches token" {
  pattern=$(unresolved_token_regex erb PascalCase)
  echo '<%= ProjectName %>' | grep -Eq "$pattern"
}

# --- github-actions delimiter style ---

@test "unresolved_token_regex: github-actions + PascalCase matches token" {
  pattern=$(unresolved_token_regex github-actions PascalCase)
  echo '${{ ProjectName }}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: github-actions + PascalCase rejects plain mustache" {
  pattern=$(unresolved_token_regex github-actions PascalCase)
  ! echo '{{ ProjectName }}' | grep -Eq "$pattern"
}

# --- blade delimiter style ---

@test "unresolved_token_regex: blade + PascalCase matches token" {
  pattern=$(unresolved_token_regex blade PascalCase)
  echo '{{ $ProjectName }}' | grep -Eq "$pattern"
}

# --- stringtemplate delimiter style ---

@test "unresolved_token_regex: stringtemplate + PascalCase matches token" {
  pattern=$(unresolved_token_regex stringtemplate PascalCase)
  echo '$ProjectName$' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: stringtemplate + PascalCase rejects shell style" {
  pattern=$(unresolved_token_regex stringtemplate PascalCase)
  ! echo '${ProjectName}' | grep -Eq "$pattern"
}

# --- ognl delimiter style ---

@test "unresolved_token_regex: ognl + PascalCase matches token" {
  pattern=$(unresolved_token_regex ognl PascalCase)
  echo '%{ProjectName}' | grep -Eq "$pattern"
}

# --- t4 delimiter style ---

@test "unresolved_token_regex: t4 + PascalCase matches token" {
  pattern=$(unresolved_token_regex t4 PascalCase)
  echo '<#= ProjectName #>' | grep -Eq "$pattern"
}

# --- swift delimiter style ---

@test "unresolved_token_regex: swift + PascalCase matches token" {
  pattern=$(unresolved_token_regex swift PascalCase)
  echo '\(ProjectName)' | grep -Eq "$pattern"
}

# --- Cross-style: regex only matches its own delimiter style ---

@test "unresolved_token_regex: shell regex does not match mustache tokens" {
  pattern=$(unresolved_token_regex shell PascalCase)
  ! echo '{{ ProjectName }}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: mustache regex does not match shell tokens" {
  pattern=$(unresolved_token_regex mustache PascalCase)
  ! echo '${ProjectName}' | grep -Eq "$pattern"
}

# --- Matches token embedded in a line ---

@test "unresolved_token_regex: shell + PascalCase matches token within yaml line" {
  pattern=$(unresolved_token_regex shell PascalCase)
  echo '  name: ${ProjectName}' | grep -Eq "$pattern"
}

@test "unresolved_token_regex: shell + PascalCase does not match substituted yaml line" {
  pattern=$(unresolved_token_regex shell PascalCase)
  ! echo '  name: my-actual-cluster' | grep -Eq "$pattern"
}

# --- format_canonical_token output matches unresolved_token_regex ---

@test "unresolved_token_regex: matches format_canonical_token output for shell + PascalCase" {
  token=$(format_canonical_token shell PascalCase PROJECT_NAME)
  pattern=$(unresolved_token_regex shell PascalCase)
  echo "$token" | grep -Eq "$pattern"
}

@test "unresolved_token_regex: matches format_canonical_token output for mustache + lower-kebab" {
  token=$(format_canonical_token mustache lower-kebab PROJECT_NAME)
  pattern=$(unresolved_token_regex mustache lower-kebab)
  echo "$token" | grep -Eq "$pattern"
}

@test "unresolved_token_regex: matches format_canonical_token output for helm + PascalCase" {
  token=$(format_canonical_token helm PascalCase DOCKER_IMAGE_NAME)
  pattern=$(unresolved_token_regex helm PascalCase)
  echo "$token" | grep -Eq "$pattern"
}

@test "unresolved_token_regex: matches format_canonical_token output for github-actions + lower.dot" {
  token=$(format_canonical_token github-actions lower.dot PROJECT_NAME)
  pattern=$(unresolved_token_regex github-actions lower.dot)
  echo "$token" | grep -Eq "$pattern"
}

@test "unresolved_token_regex: matches format_canonical_token output for blade + camelCase" {
  token=$(format_canonical_token blade camelCase DOCKER_TAG)
  pattern=$(unresolved_token_regex blade camelCase)
  echo "$token" | grep -Eq "$pattern"
}

@test "unresolved_token_regex: matches format_canonical_token output for stringtemplate + UPPER_SNAKE" {
  token=$(format_canonical_token stringtemplate UPPER_SNAKE PROJECT_NAME)
  pattern=$(unresolved_token_regex stringtemplate UPPER_SNAKE)
  echo "$token" | grep -Eq "$pattern"
}

@test "unresolved_token_regex: matches format_canonical_token output for ognl + PascalCase" {
  token=$(format_canonical_token ognl PascalCase VERSION)
  pattern=$(unresolved_token_regex ognl PascalCase)
  echo "$token" | grep -Eq "$pattern"
}

@test "unresolved_token_regex: matches format_canonical_token output for swift + UPPER-KEBAB" {
  token=$(format_canonical_token swift UPPER-KEBAB PROJECT_NAME)
  pattern=$(unresolved_token_regex swift UPPER-KEBAB)
  echo "$token" | grep -Eq "$pattern"
}

# --- Error cases ---

@test "unresolved_token_regex: unknown delimiter style fails" {
  run unresolved_token_regex unknown-style PascalCase
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown"
}

@test "unresolved_token_regex: unknown name style fails" {
  run unresolved_token_regex shell UnknownStyle
  [ "$status" -ne 0 ]
  assert_output_contains "Unknown"
}

@test "unresolved_token_regex: missing arguments fails" {
  run unresolved_token_regex shell
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 2 arguments"
}

@test "unresolved_token_regex: empty delimiter style fails" {
  run unresolved_token_regex "" PascalCase
  [ "$status" -ne 0 ]
}

@test "unresolved_token_regex: empty name style fails" {
  run unresolved_token_regex shell ""
  [ "$status" -ne 0 ]
}

# --- All style combinations produce output ---

@test "unresolved_token_regex: all delimiter styles produce valid regex" {
  for delim in shell mustache helm erb github-actions blade stringtemplate ognl t4 swift; do
    result=$(unresolved_token_regex "$delim" PascalCase)
    [ -n "$result" ] || { echo "Empty result for delimiter: $delim"; return 1; }
  done
}

@test "unresolved_token_regex: all name styles produce valid regex" {
  for name_style in PascalCase camelCase UPPER_SNAKE lower_snake lower-kebab UPPER-KEBAB lower.dot UPPER.DOT; do
    result=$(unresolved_token_regex shell "$name_style")
    [ -n "$result" ] || { echo "Empty result for name style: $name_style"; return 1; }
  done
}
