#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/builtin-tokens-from-entry.bash
#
# Covers slug derivation from entry-as-written, file emission of the three
# auto-builtin tokens per entry (_REF, _VERSION_SPEC, _VERSION), prefix
# derivation from subdir, and input validation.

bats_require_minimum_version 1.5.0

load helpers

setup() {
  source "$LIB_DIR/builtin-tokens-from-entry.bash"
  OUTPUT_SUB_PATH=$(create_test_dir "builtin-tokens-out")
  export OUTPUT_SUB_PATH
  CONTENTS_DIR="$OUTPUT_SUB_PATH/builtin-resolved-tokens/contents"
  TEMPLATES_DIR="$OUTPUT_SUB_PATH/builtin-resolved-tokens/templates"
  LAYERS_DIR="$OUTPUT_SUB_PATH/builtin-resolved-tokens/layers"
}

teardown() {
  dump_bats_result
}

# Read a token file's exact contents (no trailing newline expected).
read_token() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "MISSING: $file" >&3
    return 1
  fi
  cat "$file"
}

# =============================================================================
# Slug derivation: simple short form
# =============================================================================

@test "short form: app-foo:1.2.3 -> CONTENT_APP_FOO_*" {
  emit_builtin_tokens_for_entry "app-foo:1.2.3" "1.2.3" "contents"

  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_REF")" = "app-foo:1.2.3" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION_SPEC")" = "1.2.3" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION")" = "1.2.3" ]
}

@test "short form: single segment app:1.0 -> CONTENT_APP_*" {
  emit_builtin_tokens_for_entry "app:1.0" "1.0" "contents"

  [ -f "$CONTENTS_DIR/CONTENT_APP_REF" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_REF")" = "app:1.0" ]
}

# =============================================================================
# Slug derivation: full URI with dots and slashes
# =============================================================================

@test "long form: ghcr.io/org/group/projectname:1.2.3 -> CONTENT_GHCR_IO_ORG_GROUP_PROJECTNAME_*" {
  emit_builtin_tokens_for_entry \
    "ghcr.io/org/group/projectname:1.2.3" "1.2.3" "contents"

  [ -f "$CONTENTS_DIR/CONTENT_GHCR_IO_ORG_GROUP_PROJECTNAME_REF" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_GHCR_IO_ORG_GROUP_PROJECTNAME_VERSION")" = "1.2.3" ]
}

@test "long form: hyphenated last segment ghcr.io/org/app-foo:1.0 -> _APP_FOO_" {
  emit_builtin_tokens_for_entry \
    "ghcr.io/org/app-foo:1.0" "1.0" "contents"

  [ -f "$CONTENTS_DIR/CONTENT_GHCR_IO_ORG_APP_FOO_REF" ]
}

@test "long form: digit in segment api-2 -> API_2" {
  emit_builtin_tokens_for_entry \
    "ghcr.io/org/api-2:1.0" "1.0" "contents"

  [ -f "$CONTENTS_DIR/CONTENT_GHCR_IO_ORG_API_2_REF" ]
}

# =============================================================================
# Version spec: range syntax preserved verbatim
# =============================================================================

@test "version spec: bracketed range [1.2.3] preserved" {
  emit_builtin_tokens_for_entry "app-foo:[1.2.3]" "1.2.3" "contents"

  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION_SPEC")" = "[1.2.3]" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION")" = "1.2.3" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_REF")" = "app-foo:[1.2.3]" ]
}

@test "version spec: open range >=1.0.0 preserved" {
  emit_builtin_tokens_for_entry "app-foo:>=1.0.0" "1.4.2" "contents"

  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION_SPEC")" = ">=1.0.0" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION")" = "1.4.2" ]
}

@test "no version spec: app-foo without : -> empty VERSION_SPEC" {
  emit_builtin_tokens_for_entry "app-foo" "1.0.0" "contents"

  [ -f "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION_SPEC" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION_SPEC")" = "" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION")" = "1.0.0" ]
}

# =============================================================================
# Provider prefix stripped
# =============================================================================

@test "provider prefix: docker|app-foo:1.0 -> CONTENT_APP_FOO_*" {
  emit_builtin_tokens_for_entry "docker|app-foo:1.0" "1.0" "contents"

  [ -f "$CONTENTS_DIR/CONTENT_APP_FOO_REF" ]
  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_REF")" = "docker|app-foo:1.0" ]
}

