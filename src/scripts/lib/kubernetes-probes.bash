#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Kubernetes probes library
#
# Functions for generating health probe YAML blocks for Deployment, StatefulSet, etc.
# Supports HTTP GET, TCP socket, exec, and gRPC check types.
#
# Functions:
#   generate_probe            - Generate complete probe block
#   generate_workload_probes  - Generate all three probes for a workload
#   probe_check_http_get      - Generate HTTP GET check
#   probe_check_tcp_socket    - Generate TCP socket check
#   probe_check_exec          - Generate exec check (wraps with /bin/sh -c)
#   probe_check_grpc          - Generate gRPC check
#   probe_timing_fields       - Generate common timing fields
#
# shellcheck disable=SC2154 # Probe variables (LIVENESS_*, READINESS_*, STARTUP_*, CONTAINER_PORT) set by caller

# Build indentation string
# Usage: build_indent <spaces>
build_indent() {
  local count="$1"
  local indent=""
  for ((i = 0; i < count; i++)); do
    indent+=" "
  done
  echo "${indent}"
}

# Generate HTTP GET check block
# Usage: probe_check_http_get <indent> <path> <port> <scheme>
probe_check_http_get() {
  if [[ $# -ne 4 ]]; then
    echo "Error: probe_check_http_get requires exactly 4 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local path="$2"
  local port="$3"
  local scheme="$4"

  local indent
  indent=$(build_indent "${indent_count}")

  echo "${indent}httpGet:"
  echo "${indent}  path: ${path}"
  echo "${indent}  port: ${port}"
  echo "${indent}  scheme: ${scheme}"
}

# Generate TCP socket check block
# Usage: probe_check_tcp_socket <indent> <port>
probe_check_tcp_socket() {
  if [[ $# -ne 2 ]]; then
    echo "Error: probe_check_tcp_socket requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local port="$2"

  local indent
  indent=$(build_indent "${indent_count}")

  echo "${indent}tcpSocket:"
  echo "${indent}  port: ${port}"
}

# Generate exec check block
# Usage: probe_check_exec <indent> <command>
# Command is wrapped with /bin/sh -c automatically
probe_check_exec() {
  if [[ $# -ne 2 ]]; then
    echo "Error: probe_check_exec requires exactly 2 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local command="$2"

  local indent
  indent=$(build_indent "${indent_count}")

  echo "${indent}exec:"
  echo "${indent}  command:"
  echo "${indent}    - /bin/sh"
  echo "${indent}    - -c"
  echo "${indent}    - ${command}"
}

# Generate gRPC check block
# Usage: probe_check_grpc <indent> <port> <service>
# Service is optional - if empty string, omitted from output
probe_check_grpc() {
  if [[ $# -ne 3 ]]; then
    echo "Error: probe_check_grpc requires exactly 3 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local port="$2"
  local service="$3"

  local indent
  indent=$(build_indent "${indent_count}")

  echo "${indent}grpc:"
  echo "${indent}  port: ${port}"
  if [[ -n "${service}" ]]; then
    echo "${indent}  service: ${service}"
  fi
}

# Generate common timing fields
# Usage: probe_timing_fields <indent> <initial_delay> <period> <timeout> <failure> [success] [termination_grace_period]
# success is optional - only include for readiness probes
# termination_grace_period is optional - only for liveness/startup probes (K8s 1.25+)
probe_timing_fields() {
  if [[ $# -lt 5 || $# -gt 7 ]]; then
    echo "Error: probe_timing_fields requires 5-7 arguments, got $#" >&2
    return 1
  fi

  local indent_count="$1"
  local initial_delay="$2"
  local period="$3"
  local timeout="$4"
  local failure="$5"
  local success="${6:-}"
  local termination_grace_period="${7:-}"

  local indent
  indent=$(build_indent "${indent_count}")

  echo "${indent}initialDelaySeconds: ${initial_delay}"
  echo "${indent}periodSeconds: ${period}"
  echo "${indent}timeoutSeconds: ${timeout}"
  echo "${indent}failureThreshold: ${failure}"
  if [[ -n "${success}" ]]; then
    echo "${indent}successThreshold: ${success}"
  fi
  if [[ -n "${termination_grace_period}" ]]; then
    echo "${indent}terminationGracePeriodSeconds: ${termination_grace_period}"
  fi
}

# Generate complete probe block
# Usage: generate_probe <probe_type> <check_type> <indent> <check_args...> -- <timing_args...>
#
# Arguments:
#   probe_type   - liveness, readiness, startup
#   check_type   - http-get, tcp-socket, exec, grpc
#   indent       - base indentation (spaces)
#   check_args   - arguments for check type function (varies by type)
#   --           - separator
#   timing_args  - initial_delay, period, timeout, failure, [5th_arg]
#                  For readiness: 5th arg is successThreshold (default 1)
#                  For liveness/startup: 5th arg is terminationGracePeriodSeconds (optional)
#
# Check type arguments:
#   http-get:   <path> <port> <scheme>
#   tcp-socket: <port>
#   exec:       <command>
#   grpc:       <port> <service>
#
# Example:
#   generate_probe liveness http-get 10 /health 8080 HTTP -- 10 10 5 3
#   generate_probe liveness http-get 10 /health 8080 HTTP -- 10 10 5 3 5
#   generate_probe readiness tcp-socket 10 5432 -- 5 5 3 3 2
#   generate_probe startup exec 10 "pg_isready -U postgres" -- 0 5 3 30
#
generate_probe() {
  if [[ $# -lt 5 ]]; then
    echo "Error: generate_probe requires at least 5 arguments" >&2
    return 1
  fi

  local probe_type="$1"
  local check_type="$2"
  local indent_count="$3"
  shift 3

  # Validate probe type
  case "${probe_type}" in
    liveness|readiness|startup) ;;
    *)
      echo "Error: invalid probe_type '${probe_type}', must be liveness, readiness, or startup" >&2
      return 1
      ;;
  esac

  # Validate check type
  case "${check_type}" in
    http-get|tcp-socket|exec|grpc) ;;
    *)
      echo "Error: invalid check_type '${check_type}', must be http-get, tcp-socket, exec, or grpc" >&2
      return 1
      ;;
  esac

  # Split args on --
  local check_args=()
  local timing_args=()
  local found_separator=false

  for arg in "$@"; do
    if [[ "${arg}" == "--" ]]; then
      found_separator=true
      continue
    fi
    if ${found_separator}; then
      timing_args+=("${arg}")
    else
      check_args+=("${arg}")
    fi
  done

  if ! ${found_separator}; then
    echo "Error: generate_probe requires -- separator between check args and timing args" >&2
    return 1
  fi

  local indent
  indent=$(build_indent "${indent_count}")
  local inner_indent=$((indent_count + 2))

  # Output probe type label
  echo "${indent}${probe_type}Probe:"

  # Output check block
  case "${check_type}" in
    http-get)
      if [[ ${#check_args[@]} -ne 3 ]]; then
        echo "Error: http-get requires 3 check args (path, port, scheme), got ${#check_args[@]}" >&2
        return 1
      fi
      probe_check_http_get "${inner_indent}" "${check_args[0]}" "${check_args[1]}" "${check_args[2]}"
      ;;
    tcp-socket)
      if [[ ${#check_args[@]} -ne 1 ]]; then
        echo "Error: tcp-socket requires 1 check arg (port), got ${#check_args[@]}" >&2
        return 1
      fi
      probe_check_tcp_socket "${inner_indent}" "${check_args[0]}"
      ;;
    exec)
      if [[ ${#check_args[@]} -ne 1 ]]; then
        echo "Error: exec requires 1 check arg (command), got ${#check_args[@]}" >&2
        return 1
      fi
      probe_check_exec "${inner_indent}" "${check_args[0]}"
      ;;
    grpc)
      if [[ ${#check_args[@]} -ne 2 ]]; then
        echo "Error: grpc requires 2 check args (port, service), got ${#check_args[@]}" >&2
        return 1
      fi
      probe_check_grpc "${inner_indent}" "${check_args[0]}" "${check_args[1]}"
      ;;
  esac

  # Validate timing args
  if [[ ${#timing_args[@]} -lt 4 ]]; then
    echo "Error: timing args require at least 4 values (initial_delay, period, timeout, failure), got ${#timing_args[@]}" >&2
    return 1
  fi

  # Determine success threshold and termination grace period based on probe type
  # K8s enforces successThreshold=1 for liveness and startup
  # terminationGracePeriodSeconds only applies to liveness and startup (K8s 1.25+)
  local success_threshold=""
  local termination_grace_period=""

  case "${probe_type}" in
    liveness|startup)
      success_threshold="1"
      # 5th arg (if present) is terminationGracePeriodSeconds
      if [[ ${#timing_args[@]} -ge 5 ]]; then
        termination_grace_period="${timing_args[4]}"
      fi
      ;;
    readiness)
      # Readiness can have custom successThreshold, no terminationGracePeriodSeconds
      if [[ ${#timing_args[@]} -ge 5 ]]; then
        success_threshold="${timing_args[4]}"
      else
        success_threshold="1"
      fi
      ;;
  esac

  # Output timing fields
  probe_timing_fields "${inner_indent}" "${timing_args[0]}" "${timing_args[1]}" "${timing_args[2]}" "${timing_args[3]}" "${success_threshold}" "${termination_grace_period}"
}

# Generate all three probes for a workload
# Usage: generate_workload_probes <indent>
#
# Reads from caller's scope:
#   CONTAINER_PORT - Default port for probes
#
#   Liveness: LIVENESS_CHECK_TYPE, LIVENESS_INITIAL_DELAY_SECONDS, LIVENESS_PERIOD_SECONDS,
#             LIVENESS_TIMEOUT_SECONDS, LIVENESS_FAILURE_THRESHOLD, LIVENESS_HTTP_PATH,
#             LIVENESS_HTTP_SCHEME, LIVENESS_TCP_PORT, LIVENESS_EXEC_COMMAND,
#             LIVENESS_GRPC_PORT, LIVENESS_GRPC_SERVICE, LIVENESS_TERMINATION_GRACE_PERIOD_SECONDS
#
#   Readiness: READINESS_CHECK_TYPE, READINESS_INITIAL_DELAY_SECONDS, READINESS_PERIOD_SECONDS,
#              READINESS_TIMEOUT_SECONDS, READINESS_FAILURE_THRESHOLD, READINESS_SUCCESS_THRESHOLD,
#              READINESS_HTTP_PATH, READINESS_HTTP_SCHEME, READINESS_TCP_PORT,
#              READINESS_EXEC_COMMAND, READINESS_GRPC_PORT, READINESS_GRPC_SERVICE
#
#   Startup: STARTUP_CHECK_TYPE, STARTUP_INITIAL_DELAY_SECONDS, STARTUP_PERIOD_SECONDS,
#            STARTUP_TIMEOUT_SECONDS, STARTUP_FAILURE_THRESHOLD, STARTUP_HTTP_PATH,
#            STARTUP_HTTP_SCHEME, STARTUP_TCP_PORT, STARTUP_EXEC_COMMAND,
#            STARTUP_GRPC_PORT, STARTUP_GRPC_SERVICE, STARTUP_TERMINATION_GRACE_PERIOD_SECONDS
#
generate_workload_probes() {
  local indent_count="$1"

  # === Validate required fields based on check type ===
  case "${LIVENESS_CHECK_TYPE}" in
    exec)
      if [[ -z "${LIVENESS_EXEC_COMMAND:-}" ]]; then
        echo "Error: Liveness probe type 'exec' requires LIVENESS_EXEC_COMMAND" >&2
        return 4
      fi
      ;;
    tcp-socket)
      if [[ -z "${LIVENESS_TCP_PORT:-}" ]]; then
        echo "Error: Liveness probe type 'tcp-socket' requires LIVENESS_TCP_PORT" >&2
        return 4
      fi
      ;;
    grpc)
      if [[ -z "${LIVENESS_GRPC_PORT:-}" ]]; then
        echo "Error: Liveness probe type 'grpc' requires LIVENESS_GRPC_PORT" >&2
        return 4
      fi
      ;;
  esac

  case "${READINESS_CHECK_TYPE}" in
    exec)
      if [[ -z "${READINESS_EXEC_COMMAND:-}" ]]; then
        echo "Error: Readiness probe type 'exec' requires READINESS_EXEC_COMMAND" >&2
        return 4
      fi
      ;;
    tcp-socket)
      if [[ -z "${READINESS_TCP_PORT:-}" ]]; then
        echo "Error: Readiness probe type 'tcp-socket' requires READINESS_TCP_PORT" >&2
        return 4
      fi
      ;;
    grpc)
      if [[ -z "${READINESS_GRPC_PORT:-}" ]]; then
        echo "Error: Readiness probe type 'grpc' requires READINESS_GRPC_PORT" >&2
        return 4
      fi
      ;;
  esac

  case "${STARTUP_CHECK_TYPE}" in
    exec)
      if [[ -z "${STARTUP_EXEC_COMMAND:-}" ]]; then
        echo "Error: Startup probe type 'exec' requires STARTUP_EXEC_COMMAND" >&2
        return 4
      fi
      ;;
    tcp-socket)
      if [[ -z "${STARTUP_TCP_PORT:-}" ]]; then
        echo "Error: Startup probe type 'tcp-socket' requires STARTUP_TCP_PORT" >&2
        return 4
      fi
      ;;
    grpc)
      if [[ -z "${STARTUP_GRPC_PORT:-}" ]]; then
        echo "Error: Startup probe type 'grpc' requires STARTUP_GRPC_PORT" >&2
        return 4
      fi
      ;;
  esac

  # === Liveness probe ===
  local liveness_timing_args=(
    "${LIVENESS_INITIAL_DELAY_SECONDS}"
    "${LIVENESS_PERIOD_SECONDS}"
    "${LIVENESS_TIMEOUT_SECONDS}"
    "${LIVENESS_FAILURE_THRESHOLD}"
  )
  if [[ -n "${LIVENESS_TERMINATION_GRACE_PERIOD_SECONDS:-}" ]]; then
    liveness_timing_args+=("${LIVENESS_TERMINATION_GRACE_PERIOD_SECONDS}")
  fi

  case "${LIVENESS_CHECK_TYPE}" in
    http-get)
      generate_probe liveness http-get "${indent_count}" "${LIVENESS_HTTP_PATH}" "${CONTAINER_PORT}" "${LIVENESS_HTTP_SCHEME}" -- "${liveness_timing_args[@]}"
      ;;
    tcp-socket)
      generate_probe liveness tcp-socket "${indent_count}" "${LIVENESS_TCP_PORT}" -- "${liveness_timing_args[@]}"
      ;;
    exec)
      generate_probe liveness exec "${indent_count}" "${LIVENESS_EXEC_COMMAND}" -- "${liveness_timing_args[@]}"
      ;;
    grpc)
      generate_probe liveness grpc "${indent_count}" "${LIVENESS_GRPC_PORT}" "${LIVENESS_GRPC_SERVICE}" -- "${liveness_timing_args[@]}"
      ;;
  esac

  # === Readiness probe ===
  local readiness_timing_args=(
    "${READINESS_INITIAL_DELAY_SECONDS}"
    "${READINESS_PERIOD_SECONDS}"
    "${READINESS_TIMEOUT_SECONDS}"
    "${READINESS_FAILURE_THRESHOLD}"
    "${READINESS_SUCCESS_THRESHOLD}"
  )

  case "${READINESS_CHECK_TYPE}" in
    http-get)
      generate_probe readiness http-get "${indent_count}" "${READINESS_HTTP_PATH}" "${CONTAINER_PORT}" "${READINESS_HTTP_SCHEME}" -- "${readiness_timing_args[@]}"
      ;;
    tcp-socket)
      generate_probe readiness tcp-socket "${indent_count}" "${READINESS_TCP_PORT}" -- "${readiness_timing_args[@]}"
      ;;
    exec)
      generate_probe readiness exec "${indent_count}" "${READINESS_EXEC_COMMAND}" -- "${readiness_timing_args[@]}"
      ;;
    grpc)
      generate_probe readiness grpc "${indent_count}" "${READINESS_GRPC_PORT}" "${READINESS_GRPC_SERVICE}" -- "${readiness_timing_args[@]}"
      ;;
  esac

  # === Startup probe ===
  local startup_timing_args=(
    "${STARTUP_INITIAL_DELAY_SECONDS}"
    "${STARTUP_PERIOD_SECONDS}"
    "${STARTUP_TIMEOUT_SECONDS}"
    "${STARTUP_FAILURE_THRESHOLD}"
  )
  if [[ -n "${STARTUP_TERMINATION_GRACE_PERIOD_SECONDS:-}" ]]; then
    startup_timing_args+=("${STARTUP_TERMINATION_GRACE_PERIOD_SECONDS}")
  fi

  case "${STARTUP_CHECK_TYPE}" in
    http-get)
      generate_probe startup http-get "${indent_count}" "${STARTUP_HTTP_PATH}" "${CONTAINER_PORT}" "${STARTUP_HTTP_SCHEME}" -- "${startup_timing_args[@]}"
      ;;
    tcp-socket)
      generate_probe startup tcp-socket "${indent_count}" "${STARTUP_TCP_PORT}" -- "${startup_timing_args[@]}"
      ;;
    exec)
      generate_probe startup exec "${indent_count}" "${STARTUP_EXEC_COMMAND}" -- "${startup_timing_args[@]}"
      ;;
    grpc)
      generate_probe startup grpc "${indent_count}" "${STARTUP_GRPC_PORT}" "${STARTUP_GRPC_SERVICE}" -- "${startup_timing_args[@]}"
      ;;
  esac
}

# Generate a single liveness probe using workload variables
# Usage: generate_liveness_probe <indent>
#
# Reads from caller's scope: CONTAINER_PORT, LIVENESS_* variables
generate_liveness_probe() {
  local indent_count="$1"

  # Validate required fields based on check type
  case "${LIVENESS_CHECK_TYPE}" in
    exec)
      if [[ -z "${LIVENESS_EXEC_COMMAND:-}" ]]; then
        echo "Error: Liveness probe type 'exec' requires LIVENESS_EXEC_COMMAND" >&2
        return 4
      fi
      ;;
    tcp-socket)
      if [[ -z "${LIVENESS_TCP_PORT:-}" ]]; then
        echo "Error: Liveness probe type 'tcp-socket' requires LIVENESS_TCP_PORT" >&2
        return 4
      fi
      ;;
    grpc)
      if [[ -z "${LIVENESS_GRPC_PORT:-}" ]]; then
        echo "Error: Liveness probe type 'grpc' requires LIVENESS_GRPC_PORT" >&2
        return 4
      fi
      ;;
  esac

  local liveness_timing_args=(
    "${LIVENESS_INITIAL_DELAY_SECONDS}"
    "${LIVENESS_PERIOD_SECONDS}"
    "${LIVENESS_TIMEOUT_SECONDS}"
    "${LIVENESS_FAILURE_THRESHOLD}"
  )
  if [[ -n "${LIVENESS_TERMINATION_GRACE_PERIOD_SECONDS:-}" ]]; then
    liveness_timing_args+=("${LIVENESS_TERMINATION_GRACE_PERIOD_SECONDS}")
  fi

  case "${LIVENESS_CHECK_TYPE}" in
    http-get)
      generate_probe liveness http-get "${indent_count}" "${LIVENESS_HTTP_PATH}" "${CONTAINER_PORT}" "${LIVENESS_HTTP_SCHEME}" -- "${liveness_timing_args[@]}"
      ;;
    tcp-socket)
      generate_probe liveness tcp-socket "${indent_count}" "${LIVENESS_TCP_PORT}" -- "${liveness_timing_args[@]}"
      ;;
    exec)
      generate_probe liveness exec "${indent_count}" "${LIVENESS_EXEC_COMMAND}" -- "${liveness_timing_args[@]}"
      ;;
    grpc)
      generate_probe liveness grpc "${indent_count}" "${LIVENESS_GRPC_PORT}" "${LIVENESS_GRPC_SERVICE}" -- "${liveness_timing_args[@]}"
      ;;
  esac
}

