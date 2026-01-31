#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for action template wiring
# Verifies that action templates have env mappings for all variables
# that the corresponding hook scripts export

load helpers

ACTION_TEMPLATES_DIR="$PROJECT_ROOT/src/action-templates"

setup() {
  :
}

teardown() {
  :
}

@test "hook-post-docker-tests action template wires all hook exports" {
  run verify_action_template_env_mappings \
    "$ACTION_TEMPLATES_DIR/hook-post-docker-tests.yaml" \
    "$SCRIPTS_DIR/hook-post-docker-tests"
  if [[ "$status" -ne 0 ]]; then
    echo "$output" >&3
    return 1
  fi
}

@test "hook-pre-docker-prepare action template wires all hook exports" {
  run verify_action_template_env_mappings \
    "$ACTION_TEMPLATES_DIR/hook-pre-docker-prepare.yaml" \
    "$SCRIPTS_DIR/hook-pre-docker-prepare"
  if [[ "$status" -ne 0 ]]; then
    echo "$output" >&3
    return 1
  fi
}

@test "hook-pre-tagging-tests action template wires all hook exports" {
  run verify_action_template_env_mappings \
    "$ACTION_TEMPLATES_DIR/hook-pre-tagging-tests.yaml" \
    "$SCRIPTS_DIR/hook-pre-tagging-tests"
  if [[ "$status" -ne 0 ]]; then
    echo "$output" >&3
    return 1
  fi
}

@test "hook-pre-package-prepare action template wires all hook exports" {
  run verify_action_template_env_mappings \
    "$ACTION_TEMPLATES_DIR/hook-pre-package-prepare.yaml" \
    "$SCRIPTS_DIR/hook-pre-package-prepare"
  if [[ "$status" -ne 0 ]]; then
    echo "$output" >&3
    return 1
  fi
}

@test "hook-post-package-tests action template wires all hook exports" {
  run verify_action_template_env_mappings \
    "$ACTION_TEMPLATES_DIR/hook-post-package-tests.yaml" \
    "$SCRIPTS_DIR/hook-post-package-tests"
  if [[ "$status" -ne 0 ]]; then
    echo "$output" >&3
    return 1
  fi
}
