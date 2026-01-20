#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for pod-placement-strategy plugin scripts

load helpers

PLUGIN_DIR="$PROJECT_ROOT/src/scripts/plugins/pod-placement-strategy"

# =============================================================================
# none strategy
# =============================================================================

@test "pod-placement-strategy/none: outputs nothing" {
  run "$PLUGIN_DIR/none"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# spread-nodes strategy
# =============================================================================

@test "pod-placement-strategy/spread-nodes: requires APP_LABEL_VALUE" {
  run env -u APP_LABEL_VALUE "$PLUGIN_DIR/spread-nodes"
  [ "$status" -ne 0 ]
  assert_output_contains "APP_LABEL_VALUE is required"
}

@test "pod-placement-strategy/spread-nodes: basic output" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-nodes"
  [ "$status" -eq 0 ]
  assert_output_contains "affinity:"
  assert_output_contains "podAntiAffinity:"
  assert_output_contains "preferredDuringSchedulingIgnoredDuringExecution:"
  assert_output_contains "weight: 100"
  assert_output_contains 'app: ${ProjectName}'
  assert_output_contains "topologyKey: kubernetes.io/hostname"
}

@test "pod-placement-strategy/spread-nodes: uses provided label value" {
  run env APP_LABEL_VALUE='${ProjectName}-backend-redis-cache' "$PLUGIN_DIR/spread-nodes"
  [ "$status" -eq 0 ]
  assert_output_contains 'app: ${ProjectName}-backend-redis-cache'
}

@test "pod-placement-strategy/spread-nodes: respects POD_PLACEMENT_INDENT" {
  run env APP_LABEL_VALUE='${ProjectName}' POD_PLACEMENT_INDENT=4 "$PLUGIN_DIR/spread-nodes"
  [ "$status" -eq 0 ]
  assert_output_contains "    affinity:"
}

# =============================================================================
# spread-zones strategy
# =============================================================================

@test "pod-placement-strategy/spread-zones: requires APP_LABEL_VALUE" {
  run env -u APP_LABEL_VALUE "$PLUGIN_DIR/spread-zones"
  [ "$status" -ne 0 ]
  assert_output_contains "APP_LABEL_VALUE is required"
}

@test "pod-placement-strategy/spread-zones: basic output" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-zones"
  [ "$status" -eq 0 ]
  assert_output_contains "affinity:"
  assert_output_contains "podAntiAffinity:"
  assert_output_contains "preferredDuringSchedulingIgnoredDuringExecution:"
  assert_output_contains "weight: 100"
  assert_output_contains 'app: ${ProjectName}'
  assert_output_contains "topologyKey: topology.kubernetes.io/zone"
}

@test "pod-placement-strategy/spread-zones: uses zone topology key not hostname" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-zones"
  [ "$status" -eq 0 ]
  assert_output_contains "topology.kubernetes.io/zone"
  assert_output_not_contains "kubernetes.io/hostname"
}

# =============================================================================
# spread-nodes-and-zones-ha strategy
# =============================================================================

@test "pod-placement-strategy/spread-nodes-and-zones-ha: requires APP_LABEL_VALUE" {
  run env -u APP_LABEL_VALUE "$PLUGIN_DIR/spread-nodes-and-zones-ha"
  [ "$status" -ne 0 ]
  assert_output_contains "APP_LABEL_VALUE is required"
}

@test "pod-placement-strategy/spread-nodes-and-zones-ha: basic output" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-nodes-and-zones-ha"
  [ "$status" -eq 0 ]
  assert_output_contains "affinity:"
  assert_output_contains "podAntiAffinity:"
  assert_output_contains "preferredDuringSchedulingIgnoredDuringExecution:"
}

@test "pod-placement-strategy/spread-nodes-and-zones-ha: has node weight 100" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-nodes-and-zones-ha"
  [ "$status" -eq 0 ]
  assert_output_contains "weight: 100"
  assert_output_contains "kubernetes.io/hostname"
}

@test "pod-placement-strategy/spread-nodes-and-zones-ha: has zone weight 50" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-nodes-and-zones-ha"
  [ "$status" -eq 0 ]
  assert_output_contains "weight: 50"
  assert_output_contains "topology.kubernetes.io/zone"
}

@test "pod-placement-strategy/spread-nodes-and-zones-ha: both topology keys present" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-nodes-and-zones-ha"
  [ "$status" -eq 0 ]
  assert_output_contains "kubernetes.io/hostname"
  assert_output_contains "topology.kubernetes.io/zone"
}

# =============================================================================
# spread-nodes-required strategy
# =============================================================================

