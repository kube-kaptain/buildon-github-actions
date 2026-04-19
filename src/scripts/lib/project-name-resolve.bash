#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# project-name-resolve - Resolve project_name from REPOSITORY_NAME with optional prefix strip
#
# Sourced by scripts that need project_name. Sets shell variable `project_name`
# (not exported here — caller maps to PROJECT_NAME if it needs the env var).
#
# Requires in scope:
#   REPOSITORY_NAME, STRIP_REPOSITORY_NAME_PREFIX
#   log, log_warning, log_error functions (source lib/log.bash first)
#
# shellcheck disable=SC2154 # REPOSITORY_NAME, STRIP_REPOSITORY_NAME_PREFIX set by caller

if [[ -n "${STRIP_REPOSITORY_NAME_PREFIX}" ]]; then
  log_warning "Stripping repository name prefix '${STRIP_REPOSITORY_NAME_PREFIX}' from '${REPOSITORY_NAME}'."
  log_warning "Do not use this configuration unless you have an isolated cluster set or other"
  log_warning "runtime as it means you could get project name collisions if a repo is named the"
  log_warning "same without the prefix or has a different prefix with that prefix stripped."
  project_name="${REPOSITORY_NAME#"${STRIP_REPOSITORY_NAME_PREFIX}-"}"
  if [[ "${project_name}" == "${REPOSITORY_NAME}" ]]; then
    log_error "Repository name '${REPOSITORY_NAME}' does not start with prefix '${STRIP_REPOSITORY_NAME_PREFIX}-'"
    exit 1
  fi
  log "Project name after prefix strip: ${project_name}"
else
  project_name="${REPOSITORY_NAME}"
fi