# Generate a single readiness probe using workload variables
# Usage: generate_readiness_probe <indent>
#
# Reads from caller's scope: CONTAINER_PORT, READINESS_* variables
generate_readiness_probe() {
  local indent_count="$1"

  # Validate required fields based on check type
  case "${READINESS_CHECK_TYPE}" in
    exec)
      if [[ -z "${READINESS_EXEC_COMMAND:-}" ]]; then
        echo "Error: Readiness probe type 'exec' requires READINESS_EXEC_COMMAND" >&2
        return 4
      fi
      ;;
    tcp-socket)
      if [[ -z "${READINESS_TCP_PORT:-}" ]]; then
        echo "Error: Readiness probe type 'tcp-socket' requires READINESS_TCP_PORT" >&2
        return 4
      fi
      ;;
    grpc)
      if [[ -z "${READINESS_GRPC_PORT:-}" ]]; then
        echo "Error: Readiness probe type 'grpc' requires READINESS_GRPC_PORT" >&2
        return 4
      fi
      ;;
  esac

  local readiness_timing_args=(
    "${READINESS_INITIAL_DELAY_SECONDS}"
    "${READINESS_PERIOD_SECONDS}"
    "${READINESS_TIMEOUT_SECONDS}"
    "${READINESS_FAILURE_THRESHOLD}"
    "${READINESS_SUCCESS_THRESHOLD}"
  )

  case "${READINESS_CHECK_TYPE}" in
    http-get)
      generate_probe readiness http-get "${indent_count}" "${READINESS_HTTP_PATH}" "${CONTAINER_PORT}" "${READINESS_HTTP_SCHEME}" -- "${readiness_timing_args[@]}"
      ;;
    tcp-socket)
      generate_probe readiness tcp-socket "${indent_count}" "${READINESS_TCP_PORT}" -- "${readiness_timing_args[@]}"
      ;;
    exec)
      generate_probe readiness exec "${indent_count}" "${READINESS_EXEC_COMMAND}" -- "${readiness_timing_args[@]}"
      ;;
    grpc)
      generate_probe readiness grpc "${indent_count}" "${READINESS_GRPC_PORT}" "${READINESS_GRPC_SERVICE}" -- "${readiness_timing_args[@]}"
      ;;
  esac
}

