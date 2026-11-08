#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# output-dir-guard.bash - Refuse an output dir path that is unsafe to rm -rf.
#
# The build wipes output dirs: validate-tooling the one the build starts with,
# load-final-kaptainpm-yaml a configured spec.global.outputSubPath before the
# build's output moves into it. Both paths come from outside the build (a
# wrapper's env, a project or layer's KaptainPM.yaml), so they are checked
# here whatever the schema in use allowed.
#
# Requires lib/log.bash and git.

# Usage: assert_safe_output_dir <label> <dir>
# Exits 1 with the reason logged unless <dir> is a path relative to the
# repository root (no leading or trailing /, no empty, . or .. segments), is
# not .git, kaptainpm or src or inside one of them, and holds no files
# tracked by git.
assert_safe_output_dir() {
  local label="${1}" dir="${2}" first_segment tracked
  local segment='([^/.][^/]*|\.[^/.][^/]*|\.\.[^/]+)'
  if [[ ! "${dir}" =~ ^${segment}(/${segment})*$ ]]; then
    log_error "${label} must be a path relative to the repository root, with no leading or trailing /, empty, . or .. segments, got: ${dir}"
    exit 1
  fi
  first_segment="${dir%%/*}"
  case "${first_segment}" in
    .git|kaptainpm|src)
      log_error "${label} must not be ${first_segment} or inside it, got: ${dir}"
      exit 1
      ;;
  esac
  if ! tracked=$(git ls-files -- "${dir}" 2>/dev/null); then
    log_error "Cannot check ${label} ${dir} for tracked files: not in a git work tree"
    exit 1
  fi
  if [[ -n "${tracked}" ]]; then
    log_error "${label} ${dir} holds files tracked by git; it is wiped on every build, so it must be a dedicated output dir"
    exit 1
  fi
}
