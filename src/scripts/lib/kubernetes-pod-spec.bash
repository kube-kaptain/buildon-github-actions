#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# kubernetes-pod-spec.bash - Pod spec generation for workload manifests
#
# Functions for generating pod spec YAML blocks used by Deployment, StatefulSet,
# DaemonSet, Job, and CronJob generators.
#
# Functions:
#   generate_pod_security_context       - Pod-level security context
#   generate_container_security_context - Container-level security context
#   generate_container_resources        - Resource requests and limits
#   generate_container_ports            - Container port definitions
#   generate_container_lifecycle        - Lifecycle hooks (preStop)
#   generate_container_env_from_directory - Environment variables from file directory
#   generate_container_env_refs         - Environment variables from ConfigMap/Secret key refs
#   generate_container_env_all          - All env vars (plain + configmap refs + secret refs)
#   generate_configmap_secret_volume_mounts - Volume mounts for ConfigMap/Secret
#   generate_configmap_secret_volumes   - Volume definitions for ConfigMap/Secret
#   generate_image_pull_secrets         - Image pull secrets block
#   generate_service_account_config     - ServiceAccount name and automount token
#   generate_container_start            - Container name, image, imagePullPolicy

# Build indentation string
# Usage: _pod_spec_indent <spaces>
_pod_spec_indent() {
  local count="$1"
  local indent=""
  for ((i = 0; i < count; i++)); do
    indent+=" "
  done
  echo "$indent"
}