# Generate a single startup probe using workload variables
# Usage: generate_startup_probe <indent>
#
# Reads from caller's scope: CONTAINER_PORT, STARTUP_* variables
generate_startup_probe() {
  local indent_count="$1"

  # Validate required fields based on check type
  case "${STARTUP_CHECK_TYPE}" in
    exec)
      if [[ -z "${STARTUP_EXEC_COMMAND:-}" ]]; then
        echo "Error: Startup probe type 'exec' requires STARTUP_EXEC_COMMAND" >&2
        return 4
      fi
      ;;
    tcp-socket)
      if [[ -z "${STARTUP_TCP_PORT:-}" ]]; then
        echo "Error: Startup probe type 'tcp-socket' requires STARTUP_TCP_PORT" >&2
        return 4
      fi
      ;;
    grpc)
      if [[ -z "${STARTUP_GRPC_PORT:-}" ]]; then
        echo "Error: Startup probe type 'grpc' requires STARTUP_GRPC_PORT" >&2
        return 4
      fi
      ;;
  esac

  local startup_timing_args=(
    "${STARTUP_INITIAL_DELAY_SECONDS}"
    "${STARTUP_PERIOD_SECONDS}"
    "${STARTUP_TIMEOUT_SECONDS}"
    "${STARTUP_FAILURE_THRESHOLD}"
  )
  if [[ -n "${STARTUP_TERMINATION_GRACE_PERIOD_SECONDS:-}" ]]; then
    startup_timing_args+=("${STARTUP_TERMINATION_GRACE_PERIOD_SECONDS}")
  fi

  case "${STARTUP_CHECK_TYPE}" in
    http-get)
      generate_probe startup http-get "${indent_count}" "${STARTUP_HTTP_PATH}" "${CONTAINER_PORT}" "${STARTUP_HTTP_SCHEME}" -- "${startup_timing_args[@]}"
      ;;
    tcp-socket)
      generate_probe startup tcp-socket "${indent_count}" "${STARTUP_TCP_PORT}" -- "${startup_timing_args[@]}"
      ;;
    exec)
      generate_probe startup exec "${indent_count}" "${STARTUP_EXEC_COMMAND}" -- "${startup_timing_args[@]}"
      ;;
    grpc)
      generate_probe startup grpc "${indent_count}" "${STARTUP_GRPC_PORT}" "${STARTUP_GRPC_SERVICE}" -- "${startup_timing_args[@]}"
      ;;
  esac
}