@test "pod-placement-strategy/spread-nodes-required: requires APP_LABEL_VALUE" {
  run env -u APP_LABEL_VALUE "$PLUGIN_DIR/spread-nodes-required"
  [ "$status" -ne 0 ]
  assert_output_contains "APP_LABEL_VALUE is required"
}

@test "pod-placement-strategy/spread-nodes-required: basic output" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-nodes-required"
  [ "$status" -eq 0 ]
  assert_output_contains "affinity:"
  assert_output_contains "podAntiAffinity:"
  assert_output_contains "requiredDuringSchedulingIgnoredDuringExecution:"
  assert_output_contains 'app: ${ProjectName}'
  assert_output_contains "topologyKey: kubernetes.io/hostname"
}

@test "pod-placement-strategy/spread-nodes-required: uses required not preferred" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-nodes-required"
  [ "$status" -eq 0 ]
  assert_output_contains "requiredDuringSchedulingIgnoredDuringExecution:"
  assert_output_not_contains "preferredDuringSchedulingIgnoredDuringExecution:"
  assert_output_not_contains "weight:"
}

# =============================================================================
# spread-zones-required strategy
# =============================================================================

@test "pod-placement-strategy/spread-zones-required: requires APP_LABEL_VALUE" {
  run env -u APP_LABEL_VALUE "$PLUGIN_DIR/spread-zones-required"
  [ "$status" -ne 0 ]
  assert_output_contains "APP_LABEL_VALUE is required"
}

@test "pod-placement-strategy/spread-zones-required: basic output" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-zones-required"
  [ "$status" -eq 0 ]
  assert_output_contains "affinity:"
  assert_output_contains "podAntiAffinity:"
  assert_output_contains "requiredDuringSchedulingIgnoredDuringExecution:"
  assert_output_contains 'app: ${ProjectName}'
  assert_output_contains "topologyKey: topology.kubernetes.io/zone"
}

@test "pod-placement-strategy/spread-zones-required: uses required not preferred" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-zones-required"
  [ "$status" -eq 0 ]
  assert_output_contains "requiredDuringSchedulingIgnoredDuringExecution:"
  assert_output_not_contains "preferredDuringSchedulingIgnoredDuringExecution:"
  assert_output_not_contains "weight:"
}

# =============================================================================
# colocate-app strategy (still uses token formatting for dynamic label)
# =============================================================================

@test "pod-placement-strategy/colocate-app: requires TOKEN_NAME_STYLE" {
  run env -u TOKEN_NAME_STYLE TOKEN_DELIMITER_STYLE=shell PROJECT_NAME=my-project "$PLUGIN_DIR/colocate-app"
  [ "$status" -ne 0 ]
  assert_output_contains "TOKEN_NAME_STYLE is required"
}

@test "pod-placement-strategy/colocate-app: requires TOKEN_DELIMITER_STYLE" {
  run env -u TOKEN_DELIMITER_STYLE TOKEN_NAME_STYLE=PascalCase PROJECT_NAME=my-project "$PLUGIN_DIR/colocate-app"
  [ "$status" -ne 0 ]
  assert_output_contains "TOKEN_DELIMITER_STYLE is required"
}

@test "pod-placement-strategy/colocate-app: requires PROJECT_NAME" {
  run env -u PROJECT_NAME TOKEN_NAME_STYLE=PascalCase TOKEN_DELIMITER_STYLE=shell "$PLUGIN_DIR/colocate-app"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME is required"
}

@test "pod-placement-strategy/colocate-app: shell + PascalCase output" {
  run env TOKEN_NAME_STYLE=PascalCase TOKEN_DELIMITER_STYLE=shell PROJECT_NAME=my-service "$PLUGIN_DIR/colocate-app"
  [ "$status" -eq 0 ]
  assert_output_contains "affinity:"
  assert_output_contains "podAffinity:"
  assert_output_contains "preferredDuringSchedulingIgnoredDuringExecution:"
  assert_output_contains "weight: 100"
  assert_output_contains 'app: ${MyServiceAffinityColocateApp}'
  assert_output_contains "topologyKey: kubernetes.io/hostname"
}

@test "pod-placement-strategy/colocate-app: uses podAffinity not podAntiAffinity" {
  run env TOKEN_NAME_STYLE=PascalCase TOKEN_DELIMITER_STYLE=shell PROJECT_NAME=my-service "$PLUGIN_DIR/colocate-app"
  [ "$status" -eq 0 ]
  assert_output_contains "podAffinity:"
  assert_output_not_contains "podAntiAffinity:"
}

