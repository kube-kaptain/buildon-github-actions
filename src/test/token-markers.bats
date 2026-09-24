#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/token-markers.bash unmarked-token filters. Marker grammar is
# covered by convert-tokens-in-tree.bats and kubernetes-run-finalise.bats.

bats_require_minimum_version 1.5.0

load helpers

setup() {
  TEST_DIR=$(create_test_dir "token-markers")
  source "${LIB_DIR}/token-format.bash"
  source "${LIB_DIR}/token-markers.bash"
  REGEX=$(unresolved_token_regex shell PascalCase)
  cd "${TEST_DIR}"
}

teardown() {
  dump_bats_result
}

@test "file_unmarked_tokens: every token when the file has no markers" {
  printf 'a: ${One}\nb: ${Two}\n' > f.yaml
  run token_markers_file_unmarked_tokens IgnoreUnresolved f.yaml "${REGEX}" shell
  [ "$status" -eq 0 ]
  [ "$output" = $'One\nTwo' ]
}

@test "file_unmarked_tokens: a bare marker drops every token on its line" {
  printf 'a: ${One} ${Two} # IgnoreUnresolved\nb: ${Three}\n' > f.yaml
  run token_markers_file_unmarked_tokens IgnoreUnresolved f.yaml "${REGEX}" shell
  [ "$status" -eq 0 ]
  [ "$output" = "Three" ]
}

@test "file_unmarked_tokens: a specifier drops only the named token" {
  printf 'a: ${One} ${Two} # IgnoreUnresolved: ${One}\n' > f.yaml
  run token_markers_file_unmarked_tokens IgnoreUnresolved f.yaml "${REGEX}" shell
  [ "$status" -eq 0 ]
  [ "$output" = "Two" ]
}

@test "file_unmarked_tokens: a Below marker covers the next line only" {
  printf '# IgnoreUnresolvedBelow\na: ${One}\nb: ${Two}\n' > f.yaml
  run token_markers_file_unmarked_tokens IgnoreUnresolved f.yaml "${REGEX}" shell
  [ "$status" -eq 0 ]
  [ "$output" = "Two" ]
}

@test "file_unmarked_tokens: matches are sorted before delimiters are stripped" {
  # ${Ab} sorts before ${A} as delimited text; callers hash in this order.
  printf 'x: ${A}\ny: ${Ab}\n' > f.yaml
  run token_markers_file_unmarked_tokens IgnoreUnresolved f.yaml "${REGEX}" shell
  [ "$status" -eq 0 ]
  [ "$output" = $'Ab\nA' ]
}

@test "unmarked_tokens: records for another file are not applied" {
  printf 'a: ${One}\n' > f.yaml
  printf 'other.yaml\t1\t*\n' > records.tsv
  run token_markers_unmarked_tokens f.yaml f.yaml "${REGEX}" records.tsv shell
  [ "$status" -eq 0 ]
  [ "$output" = "One" ]
}
