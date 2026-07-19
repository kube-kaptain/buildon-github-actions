#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kaptain contributors (Fred Cooke)
#
# kaptainpm-bool.bash - Boolean reads from KaptainPM files
#
# A raw yq read, deliberately NOT `yq '.path // default'`: yq's // operator
# treats an explicit false as absent and would clobber it with the default.
# Anything that is not literally true/false (absent reads as "null") yields
# the default - the schema owns rejecting genuinely invalid values.
#
# Requires: yq

# Usage: kaptainpm_bool <file> <yaml.path> <default>
kaptainpm_bool() {
  local value
  value=$(yq -r ".${2}" "${1}")
  case "${value}" in
    true|false) printf '%s' "${value}" ;;
    *) printf '%s' "${3}" ;;
  esac
}