@test "pod-placement-strategy/colocate-app: compound token with camelCase" {
  run env TOKEN_NAME_STYLE=camelCase TOKEN_DELIMITER_STYLE=mustache PROJECT_NAME=my-cool-service "$PLUGIN_DIR/colocate-app"
  [ "$status" -eq 0 ]
  assert_output_contains "app: {{ myCoolServiceAffinityColocateApp }}"
}

@test "pod-placement-strategy/colocate-app: compound token with helm style" {
  run env TOKEN_NAME_STYLE=PascalCase TOKEN_DELIMITER_STYLE=helm PROJECT_NAME=my-service "$PLUGIN_DIR/colocate-app"
  [ "$status" -eq 0 ]
  assert_output_contains "app: {{ .Values.MyServiceAffinityColocateApp }}"
}

# =============================================================================
# Indentation tests across strategies
# =============================================================================

@test "pod-placement-strategy: default indent is 0" {
  run env APP_LABEL_VALUE='${ProjectName}' "$PLUGIN_DIR/spread-nodes"
  [ "$status" -eq 0 ]
  # First line should start with "affinity:" at column 0
  first_line=$(echo "$output" | head -n1)
  [ "$first_line" = "affinity:" ]
}

@test "pod-placement-strategy: indent 6 for deployment embedding" {
  run env APP_LABEL_VALUE='${ProjectName}' POD_PLACEMENT_INDENT=6 "$PLUGIN_DIR/spread-nodes-and-zones-ha"
  [ "$status" -eq 0 ]
  first_line=$(echo "$output" | head -n1)
  [ "$first_line" = "      affinity:" ]
}

# =============================================================================
# Library functions (kubernetes-pod-placement.bash)
# =============================================================================

LIB_DIR="$PROJECT_ROOT/src/scripts/lib"

# Helper to source the library
source_lib() {
  source "$LIB_DIR/kubernetes-pod-placement.bash"
}

# --- generate_tolerations ---

@test "generate_tolerations: empty input produces no output" {
  source_lib
  run generate_tolerations 6 ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_tolerations: basic toleration" {
  source_lib
  run generate_tolerations 6 '[{"operator":"Exists"}]'
  [ "$status" -eq 0 ]
  assert_output_contains "tolerations:"
  assert_output_contains "operator: Exists"
}

@test "generate_tolerations: respects indent" {
  source_lib
  run generate_tolerations 4 '[{"operator":"Exists"}]'
  [ "$status" -eq 0 ]
  first_line=$(echo "$output" | head -n1)
  [ "$first_line" = "    tolerations:" ]
}

# --- generate_node_selector ---

@test "generate_node_selector: empty input produces no output" {
  source_lib
  run generate_node_selector 6 ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_node_selector: single selector" {
  source_lib
  run generate_node_selector 6 "disktype=ssd"
  [ "$status" -eq 0 ]
  assert_output_contains "nodeSelector:"
  assert_output_contains 'disktype: "ssd"'
}

@test "generate_node_selector: multiple selectors" {
  source_lib
  run generate_node_selector 6 "disktype=ssd,zone=us-east-1a"
  [ "$status" -eq 0 ]
  assert_output_contains "nodeSelector:"
  assert_output_contains 'disktype: "ssd"'
  assert_output_contains 'zone: "us-east-1a"'
}

@test "generate_node_selector: respects indent" {
  source_lib
  run generate_node_selector 4 "disktype=ssd"
  [ "$status" -eq 0 ]
  first_line=$(echo "$output" | head -n1)
  [ "$first_line" = "    nodeSelector:" ]
}

@test "generate_node_selector: handles dots in key" {
  source_lib
  run generate_node_selector 6 "node.kubernetes.io/instance-type=m5.large"
  [ "$status" -eq 0 ]
  assert_output_contains 'node.kubernetes.io/instance-type: "m5.large"'
}

# --- generate_dns_policy ---

@test "generate_dns_policy: empty input produces no output" {
  source_lib
  run generate_dns_policy 6 ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "generate_dns_policy: ClusterFirst" {
  source_lib
  run generate_dns_policy 6 "ClusterFirst"
  [ "$status" -eq 0 ]
  assert_output_contains "dnsPolicy: ClusterFirst"
}

@test "generate_dns_policy: ClusterFirstWithHostNet" {
  source_lib
  run generate_dns_policy 6 "ClusterFirstWithHostNet"
  [ "$status" -eq 0 ]
  assert_output_contains "dnsPolicy: ClusterFirstWithHostNet"
}

@test "generate_dns_policy: respects indent" {
  source_lib
  run generate_dns_policy 4 "None"
  [ "$status" -eq 0 ]
  [ "$output" = "    dnsPolicy: None" ]
}
