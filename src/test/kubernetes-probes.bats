#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-probes.bash library

load helpers

setup() {
  source "$LIB_DIR/kubernetes-probes.bash"
}

# =============================================================================
# probe_check_http_get
# =============================================================================

@test "probe_check_http_get: generates correct output" {
  run probe_check_http_get 0 /health 8080 HTTP
  [ "$status" -eq 0 ]
  assert_output_contains "httpGet:"
  assert_output_contains "path: /health"
  assert_output_contains "port: 8080"
  assert_output_contains "scheme: HTTP"
}

@test "probe_check_http_get: respects indentation" {
  result=$(probe_check_http_get 4 /liveness 1024 HTTPS)
  [[ "$result" == *"    httpGet:"* ]]
  [[ "$result" == *"      path: /liveness"* ]]
}

@test "probe_check_http_get: wrong arg count fails" {
  run probe_check_http_get 0 /health 8080
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 4 arguments"
}

# =============================================================================
# probe_check_tcp_socket
# =============================================================================

@test "probe_check_tcp_socket: generates correct output" {
  run probe_check_tcp_socket 0 5432
  [ "$status" -eq 0 ]
  assert_output_contains "tcpSocket:"
  assert_output_contains "port: 5432"
}

@test "probe_check_tcp_socket: respects indentation" {
  result=$(probe_check_tcp_socket 2 3306)
  [[ "$result" == *"  tcpSocket:"* ]]
  [[ "$result" == *"    port: 3306"* ]]
}

@test "probe_check_tcp_socket: wrong arg count fails" {
  run probe_check_tcp_socket 0
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 2 arguments"
}

# =============================================================================
# probe_check_exec
# =============================================================================

@test "probe_check_exec: generates correct output with sh -c wrapper" {
  run probe_check_exec 0 "pg_isready -U postgres"
  [ "$status" -eq 0 ]
  assert_output_contains "exec:"
  assert_output_contains "command:"
  assert_output_contains "- /bin/sh"
  assert_output_contains "- -c"
  assert_output_contains "- pg_isready -U postgres"
}

@test "probe_check_exec: respects indentation" {
  result=$(probe_check_exec 4 "cat /tmp/ready")
  [[ "$result" == *"    exec:"* ]]
  [[ "$result" == *"      command:"* ]]
}

@test "probe_check_exec: wrong arg count fails" {
  run probe_check_exec 0
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 2 arguments"
}

# =============================================================================
# probe_check_grpc
# =============================================================================

@test "probe_check_grpc: generates correct output with service" {
  run probe_check_grpc 0 50051 "myapp.HealthService"
  [ "$status" -eq 0 ]
  assert_output_contains "grpc:"
  assert_output_contains "port: 50051"
  assert_output_contains "service: myapp.HealthService"
}

@test "probe_check_grpc: omits service when empty" {
  run probe_check_grpc 0 50051 ""
  [ "$status" -eq 0 ]
  assert_output_contains "grpc:"
  assert_output_contains "port: 50051"
  assert_output_not_contains "service:"
}

@test "probe_check_grpc: respects indentation" {
  result=$(probe_check_grpc 2 50051 "")
  [[ "$result" == *"  grpc:"* ]]
  [[ "$result" == *"    port: 50051"* ]]
}

@test "probe_check_grpc: wrong arg count fails" {
  run probe_check_grpc 0 50051
  [ "$status" -ne 0 ]
  assert_output_contains "requires exactly 3 arguments"
}

# =============================================================================
# probe_timing_fields
# =============================================================================

@test "probe_timing_fields: generates all fields without success" {
  run probe_timing_fields 0 10 10 5 3
  [ "$status" -eq 0 ]
  assert_output_contains "initialDelaySeconds: 10"
  assert_output_contains "periodSeconds: 10"
  assert_output_contains "timeoutSeconds: 5"
  assert_output_contains "failureThreshold: 3"
  assert_output_not_contains "successThreshold:"
}

@test "probe_timing_fields: includes success when provided" {
  run probe_timing_fields 0 5 5 3 3 2
  [ "$status" -eq 0 ]
  assert_output_contains "initialDelaySeconds: 5"
  assert_output_contains "successThreshold: 2"
}

