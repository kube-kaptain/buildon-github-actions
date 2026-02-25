#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Kubernetes metadata generation library
#
# Functions:
#   build_name_middle_fragment  - Build hyphen-prefixed name fragment from combined sub-path and suffix
#   build_resource_name         - Build full resource name from project token, path, suffix, and optional final suffix
#   build_output_filename       - Build output filename from directory, resource type, and optional suffix
#   ensure_manifest_output_dir  - Create and return manifest output directory path
#   generate_manifest_header    - Output apiVersion, kind, metadata.name (and optionally namespace)
#   merge_key_value_pairs       - Merge two comma-separated key=value lists (second overrides first)
#   generate_yaml_map           - Output YAML map block with configurable indentation
#   generate_metadata_map       - Convenience wrapper for metadata-level maps (2-space indent)
#   generate_metadata           - Build and output labels or annotations with standard kaptain values
#
# shellcheck disable=SC2154 # app_name, version_token, build_timestamp, script_name, project_name_token, default_container set by caller

# Build hyphen-prefixed name fragment from combined sub-path and suffix
# Usage: build_name_middle_fragment <combined_sub_path> <suffix>
# Output: echoes fragment (empty or hyphen-prefixed string)
# Examples:
#   "omg/wtf" "backend" → "-omg-wtf-backend"
#   "" "backend"        → "-backend"
#   "omg/wtf" ""        → "-omg-wtf"
#   "" ""               → (empty)
build_name_middle_fragment() {
  if [[ $# -ne 2 ]]; then
    log_error "build_name_middle_fragment requires 2 arguments, got $#"
    log "Usage: build_name_middle_fragment <combined_sub_path> <suffix>"
    return 1
  fi

  local combined_sub_path="$1"
  local suffix="$2"
  local result=""

  if [[ -n "${combined_sub_path}" ]]; then
    local combined_fragment="${combined_sub_path//\//-}"
    result="-${combined_fragment}"
  fi

  if [[ -n "${suffix}" ]]; then
    result="${result}-${suffix}"
  fi

  echo "${result}"
}

# Build full resource name from project token, path, suffix, and optional final suffix
# Usage: build_resource_name <project_name_token> <combined_sub_path> <suffix> [final_suffix]
# Output: echoes full resource name
# Examples:
#   "\${ProjectName}" "backend/redis" "cache" ""                  → "\${ProjectName}-backend-redis-cache"
#   "\${ProjectName}" "backend/redis" "cache" "configmap-checksum" → "\${ProjectName}-backend-redis-cache-configmap-checksum"
#   "\${ProjectName}" "" "worker" "secret-checksum"               → "\${ProjectName}-worker-secret-checksum"
#   "\${ProjectName}" "" "" "headless"                            → "\${ProjectName}-headless"
#   "\${ProjectName}" "" "" ""                                    → "\${ProjectName}"
build_resource_name() {
  if [[ $# -lt 3 || $# -gt 4 ]]; then
    log_error "build_resource_name requires 3-4 arguments, got $#"
    log "Usage: build_resource_name <project_name_token> <combined_sub_path> <suffix> [final_suffix]"
    return 1
  fi

  local project_name_token="$1"
  local combined_sub_path="$2"
  local suffix="$3"
  local final_suffix="${4:-}"

  local name_middle
  name_middle=$(build_name_middle_fragment "${combined_sub_path}" "${suffix}")

  if [[ -n "${final_suffix}" ]]; then
    echo "${project_name_token}${name_middle}-${final_suffix}"
  else
    echo "${project_name_token}${name_middle}"
  fi
}

# Build output filename from directory, kind, and optional suffix
# Usage: build_output_filename <sub_path> <kind> <suffix>
# Output: echoes full file path (kind is lowercased automatically)
# Examples:
#   "target/manifests/combined" "Deployment" "cache"  → "target/manifests/combined/deployment-cache.yaml"
#   "target/manifests/combined" "deployment" ""       → "target/manifests/combined/deployment.yaml"
#   "target/manifests/combined" "Service" "headless"  → "target/manifests/combined/service-headless.yaml"
#   "target/manifests/combined" "Secret" "db" "template.yaml" → "target/manifests/combined/secret-db.template.yaml"
build_output_filename() {
  if [[ $# -lt 3 || $# -gt 4 ]]; then
    log_error "build_output_filename requires 3-4 arguments, got $#"
    log "Usage: build_output_filename <sub_path> <kind> <suffix> [extension]"
    return 1
  fi

  local sub_path="$1"
  local kind="$2"
  local suffix="$3"
  local extension="${4:-yaml}"
  local lowercase_kind
  lowercase_kind=$(echo "${kind}" | tr '[:upper:]' '[:lower:]')

  if [[ -n "${suffix}" ]]; then
    echo "${sub_path}/${lowercase_kind}-${suffix}.${extension}"
  else
    echo "${sub_path}/${lowercase_kind}.${extension}"
  fi
}

# Create and return manifest output directory path
# Usage: ensure_manifest_output_dir <output_base_path> <combined_sub_path>
# Output: creates directory, echoes path
# Examples:
#   "target" "omg/wtf" → creates & echoes "target/manifests/combined/omg/wtf"
#   "target" ""        → creates & echoes "target/manifests/combined"
ensure_manifest_output_dir() {
  if [[ $# -ne 2 ]]; then
    log_error "ensure_manifest_output_dir requires 2 arguments, got $#"
    log "Usage: ensure_manifest_output_dir <output_base_path> <combined_sub_path>"
    return 1
  fi

  local output_base_path="$1"
  local combined_sub_path="$2"
  local output_dir

  if [[ -n "${combined_sub_path}" ]]; then
    output_dir="${output_base_path}/manifests/combined/${combined_sub_path}"
  else
    output_dir="${output_base_path}/manifests/combined"
  fi

  mkdir -p "${output_dir}"
  echo "${output_dir}"
}

# Generate manifest header (apiVersion, kind, metadata.name, optionally namespace)
# Usage: generate_manifest_header <apiVersion> <kind> <name> [namespace]
#   3 args: cluster-scoped resource (no namespace)
#   4 args: namespaced resource
generate_manifest_header() {
  if [[ $# -lt 3 || $# -gt 4 ]]; then
    log_error "generate_manifest_header requires 3 or 4 arguments"
    log "Usage: generate_manifest_header <apiVersion> <kind> <name> [namespace]"
    return 1
  fi

  local api_version="$1"
  local kind="$2"
  local name="$3"

  echo "apiVersion: ${api_version}"
  echo "kind: ${kind}"
  echo "metadata:"
  echo "  name: ${name}"

  if [[ $# -eq 4 ]]; then
    local namespace="$4"
    echo "  namespace: ${namespace}"
  fi
}

# Merge two comma-separated key=value lists (second overrides first)
# Usage: merge_key_value_pairs <base> <override>
# Output: merged comma-separated key=value string
merge_key_value_pairs() {
  local base="$1"
  local override="$2"

  # Validate pairs contain '=' (helper for early returns)
  local IFS=',' pair
  validate_pairs() {
    local pairs="$1"
    for pair in ${pairs}; do
      if [[ "${pair}" != *"="* ]]; then
        log_error "merge_key_value_pairs: pair '${pair}' must contain '='"
        return 1
      fi
    done
  }

  # Validate all non-empty inputs upfront
  [[ -n "${base}" ]] && { validate_pairs "${base}" || return 1; }
  [[ -n "${override}" ]] && { validate_pairs "${override}" || return 1; }

  # Handle empty inputs (already validated)
  if [[ -z "${base}" && -z "${override}" ]]; then
    echo ""
    return 0
  fi
  if [[ -z "${base}" ]]; then
    echo "${override}"
    return 0
  fi
  if [[ -z "${override}" ]]; then
    echo "${base}"
    return 0
  fi

  # Build associative-style merge using arrays (bash 3.2 compatible)
  # Parse base into parallel arrays
  local -a keys=()
  local -a values=()

  local IFS=','
  local pair key value i

  # Parse base pairs
  for pair in ${base}; do
    key="${pair%%=*}"
    value="${pair#*=}"
    keys+=("${key}")
    values+=("${value}")
  done

  # Parse override pairs, replacing or adding
  for pair in ${override}; do
    key="${pair%%=*}"
    value="${pair#*=}"

    # Check if key exists in base
    local found=false
    for i in "${!keys[@]}"; do
      if [[ "${keys[i]}" == "${key}" ]]; then
        values[i]="${value}"
        found=true
        break
      fi
    done

    # Add new key if not found
    if [[ "${found}" == "false" ]]; then
      keys+=("${key}")
      values+=("${value}")
    fi
  done

  # Rebuild output
  local result=""
  for i in "${!keys[@]}"; do
    if [[ -n "${result}" ]]; then
      result="${result},"
    fi
    result="${result}${keys[i]}=${values[i]}"
  done

  echo "${result}"
}

# Generate YAML map block with configurable indentation
# Usage: generate_yaml_map <indent_spaces> <field_name> <key=value,key=value,...>
# indent_spaces: number of leading spaces (e.g., 2 for metadata-level)
# Output: YAML block to stdout
generate_yaml_map() {
  local indent_spaces="$1"
  local field_name="$2"
  local pairs="$3"

  # Empty pairs = no output
  if [[ -z "${pairs}" ]]; then
    return 0
  fi

  # Generate leading spaces
  local leading_spaces=""
  local i
  for ((i = 0; i < indent_spaces; i++)); do
    leading_spaces="${leading_spaces} "
  done

  echo "${leading_spaces}${field_name}:"

  local IFS=','
  local pair key value
  local entry_indent="${leading_spaces}  "

  for pair in ${pairs}; do
    key="${pair%%=*}"
    value="${pair#*=}"
    echo "${entry_indent}${key}: ${value}"
  done
}

# Convenience wrapper for metadata-level maps (2-space indent)
# Usage: generate_metadata_map <field_name> <key=value,key=value,...>
generate_metadata_map() {
  local field_name="$1"
  local pairs="$2"

  generate_yaml_map 2 "${field_name}" "${pairs}"
}

# Build and output labels or annotations with standard kaptain values
# Usage: generate_metadata <indent> <labels|annotations> [default_container]
#
# Reads from caller's scope:
#   project_name_token  - Token for project name (e.g., ${ProjectName}) - used in kaptain/project-name annotation
#   app_name            - Full resource name for app labels (e.g., ${ProjectName}-backend-db)
#   version_token       - Token for version (e.g., ${Version})
#   build_timestamp     - ISO 8601 timestamp (annotations only)
#   script_name         - Generator script name (annotations only)
#   GLOBAL_LABELS       - Additional labels from global config (labels only)
#   SPECIFIC_LABELS     - Additional labels from resource config (labels only)
#   GLOBAL_ANNOTATIONS  - Additional annotations from global config (annotations only)
#   SPECIFIC_ANNOTATIONS - Additional annotations from resource config (annotations only)
#
# Arguments:
#   indent            - Number of leading spaces
#   type              - "labels" or "annotations"
#   default_container - Optional container name for kubectl.kubernetes.io/default-container
#
generate_metadata() {
  if [[ $# -lt 2 || $# -gt 3 ]]; then
    log_error "generate_metadata requires 2-3 arguments, got $#"
    log "Usage: generate_metadata <indent> <labels|annotations> [default_container]"
    return 1
  fi

  local indent="$1"
  local type="$2"
  local default_container="${3:-}"

  local builtin global specific merged

  case "${type}" in
    labels)
      builtin="app=${app_name},app.kubernetes.io/name=${app_name},app.kubernetes.io/version=\"${version_token}\",app.kubernetes.io/managed-by=Kaptain"
      global="${GLOBAL_LABELS:-}"
      specific="${SPECIFIC_LABELS:-}"
      ;;
    annotations)
      builtin="kaptain/project-name=${project_name_token},kaptain/version=\"${version_token}\",kaptain/build-timestamp=\"${build_timestamp}\",kaptain/generated-by=\"Generated by Kaptain ${script_name}\""
      if [[ -n "${default_container}" ]]; then
        builtin="${builtin},kubectl.kubernetes.io/default-container=${default_container}"
      fi
      global="${GLOBAL_ANNOTATIONS:-}"
      specific="${SPECIFIC_ANNOTATIONS:-}"
      ;;
    *)
      log_error "generate_metadata type must be 'labels' or 'annotations', got: ${type}"
      return 1
      ;;
  esac

  merged=$(merge_key_value_pairs "${builtin}" "${global}")
  merged=$(merge_key_value_pairs "${merged}" "${specific}")
  generate_yaml_map "${indent}" "${type}" "${merged}"
}