# =============================================================================
# Prefix derivation from subdir
# =============================================================================

@test "subdir templates derives TEMPLATE_ prefix" {
  emit_builtin_tokens_for_entry "tpl-foo:1.0" "1.0" "templates"

  [ -f "$TEMPLATES_DIR/TEMPLATE_TPL_FOO_REF" ]
  [ -f "$TEMPLATES_DIR/TEMPLATE_TPL_FOO_VERSION_SPEC" ]
  [ -f "$TEMPLATES_DIR/TEMPLATE_TPL_FOO_VERSION" ]
}

@test "subdir layers derives LAYER_ prefix" {
  emit_builtin_tokens_for_entry "layer-foo:1.0" "1.0" "layers"

  [ -f "$LAYERS_DIR/LAYER_LAYER_FOO_REF" ]
}

@test "layerset entry distinct from layer entry under same LAYER_ prefix" {
  emit_builtin_tokens_for_entry "layerset-foo:1.0" "1.0" "layers"
  emit_builtin_tokens_for_entry "layer-foo:1.0" "1.0" "layers"

  [ -f "$LAYERS_DIR/LAYER_LAYER_FOO_REF" ]
  [ -f "$LAYERS_DIR/LAYER_LAYERSET_FOO_REF" ]
}

@test "subdir routes files to its own dir and prefix" {
  emit_builtin_tokens_for_entry "app-foo:1.0" "1.0" "contents"
  emit_builtin_tokens_for_entry "tpl-foo:1.0" "1.0" "templates"

  [ -f "$CONTENTS_DIR/CONTENT_APP_FOO_REF" ]
  [ -f "$TEMPLATES_DIR/TEMPLATE_TPL_FOO_REF" ]
  [ ! -f "$CONTENTS_DIR/TEMPLATE_TPL_FOO_REF" ]
  [ ! -f "$TEMPLATES_DIR/CONTENT_APP_FOO_REF" ]
}

# =============================================================================
# REF is verbatim (preserves original syntax)
# =============================================================================

@test "REF: verbatim, includes provider prefix and version spec" {
  emit_builtin_tokens_for_entry "docker|app-foo:[1.2.3]" "1.2.3" "contents"

  [ "$(read_token "$CONTENTS_DIR/CONTENT_APP_FOO_REF")" = "docker|app-foo:[1.2.3]" ]
}

# =============================================================================
# Files have no trailing newline
# =============================================================================

@test "no trailing newline on emitted files" {
  emit_builtin_tokens_for_entry "app-foo:1.0" "1.0" "contents"

  # Each file's size should equal its content length, no trailing \n.
  local ref_size version_size
  ref_size=$(wc -c < "$CONTENTS_DIR/CONTENT_APP_FOO_REF" | tr -d ' ')
  version_size=$(wc -c < "$CONTENTS_DIR/CONTENT_APP_FOO_VERSION" | tr -d ' ')
  [ "$ref_size" = "11" ]      # "app-foo:1.0"
  [ "$version_size" = "3" ]   # "1.0"
}

# =============================================================================
# Input validation
# =============================================================================

@test "fails on wrong arg count" {
  run emit_builtin_tokens_for_entry "app:1.0" "1.0"
  [ "$status" -ne 0 ]
}

@test "fails on empty entry" {
  run emit_builtin_tokens_for_entry "" "1.0" "contents"
  [ "$status" -ne 0 ]
}

@test "fails on empty subdir" {
  run emit_builtin_tokens_for_entry "app:1.0" "1.0" ""
  [ "$status" -ne 0 ]
}

@test "fails when OUTPUT_SUB_PATH is unset" {
  unset OUTPUT_SUB_PATH
  run emit_builtin_tokens_for_entry "app:1.0" "1.0" "contents"
  [ "$status" -ne 0 ]
}

@test "fails on entry with no path before version" {
  run emit_builtin_tokens_for_entry ":1.0" "1.0" "contents"
  [ "$status" -ne 0 ]
}

@test "creates out_dir if missing" {
  # Fresh OUTPUT_SUB_PATH with no pre-existing builtin-resolved-tokens tree.
  [ ! -d "$CONTENTS_DIR" ]
  emit_builtin_tokens_for_entry "app-foo:1.0" "1.0" "contents"

  [ -f "$CONTENTS_DIR/CONTENT_APP_FOO_REF" ]
}