# Generate pod-level security context
# Usage: generate_pod_security_context <indent> <seccomp_profile>
#   seccomp_profile: DISABLED, RuntimeDefault, Localhost, or Unconfined
generate_pod_security_context() {
  if [[ $# -ne 2 ]]; then
    echo "Error: generate_pod_security_context requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local seccomp_profile="$2"

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}securityContext:"
  echo "${indent}  runAsNonRoot: true"
  if [[ "${seccomp_profile}" != "DISABLED" ]]; then
    echo "${indent}  seccompProfile:"
    echo "${indent}    type: ${seccomp_profile}"
  fi
}

# Generate container-level security context
# Usage: generate_container_security_context <indent> <readonly_root_filesystem>
generate_container_security_context() {
  if [[ $# -ne 2 ]]; then
    echo "Error: generate_container_security_context requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local readonly_root_filesystem="$2"

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}securityContext:"
  echo "${indent}  allowPrivilegeEscalation: false"
  echo "${indent}  readOnlyRootFilesystem: ${readonly_root_filesystem}"
  echo "${indent}  capabilities:"
  echo "${indent}    drop:"
  echo "${indent}      - ALL"
}

# Generate container resources block
# Usage: generate_container_resources <indent> <ephemeral_storage> <memory> <cpu_request> [cpu_limit]
#   cpu_limit is optional - omit for no CPU throttling
generate_container_resources() {
  if [[ $# -lt 4 || $# -gt 5 ]]; then
    echo "Error: generate_container_resources requires 4-5 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local ephemeral_storage="$2"
  local memory="$3"
  local cpu_request="$4"
  local cpu_limit="${5:-}"

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}resources:"
  echo "${indent}  requests:"
  echo "${indent}    ephemeral-storage: ${ephemeral_storage}"
  echo "${indent}    memory: ${memory}"
  echo "${indent}    cpu: ${cpu_request}"
  echo "${indent}  limits:"
  echo "${indent}    ephemeral-storage: ${ephemeral_storage}"
  echo "${indent}    memory: ${memory}"
  if [[ -n "${cpu_limit}" ]]; then
    echo "${indent}    cpu: ${cpu_limit}"
  fi
}

# Generate container ports block
# Usage: generate_container_ports <indent> <port> [protocol]
#   protocol defaults to TCP
generate_container_ports() {
  if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Error: generate_container_ports requires 2-3 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local port="$2"
  local protocol="${3:-TCP}"

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}ports:"
  echo "${indent}  - containerPort: ${port}"
  echo "${indent}    protocol: ${protocol}"
}

# Generate container lifecycle block with preStop hook
# Usage: generate_container_lifecycle <indent> <prestop_command>
#   Only generates output if prestop_command is non-empty
generate_container_lifecycle() {
  if [[ $# -ne 2 ]]; then
    echo "Error: generate_container_lifecycle requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local prestop_command="$2"

  # Only output if there's a command
  if [[ -z "${prestop_command}" ]]; then
    return 0
  fi

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}lifecycle:"
  echo "${indent}  preStop:"
  echo "${indent}    exec:"
  echo "${indent}      command:"
  echo "${indent}        - /bin/sh"
  echo "${indent}        - -c"
  echo "${indent}        - ${prestop_command}"
}

# Generate environment variables from a directory of files
# Usage: generate_container_env_from_directory <indent> <env_directory> [skip_header]
#   Each file in directory becomes an env var (filename=name, content=value)
#   Only generates output if directory exists and has files
#   skip_header: if "true", don't emit the "env:" header (for use with wrapper)
generate_container_env_from_directory() {
  if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Error: generate_container_env_from_directory requires 2-3 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local env_directory="$2"
  local skip_header="${3:-false}"

  # Check if directory exists and has files
  if [[ ! -d "${env_directory}" ]]; then
    return 0
  fi

  local file_count
  file_count=$(find "${env_directory}" -type f -not -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${file_count}" -eq 0 ]]; then
    return 0
  fi

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  if [[ "${skip_header}" != "true" ]]; then
    echo "${indent}env:"
  fi
  while IFS= read -r -d '' filepath; do
    local filename
    filename=$(basename "${filepath}")
    local content
    content=$(cat "${filepath}")
    echo "${indent}- name: ${filename}"
    echo "${indent}  value: \"${content}\""
  done < <(find "${env_directory}" -type f -not -name '.*' -print0 | sort -z)
}

# Generate environment variable refs from ConfigMap or Secret keys
# Usage: generate_container_env_refs <indent> <resource_type> <resource_file_path> <resource_name> <keys_list>
#   resource_type: "configmap" or "secret"
#   resource_file_path: path to the yaml file to validate keys against
#   resource_name: the name to use in configMapKeyRef/secretKeyRef
#   keys_list: comma or space separated list of keys
#   Only generates output if keys_list is non-empty
generate_container_env_refs() {
  if [[ $# -ne 5 ]]; then
    echo "Error: generate_container_env_refs requires exactly 5 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local resource_type="$2"
  local resource_file_path="$3"
  local resource_name="$4"
  local keys_list="$5"

  # Skip if no keys
  if [[ -z "${keys_list}" ]]; then
    return 0
  fi

  # Determine yq path and ref type based on resource type
  local yq_path ref_type
  case "${resource_type}" in
    configmap)
      yq_path=".data"
      ref_type="configMapKeyRef"
      ;;
    secret)
      yq_path=".stringData"
      ref_type="secretKeyRef"
      ;;
    *)
      echo "Error: resource_type must be 'configmap' or 'secret', got '${resource_type}'" >&2
      return 1
      ;;
  esac

  # Validate file exists
  if [[ ! -f "${resource_file_path}" ]]; then
    echo "Error: ${resource_type} file not found: ${resource_file_path}" >&2
    return 1
  fi

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  # Split keys on comma or space and process each
  local key
  for key in ${keys_list//,/ }; do
    # Skip empty keys (from multiple spaces/commas)
    [[ -z "${key}" ]] && continue

    # Validate key exists in the resource file
    local has_key
    has_key=$(yq "${yq_path} | has(\"${key}\")" "${resource_file_path}" 2>/dev/null)
    if [[ "${has_key}" != "true" ]]; then
      echo "Error: key '${key}' not found in ${resource_type} at ${yq_path} in ${resource_file_path}" >&2
      return 1
    fi

    # Generate the env entry with valueFrom
    echo "${indent}- name: ${key}"
    echo "${indent}  valueFrom:"
    echo "${indent}    ${ref_type}:"
    echo "${indent}      name: ${resource_name}"
    echo "${indent}      key: ${key}"
  done
}

# Generate all container environment variables (plain KVs + configmap refs + secret refs)
# Usage: generate_container_env_all <indent> <env_directory> \
#          <configmap_file> <configmap_name> <configmap_keys> \
#          <secret_file> <secret_name> <secret_keys>
#   Emits "env:" header only if there's at least one entry
#   Order: plain KVs, then configmap refs, then secret refs
generate_container_env_all() {
  if [[ $# -ne 8 ]]; then
    echo "Error: generate_container_env_all requires exactly 8 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local env_directory="$2"
  local configmap_file="$3"
  local configmap_name="$4"
  local configmap_keys="$5"
  local secret_file="$6"
  local secret_name="$7"
  local secret_keys="$8"

  # Check if there's anything to emit
  local has_plain_env=false
  if [[ -d "${env_directory}" ]]; then
    local file_count
    file_count=$(find "${env_directory}" -type f -not -name '.*' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${file_count}" -gt 0 ]]; then
      has_plain_env=true
    fi
  fi

  local has_configmap_keys=false
  if [[ -n "${configmap_keys}" && -f "${configmap_file}" ]]; then
    has_configmap_keys=true
  fi

  local has_secret_keys=false
  if [[ -n "${secret_keys}" && -f "${secret_file}" ]]; then
    has_secret_keys=true
  fi

  # Nothing to emit
  if [[ "${has_plain_env}" != "true" && "${has_configmap_keys}" != "true" && "${has_secret_keys}" != "true" ]]; then
    return 0
  fi

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  # Emit header once
  echo "${indent}env:"

  # Plain KVs (skip header since we emitted it)
  if [[ "${has_plain_env}" == "true" ]]; then
    generate_container_env_from_directory "$indent_count" "${env_directory}" true
  fi

  # ConfigMap refs
  if [[ "${has_configmap_keys}" == "true" ]]; then
    generate_container_env_refs "$indent_count" "configmap" "${configmap_file}" "${configmap_name}" "${configmap_keys}" || return 1
  fi

  # Secret refs
  if [[ "${has_secret_keys}" == "true" ]]; then
    generate_container_env_refs "$indent_count" "secret" "${secret_file}" "${secret_name}" "${secret_keys}" || return 1
  fi
}

# Generate volume mounts for ConfigMap and Secret
# Usage: generate_configmap_secret_volume_mounts <indent> <has_configmap> <has_secret> <configmap_mount_path> <secret_mount_path>
#   Only generates output if at least one of has_configmap or has_secret is true
generate_configmap_secret_volume_mounts() {
  if [[ $# -ne 5 ]]; then
    echo "Error: generate_configmap_secret_volume_mounts requires exactly 5 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local has_configmap="$2"
  local has_secret="$3"
  local configmap_mount_path="$4"
  local secret_mount_path="$5"

  # Only output if there's something to mount
  if [[ "${has_configmap}" != "true" ]] && [[ "${has_secret}" != "true" ]]; then
    return 0
  fi

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}volumeMounts:"
  if [[ "${has_configmap}" == "true" ]]; then
    echo "${indent}  - name: configmap"
    echo "${indent}    mountPath: ${configmap_mount_path}"
    echo "${indent}    readOnly: true"
  fi
  if [[ "${has_secret}" == "true" ]]; then
    echo "${indent}  - name: secret"
    echo "${indent}    mountPath: ${secret_mount_path}"
    echo "${indent}    readOnly: true"
  fi
}

# Generate volumes for ConfigMap and Secret
# Usage: generate_configmap_secret_volumes <indent> <has_configmap> <has_secret> <configmap_name> <secret_name>
#   Only generates output if at least one of has_configmap or has_secret is true
generate_configmap_secret_volumes() {
  if [[ $# -ne 5 ]]; then
    echo "Error: generate_configmap_secret_volumes requires exactly 5 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local has_configmap="$2"
  local has_secret="$3"
  local configmap_name="$4"
  local secret_name="$5"

  # Only output if there's something to define
  if [[ "${has_configmap}" != "true" ]] && [[ "${has_secret}" != "true" ]]; then
    return 0
  fi

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}volumes:"
  if [[ "${has_configmap}" == "true" ]]; then
    echo "${indent}  - name: configmap"
    echo "${indent}    configMap:"
    echo "${indent}      name: ${configmap_name}"
  fi
  if [[ "${has_secret}" == "true" ]]; then
    echo "${indent}  - name: secret"
    echo "${indent}    secret:"
    echo "${indent}      secretName: ${secret_name}"
  fi
}

# Generate image pull secrets
# Usage: generate_image_pull_secrets <indent> <secret_name>
generate_image_pull_secrets() {
  if [[ $# -ne 2 ]]; then
    echo "Error: generate_image_pull_secrets requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local secret_name="$2"

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}imagePullSecrets:"
  echo "${indent}  - name: ${secret_name}"
}

# Generate service account configuration
# Usage: generate_service_account_config <indent> <has_serviceaccount> <serviceaccount_name> <automount_token>
generate_service_account_config() {
  if [[ $# -ne 4 ]]; then
    echo "Error: generate_service_account_config requires exactly 4 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local has_serviceaccount="$2"
  local serviceaccount_name="$3"
  local automount_token="$4"

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  if [[ "${has_serviceaccount}" == "true" ]]; then
    echo "${indent}serviceAccountName: ${serviceaccount_name}"
  fi
  echo "${indent}automountServiceAccountToken: ${automount_token}"
}

# Generate container start (name, image, imagePullPolicy)
# Usage: generate_container_start <indent> <container_name> <image_reference> [image_pull_policy]
#   image_pull_policy defaults to IfNotPresent
generate_container_start() {
  if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo "Error: generate_container_start requires 3-4 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local container_name="$2"
  local image_reference="$3"
  local image_pull_policy="${4:-IfNotPresent}"

  local indent
  indent=$(_pod_spec_indent "$indent_count")

  echo "${indent}- name: ${container_name}"
  echo "${indent}  image: ${image_reference}"
  echo "${indent}  imagePullPolicy: ${image_pull_policy}"
}
