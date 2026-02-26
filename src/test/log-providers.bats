#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

LIB_DIR="$PROJECT_ROOT/src/scripts/lib"

# =============================================================================
# stdout provider - default/local
# =============================================================================

@test "stdout provider: log writes to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=stdout
  source "$LIB_DIR/log.bash"

  stdout_output=$(log "hello world" 2>/dev/null)
  [ "$stdout_output" = "hello world" ]
}

@test "stdout provider: log does not write to stderr" {
  BUILD_PLATFORM_LOG_PROVIDER=stdout
  source "$LIB_DIR/log.bash"

  stderr_output=$(log "hello world" 2>&1 1>/dev/null)
  [ -z "$stderr_output" ]
}

@test "stdout provider: log_error writes to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=stdout
  source "$LIB_DIR/log.bash"

  stdout_output=$(log_error "bad thing" 2>/dev/null)
  [ "$stdout_output" = "ERROR: bad thing" ]
}

@test "stdout provider: log_error does not write to stderr" {
  BUILD_PLATFORM_LOG_PROVIDER=stdout
  source "$LIB_DIR/log.bash"

  stderr_output=$(log_error "bad thing" 2>&1 1>/dev/null)
  [ -z "$stderr_output" ]
}

@test "stdout provider: log_warning writes to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=stdout
  source "$LIB_DIR/log.bash"

  stdout_output=$(log_warning "careful" 2>/dev/null)
  [ "$stdout_output" = "WARNING: careful" ]
}

@test "stdout provider: log_warning does not write to stderr" {
  BUILD_PLATFORM_LOG_PROVIDER=stdout
  source "$LIB_DIR/log.bash"

  stderr_output=$(log_warning "careful" 2>&1 1>/dev/null)
  [ -z "$stderr_output" ]
}

@test "stdout provider: all output goes to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=stdout
  source "$LIB_DIR/log.bash"

  test_func() {
    log "info message"
    log_error "error message"
    log_warning "warning message"
  }

  # All three levels go to stdout
  stdout_output=$(test_func 2>/dev/null)
  [[ "$stdout_output" == *"info message"* ]]
  [[ "$stdout_output" == *"ERROR: error message"* ]]
  [[ "$stdout_output" == *"WARNING: warning message"* ]]

  # Nothing on stderr
  stderr_output=$(test_func 2>&1 1>/dev/null)
  [ -z "$stderr_output" ]
}

# =============================================================================
# github-actions provider
# =============================================================================

@test "github-actions provider: log writes to stderr" {
  BUILD_PLATFORM_LOG_PROVIDER=github-actions
  source "$LIB_DIR/log.bash"

  stderr_output=$(log "hello world" 2>&1 1>/dev/null)
  [ "$stderr_output" = "hello world" ]
}

@test "github-actions provider: log does not write to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=github-actions
  source "$LIB_DIR/log.bash"

  stdout_output=$(log "hello world" 2>/dev/null)
  [ -z "$stdout_output" ]
}

@test "github-actions provider: log_error writes ::error:: to stderr" {
  BUILD_PLATFORM_LOG_PROVIDER=github-actions
  source "$LIB_DIR/log.bash"

  stderr_output=$(log_error "bad thing" 2>&1 1>/dev/null)
  [ "$stderr_output" = "::error::bad thing" ]
}

@test "github-actions provider: log_error does not write to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=github-actions
  source "$LIB_DIR/log.bash"

  stdout_output=$(log_error "bad thing" 2>/dev/null)
  [ -z "$stdout_output" ]
}

@test "github-actions provider: log_warning writes ::warning:: to stderr" {
  BUILD_PLATFORM_LOG_PROVIDER=github-actions
  source "$LIB_DIR/log.bash"

  stderr_output=$(log_warning "careful" 2>&1 1>/dev/null)
  [ "$stderr_output" = "::warning::careful" ]
}

@test "github-actions provider: log_warning does not write to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=github-actions
  source "$LIB_DIR/log.bash"

  stdout_output=$(log_warning "careful" 2>/dev/null)
  [ -z "$stdout_output" ]
}

@test "github-actions provider: log_error survives subshell capture" {
  BUILD_PLATFORM_LOG_PROVIDER=github-actions
  source "$LIB_DIR/log.bash"

  test_func() {
    log "info message"
    log_error "error message"
    echo "DATA=value"
  }

  # Only stdout captured - log and log_error both go to stderr
  captured=$(test_func 2>/dev/null)
  [[ "$captured" == *"DATA=value"* ]]
  [[ "$captured" != *"info message"* ]]
  [[ "$captured" != *"::error::error message"* ]]

  # Both log and log_error on stderr
  stderr_output=$(test_func 2>&1 1>/dev/null)
  [[ "$stderr_output" == *"info message"* ]]
  [[ "$stderr_output" == *"::error::error message"* ]]
}

# =============================================================================
# azure-devops provider
# =============================================================================

@test "azure-devops provider: log writes to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=azure-devops
  source "$LIB_DIR/log.bash"

  stdout_output=$(log "hello world" 2>/dev/null)
  [ "$stdout_output" = "hello world" ]
}

@test "azure-devops provider: log does not write to stderr" {
  BUILD_PLATFORM_LOG_PROVIDER=azure-devops
  source "$LIB_DIR/log.bash"

  stderr_output=$(log "hello world" 2>&1 1>/dev/null)
  [ -z "$stderr_output" ]
}

@test "azure-devops provider: log_error writes ##vso error to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=azure-devops
  source "$LIB_DIR/log.bash"

  stdout_output=$(log_error "bad thing" 2>/dev/null)
  [ "$stdout_output" = "##vso[task.logissue type=error]bad thing" ]
}

@test "azure-devops provider: log_warning writes ##vso warning to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=azure-devops
  source "$LIB_DIR/log.bash"

  stdout_output=$(log_warning "careful" 2>/dev/null)
  [ "$stdout_output" = "##vso[task.logissue type=warning]careful" ]
}

@test "azure-devops provider: all output goes to stdout" {
  BUILD_PLATFORM_LOG_PROVIDER=azure-devops
  source "$LIB_DIR/log.bash"

  test_func() {
    log "info message"
    log_error "error message"
    log_warning "warning message"
  }

  # All three levels go to stdout (Azure agent parses ##vso from stdout)
  stdout_output=$(test_func 2>/dev/null)
  [[ "$stdout_output" == *"info message"* ]]
  [[ "$stdout_output" == *"##vso[task.logissue type=error]error message"* ]]
  [[ "$stdout_output" == *"##vso[task.logissue type=warning]warning message"* ]]

  # Nothing on stderr
  stderr_output=$(test_func 2>&1 1>/dev/null)
  [ -z "$stderr_output" ]
}

# =============================================================================
# Provider selection
# =============================================================================

@test "log.bash defaults to stdout provider" {
  unset BUILD_PLATFORM_LOG_PROVIDER
  source "$LIB_DIR/log.bash"

  stdout_output=$(log "test" 2>/dev/null)
  [ "$stdout_output" = "test" ]

  stdout_output=$(log_error "test" 2>/dev/null)
  [ "$stdout_output" = "ERROR: test" ]
}

@test "log.bash fails on unknown provider" {
  run env BUILD_PLATFORM_LOG_PROVIDER=nonexistent bash -c "source '$LIB_DIR/log.bash'"
  [ "$status" -eq 1 ]
  assert_output_contains "Unknown log provider: nonexistent"
}
