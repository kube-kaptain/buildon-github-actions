#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-pod-placement.bash - Library functions for pod placement configuration
#
# Handles tolerations, node selectors, DNS policy, and related pod scheduling concerns.
#
# Functions:
#   generate_tolerations   - Convert JSON tolerations to YAML
#   generate_node_selector - Generate nodeSelector from comma-separated key=value pairs
#   generate_dns_policy    - Generate dnsPolicy field
#

# generate_tolerations - Convert JSON tolerations to YAML and output with indentation
#
# Arguments:
#   $1 - indent_count: Number of spaces for indentation
#   $2 - tolerations_json: JSON array of tolerations (empty string = no output)
#
# Example:
#   generate_tolerations 6 '[{"operator":"Exists"}]'
# Output:
#       tolerations:
#       - operator: Exists
#
generate_tolerations() {
  local indent_count="$1"
  local tolerations_json="$2"

  [[ -z "${tolerations_json}" ]] && return 0

  local indent=""
  for ((i = 0; i < indent_count; i++)); do
    indent+=" "
  done

  echo "${indent}tolerations:"
  echo "${tolerations_json}" | yq -P '.' | while IFS= read -r line; do
    echo "${indent}${line}"
  done
}

# generate_node_selector - Generate nodeSelector from comma-separated key=value pairs
#
# Arguments:
#   $1 - indent_count: Number of spaces for indentation
#   $2 - node_selector: Comma-separated key=value pairs (empty string = no output)
#
# Example:
#   generate_node_selector 6 "disktype=ssd,zone=us-east-1a"
# Output:
#       nodeSelector:
#         disktype: "ssd"
#         zone: "us-east-1a"
#
generate_node_selector() {
  local indent_count="$1"
  local node_selector="$2"

  [[ -z "${node_selector}" ]] && return 0

  local indent=""
  for ((i = 0; i < indent_count; i++)); do
    indent+=" "
  done

  echo "${indent}nodeSelector:"
  IFS=',' read -ra selectors <<< "${node_selector}"
  for selector in "${selectors[@]}"; do
    local key="${selector%%=*}"
    local value="${selector#*=}"
    echo "${indent}  ${key}: \"${value}\""
  done
}

# generate_dns_policy - Generate dnsPolicy field
#
# Arguments:
#   $1 - indent_count: Number of spaces for indentation
#   $2 - dns_policy: DNS policy value (empty string = no output)
#
# Valid values: ClusterFirst, ClusterFirstWithHostNet, Default, None
#
# Example:
#   generate_dns_policy 6 "ClusterFirst"
# Output:
#       dnsPolicy: ClusterFirst
#
generate_dns_policy() {
  local indent_count="$1"
  local dns_policy="$2"

  [[ -z "${dns_policy}" ]] && return 0

  local indent=""
  for ((i = 0; i < indent_count; i++)); do
    indent+=" "
  done

  echo "${indent}dnsPolicy: ${dns_policy}"
}
