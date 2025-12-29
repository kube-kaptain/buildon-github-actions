#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Performance tests for substitute-tokens-from-dir
#
# This file is in src/test/performance/ and is NOT run by default.
# run-tests.bash only runs src/test/*.bats
#
# To run manually:
#   bats src/test/performance/substitute-tokens-from-dir.bats
#
# Test scenario: 50 config tokens, 250 manifest files, average 10 tokens per manifest

load ../helpers

setup() {
  export TOKENS_DIR=$(mktemp -d)
  export TARGET_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TOKENS_DIR"
  rm -rf "$TARGET_DIR"
}

@test "performance: 50 tokens, 250 files, ~10 tokens each" {
  # Create 50 tokens
  for i in $(seq 1 50); do
    printf "value-for-token-%d" "$i" > "$TOKENS_DIR/Token$i"
  done

  # Create 250 manifest files with ~10 tokens each
  for i in $(seq 1 250); do
    local content="apiVersion: v1
kind: ConfigMap
metadata:
  name: manifest-$i
data:"
    # Add ~10 token references (cycling through tokens 1-50)
    for j in $(seq 1 10); do
      local token_num=$(( (i + j) % 50 + 1 ))
      content="$content
  key$j: \${Token$token_num}"
    done
    printf '%s\n' "$content" > "$TARGET_DIR/manifest-$i.yaml"
  done

  # Time the substitution
  local start_time end_time elapsed
  start_time=$(date +%s.%N)

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"

  end_time=$(date +%s.%N)
  elapsed=$(echo "$end_time - $start_time" | bc)

  [ "$status" -eq 0 ]

  # Report timing
  echo "# Performance test completed in ${elapsed}s" >&3
  echo "# Tokens: 50, Files: 250, ~Tokens per file: 10" >&3
  echo "# Total substitutions: ~2500" >&3

  # Verify substitutions happened
  local sample_content
  sample_content=$(cat "$TARGET_DIR/manifest-1.yaml")
  [[ "$sample_content" == *"value-for-token-"* ]]
}

@test "performance: report baseline metrics" {
  # Create 10 tokens
  for i in $(seq 1 10); do
    printf "value-%d" "$i" > "$TOKENS_DIR/Token$i"
  done

  # Create 100 files with 5 tokens each
  for i in $(seq 1 100); do
    printf 'a: ${Token1}\nb: ${Token2}\nc: ${Token3}\nd: ${Token4}\ne: ${Token5}\n' > "$TARGET_DIR/file-$i.yaml"
  done

  local start_time end_time elapsed
  start_time=$(date +%s.%N)

  run "$SCRIPTS_DIR/substitute-tokens-from-dir" shell "$TOKENS_DIR" "$TARGET_DIR"

  end_time=$(date +%s.%N)
  elapsed=$(echo "$end_time - $start_time" | bc)

  [ "$status" -eq 0 ]

  echo "# Baseline: 10 tokens, 100 files, 5 tokens each = 500 subs in ${elapsed}s" >&3
}
