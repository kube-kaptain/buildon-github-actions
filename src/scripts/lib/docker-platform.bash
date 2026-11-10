#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# docker-platform.bash - Which docker build platform values are allowed, and
# which of their arches this host cannot run natively.
#
# Shared by load-final-kaptainpm-yaml, which checks the value on every build
# and tells wrappers whether anything needs emulation, and
# docker-platform-setup, which registers the QEMU handlers when something does.
#
# Provides:
#   validate_docker_platform <platforms>        - Fail unless an allowed value
#   docker_platform_foreign_arches <platforms>  - Print each arch that needs emulation here
#
# Requires: log.bash sourced

# Usage: validate_docker_platform <platforms>
# Returns 1 with the reason logged unless <platforms> is an allowed value.
#
# linux/386 is single-platform only. It exists for legacy 32 bit toolchains that
# were never packaged for anything else, and there is no manifest list pairing
# for it, so it is deliberately absent from the comma separated combinations.
validate_docker_platform() {
  case "${1}" in
    linux/amd64) ;;
    linux/arm64) ;;
    linux/386) ;;
    linux/amd64,linux/arm64) ;;
    linux/arm64,linux/amd64) ;;
    *)
      log_error "Invalid DOCKER_PLATFORM value '${1}' - must be: linux/amd64, linux/arm64, linux/386, or amd64 and arm64 comma-separated"
      return 1
      ;;
  esac
}

# Usage: docker_platform_foreign_arches <platforms>
# Prints, one per line, the target arches (binfmt names) this host cannot run
# natively. linux/386 runs natively on amd64 kernels. An unrecognised host arch
# is treated as needing emulation for everything, to stay on the safe side.
docker_platform_foreign_arches() {
  local platforms="${1}"
  local host_arch platform arch
  case "$(uname -m)" in
    x86_64|amd64) host_arch="amd64" ;;
    aarch64|arm64) host_arch="arm64" ;;
    *) host_arch="unknown" ;;
  esac

  for platform in ${platforms//,/ }; do
    arch="${platform#linux/}"
    case "${host_arch}:${arch}" in
      amd64:amd64|amd64:386|arm64:arm64) ;;
      *) echo "${arch}" ;;
    esac
  done
}
