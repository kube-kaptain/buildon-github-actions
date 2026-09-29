#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# reject-non-regular.bash - Fail on symlinks and other non-regular entries in
# content that comes from outside the build (child zips, layer images, layer
# payload archives, the layer build context).
#
# A symlink can point outside the tree it arrived in. Later steps read through
# it (cp, yq, zip, awk) and yq -i writes through it, so one crafted entry can
# pull a runner file into published output or modify a file outside the tree.
# Dot-named entries are checked too: not every walk skips them. Content that
# genuinely needs a link can ship a script that creates it and run it from a
# hook.
#
# Requires lib/log.bash.

# Usage: reject_non_regular <label> <dir>
# Returns: 0 when <dir> holds only regular files and directories, 1 otherwise
#          with each offender logged relative to <dir>
reject_non_regular() {
  local label="$1"
  local dir="$2"
  local entry found=()
  while IFS= read -r -d '' entry; do
    if [[ -L "${entry}" ]]; then
      found+=("${entry#"${dir}"/}: a symbolic link")
    else
      found+=("${entry#"${dir}"/}: not a regular file or directory")
    fi
  done < <(find "${dir}" -mindepth 1 ! -type f ! -type d -print0)
  [[ ${#found[@]} -eq 0 ]] && return 0
  log_error "${label} holds entries other than regular files and directories:"
  for entry in "${found[@]}"; do
    log_error "  ${entry}"
  done
  return 1
}