@test "probe_timing_fields: respects indentation" {
  result=$(probe_timing_fields 4 10 10 5 3)
  [[ "$result" == *"    initialDelaySeconds: 10"* ]]
}

@test "probe_timing_fields: wrong arg count fails" {
  run probe_timing_fields 0 10 10 5
  [ "$status" -ne 0 ]
  assert_output_contains "requires 5-7 arguments"
}

# =============================================================================
# generate_probe - http-get
# =============================================================================

@test "generate_probe: liveness http-get complete output" {
  run generate_probe liveness http-get 0 /liveness 8080 HTTP -- 10 10 5 3
  [ "$status" -eq 0 ]
  assert_output_contains "livenessProbe:"
  assert_output_contains "httpGet:"
  assert_output_contains "path: /liveness"
  assert_output_contains "port: 8080"
  assert_output_contains "scheme: HTTP"
  assert_output_contains "initialDelaySeconds: 10"
  assert_output_contains "failureThreshold: 3"
  assert_output_contains "successThreshold: 1"
}

@test "generate_probe: readiness http-get with custom successThreshold" {
  run generate_probe readiness http-get 0 /ready 8080 HTTP -- 5 5 3 3 2
  [ "$status" -eq 0 ]
  assert_output_contains "readinessProbe:"
  assert_output_contains "successThreshold: 2"
}

@test "generate_probe: startup http-get enforces successThreshold 1" {
  run generate_probe startup http-get 0 /startup 8080 HTTP -- 0 5 3 30
  [ "$status" -eq 0 ]
  assert_output_contains "startupProbe:"
  assert_output_contains "successThreshold: 1"
}

# =============================================================================
# generate_probe - tcp-socket
# =============================================================================

@test "generate_probe: liveness tcp-socket complete output" {
  run generate_probe liveness tcp-socket 0 5432 -- 10 10 5 3
  [ "$status" -eq 0 ]
  assert_output_contains "livenessProbe:"
  assert_output_contains "tcpSocket:"
  assert_output_contains "port: 5432"
  assert_output_contains "initialDelaySeconds: 10"
}

# =============================================================================
# generate_probe - exec
# =============================================================================

@test "generate_probe: liveness exec complete output" {
  run generate_probe liveness exec 0 "pg_isready -U postgres" -- 10 10 5 3
  [ "$status" -eq 0 ]
  assert_output_contains "livenessProbe:"
  assert_output_contains "exec:"
  assert_output_contains "- /bin/sh"
  assert_output_contains "- -c"
  assert_output_contains "- pg_isready -U postgres"
}

# =============================================================================
# generate_probe - grpc
# =============================================================================

@test "generate_probe: liveness grpc with service" {
  run generate_probe liveness grpc 0 50051 "myapp.Health" -- 10 10 5 3
  [ "$status" -eq 0 ]
  assert_output_contains "livenessProbe:"
  assert_output_contains "grpc:"
  assert_output_contains "port: 50051"
  assert_output_contains "service: myapp.Health"
}

@test "generate_probe: liveness grpc without service" {
  run generate_probe liveness grpc 0 50051 "" -- 10 10 5 3
  [ "$status" -eq 0 ]
  assert_output_contains "livenessProbe:"
  assert_output_contains "grpc:"
  assert_output_not_contains "service:"
}

# =============================================================================
# generate_probe - indentation
# =============================================================================

@test "generate_probe: respects base indentation" {
  run generate_probe liveness http-get 10 /health 8080 HTTP -- 10 10 5 3
  [ "$status" -eq 0 ]
  first_line=$(echo "$output" | head -n1)
  [[ "$first_line" == "          livenessProbe:" ]]
}

# =============================================================================
# generate_probe - error cases
# =============================================================================

@test "generate_probe: invalid probe_type fails" {
  run generate_probe invalid http-get 0 /health 8080 HTTP -- 10 10 5 3
  [ "$status" -ne 0 ]
  assert_output_contains "invalid probe_type"
}

@test "generate_probe: invalid check_type fails" {
  run generate_probe liveness invalid 0 /health 8080 HTTP -- 10 10 5 3
  [ "$status" -ne 0 ]
  assert_output_contains "invalid check_type"
}

@test "generate_probe: missing separator fails" {
  run generate_probe liveness http-get 0 /health 8080 HTTP 10 10 5 3
  [ "$status" -ne 0 ]
  assert_output_contains "requires -- separator"
}

