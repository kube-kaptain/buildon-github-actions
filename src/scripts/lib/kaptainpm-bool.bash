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
# YAML booleans may be written True, TRUE, False or FALSE, and yq -r prints
# them exactly as written, so every read goes through kaptainpm_value, which
# prints a boolean in lowercase and anything else as plain yq -r would.
#
# Requires: yq

# Usage: kaptainpm_value <file> <yaml.path>
kaptainpm_value() {
  yq -r ".${2} | select(tag == \"!!bool\") |= (. | to_json)" "${1}"
}

# Usage: kaptainpm_bool <file> <yaml.path> <default>
kaptainpm_bool() {
  local value
  value=$(kaptainpm_value "${1}" "${2}")
  case "${value}" in
    true|false) printf '%s' "${value}" ;;
    *) printf '%s' "${3}" ;;
  esac
}
