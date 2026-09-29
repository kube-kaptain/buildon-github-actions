#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for action template wiring
# Verifies that action templates have env mappings for all variables
# that the corresponding hook scripts export

bats_require_minimum_version 1.5.0

load helpers

ACTION_TEMPLATES_DIR="$PROJECT_ROOT/src/action-templates"

setup() {
  :
}

teardown() {
  dump_bats_result
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

# kubernetes-run-aggregate sources content-resolve, which requires
# SCHEMA_VALIDATION_COMMAND, so the step and the action must both carry it.
@test "kubernetes-run-aggregate step and action template wire the schema validator" {
  grep -Fq 'SCHEMA_VALIDATION_COMMAND: ${{ inputs.schema-validation-command }}' \
    "$ACTION_TEMPLATES_DIR/kubernetes-run-aggregate.yaml"
  grep -Fq '# INJECT-INPUT: schema-validation-command' \
    "$ACTION_TEMPLATES_DIR/kubernetes-run-aggregate.yaml"
  grep -Fq 'schema-validation-command: ${{ steps.validate-tooling.outputs.SCHEMA_VALIDATION_COMMAND }}' \
    "$PROJECT_ROOT/src/steps-common/run-aggregate.yaml"
}