@test "generate_probe: wrong http-get args count fails" {
  run generate_probe liveness http-get 0 /health 8080 -- 10 10 5 3
  [ "$status" -ne 0 ]
  assert_output_contains "http-get requires 3 check args"
}

@test "generate_probe: wrong tcp-socket args count fails" {
  run generate_probe liveness tcp-socket 0 5432 extra -- 10 10 5 3
  [ "$status" -ne 0 ]
  assert_output_contains "tcp-socket requires 1 check arg"
}

@test "generate_probe: wrong exec args count fails" {
  run generate_probe liveness exec 0 -- 10 10 5 3
  [ "$status" -ne 0 ]
  assert_output_contains "exec requires 1 check arg"
}

@test "generate_probe: wrong grpc args count fails" {
  run generate_probe liveness grpc 0 50051 -- 10 10 5 3
  [ "$status" -ne 0 ]
  assert_output_contains "grpc requires 2 check args"
}

@test "generate_probe: insufficient timing args fails" {
  run generate_probe liveness http-get 0 /health 8080 HTTP -- 10 10 5
  [ "$status" -ne 0 ]
  assert_output_contains "timing args require at least 4 values"
}

# =============================================================================
# K8s enforced values
# =============================================================================

@test "generate_probe: liveness always has successThreshold 1" {
  run generate_probe liveness http-get 0 /health 8080 HTTP -- 10 10 5 3
  [ "$status" -eq 0 ]
  assert_output_contains "successThreshold: 1"
}

@test "generate_probe: startup always has successThreshold 1" {
  run generate_probe startup http-get 0 /health 8080 HTTP -- 0 5 3 30
  [ "$status" -eq 0 ]
  assert_output_contains "successThreshold: 1"
}

@test "generate_probe: readiness defaults successThreshold to 1 if not provided" {
  run generate_probe readiness http-get 0 /health 8080 HTTP -- 5 5 3 3
  [ "$status" -eq 0 ]
  assert_output_contains "successThreshold: 1"
}

# =============================================================================
# terminationGracePeriodSeconds (liveness/startup only, K8s 1.25+)
# =============================================================================

@test "generate_probe: liveness with terminationGracePeriodSeconds" {
  run generate_probe liveness http-get 0 /health 8080 HTTP -- 10 10 5 3 5
  [ "$status" -eq 0 ]
  assert_output_contains "terminationGracePeriodSeconds: 5"
  assert_output_contains "successThreshold: 1"
}

@test "generate_probe: startup with terminationGracePeriodSeconds" {
  run generate_probe startup http-get 0 /health 8080 HTTP -- 0 5 3 30 10
  [ "$status" -eq 0 ]
  assert_output_contains "terminationGracePeriodSeconds: 10"
  assert_output_contains "successThreshold: 1"
}

@test "generate_probe: liveness without terminationGracePeriodSeconds omits field" {
  run generate_probe liveness http-get 0 /health 8080 HTTP -- 10 10 5 3
  [ "$status" -eq 0 ]
  assert_output_not_contains "terminationGracePeriodSeconds"
}

@test "generate_probe: readiness ignores 5th arg as terminationGracePeriodSeconds" {
  run generate_probe readiness http-get 0 /health 8080 HTTP -- 5 5 3 3 2
  [ "$status" -eq 0 ]
  assert_output_contains "successThreshold: 2"
  assert_output_not_contains "terminationGracePeriodSeconds"
}

@test "probe_timing_fields: includes terminationGracePeriodSeconds when provided" {
  run probe_timing_fields 0 10 10 5 3 1 15
  [ "$status" -eq 0 ]
  assert_output_contains "terminationGracePeriodSeconds: 15"
}

@test "probe_timing_fields: omits terminationGracePeriodSeconds when empty" {
  run probe_timing_fields 0 10 10 5 3 1 ""
  [ "$status" -eq 0 ]
  assert_output_not_contains "terminationGracePeriodSeconds"
}

@test "probe_timing_fields: accepts 7 arguments" {
  run probe_timing_fields 0 10 10 5 3 1 20
  [ "$status" -eq 0 ]
  assert_output_contains "successThreshold: 1"
  assert_output_contains "terminationGracePeriodSeconds: 20"
}
