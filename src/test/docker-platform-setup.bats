#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

bats_require_minimum_version 1.5.0

load helpers

setup() {
  export BUILD_MODE="build_server"
  export IMAGE_BUILD_COMMAND="docker"
  local base_dir=$(create_test_dir "docker-platform-setup")
  export GITHUB_OUTPUT="$base_dir/output"
}

teardown() {
  dump_bats_result
  rm -rf "${MOCK_BIN_DIR}"
}

# === Platform validation ===

@test "accepts linux/amd64" {
  export DOCKER_PLATFORM="linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/amd64"
}

@test "accepts linux/arm64" {
  export DOCKER_PLATFORM="linux/arm64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/arm64"
}

@test "accepts linux/386" {
  export DOCKER_PLATFORM="linux/386"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/386"
}

@test "rejects linux/386 combined with another platform" {
  export DOCKER_PLATFORM="linux/386,linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value 'linux/386,linux/amd64'"
}

@test "accepts linux/amd64,linux/arm64" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/amd64,linux/arm64"
}

@test "accepts linux/arm64,linux/amd64" {
  export DOCKER_PLATFORM="linux/arm64,linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/arm64,linux/amd64"
}

@test "rejects windows/amd64" {
  export DOCKER_PLATFORM="windows/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value 'windows/amd64'"
}

@test "empty string defaults to linux/amd64" {
  export DOCKER_PLATFORM=""

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/amd64"
}

@test "rejects amd64 without os prefix" {
  export DOCKER_PLATFORM="amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value 'amd64'"
}

@test "rejects three platforms" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64,linux/s390x"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value"
}

@test "rejects platform with spaces" {
  export DOCKER_PLATFORM="linux/amd64, linux/arm64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "Invalid DOCKER_PLATFORM value"
}

@test "defaults to linux/amd64 when not set" {
  unset DOCKER_PLATFORM

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Platform validated: linux/amd64"
}

# === QEMU install ===

IMAGE="ghcr.io/kube-kaptain/image/image-binfmt:10.2.3.1"

@test "skips QEMU setup on non-Linux" {
  export DOCKER_PLATFORM="linux/arm64"
  mkdir -p "${MOCK_BIN_DIR}"
  printf '#!/usr/bin/env bash\necho Darwin\n' > "${MOCK_BIN_DIR}/uname"
  chmod +x "${MOCK_BIN_DIR}/uname"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Not a Linux host: skipping QEMU setup"
}

# Fake a Linux host of the given machine arch, with docker, podman and sudo
# mocked, and an empty binfmt_misc dir standing in for the kernel's.
mock_linux_host() {
  local machine="${1}"
  setup_mock_docker
  cat > "${MOCK_BIN_DIR}/uname" << MOCK
#!/usr/bin/env bash
if [[ "\${1}" == "-m" ]]; then echo "${machine}"; else echo "Linux"; fi
MOCK
  # Only runs the command when it is itself a mock, so a real apt-get or yum on
  # the test host is never executed
  cat > "${MOCK_BIN_DIR}/sudo" << MOCK
#!/usr/bin/env bash
echo "MOCK sudo \$*"
if [[ "\$(command -v "\${1}")" == "${MOCK_BIN_DIR}/"* ]]; then
  "\$@"
fi
MOCK
  chmod +x "${MOCK_BIN_DIR}/uname" "${MOCK_BIN_DIR}/sudo"
  export BINFMT_MISC_DIR="${BATS_TEST_TMPDIR}/binfmt_misc"
  mkdir -p "${BINFMT_MISC_DIR}"
}

@test "skips QEMU setup for linux/amd64 on an amd64 host" {
  export DOCKER_PLATFORM="linux/amd64"
  mock_linux_host x86_64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "builds linux/amd64 natively"
  assert_docker_not_called "run"
}

@test "skips QEMU setup for linux/386 on an amd64 host" {
  export DOCKER_PLATFORM="linux/386"
  mock_linux_host x86_64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "builds linux/386 natively"
  assert_docker_not_called "run"
}

@test "skips QEMU setup for linux/arm64 on an arm64 host" {
  export DOCKER_PLATFORM="linux/arm64"
  mock_linux_host aarch64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "builds linux/arm64 natively"
  assert_docker_not_called "run"
}

@test "installs arm64 binfmt on an amd64 host" {
  export DOCKER_PLATFORM="linux/arm64"
  mock_linux_host x86_64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_docker_called "run --privileged --rm ${IMAGE} --install arm64"
}

@test "installs amd64 binfmt on an arm64 host" {
  export DOCKER_PLATFORM="linux/amd64"
  mock_linux_host aarch64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_docker_called "run --privileged --rm ${IMAGE} --install amd64"
}

@test "installs 386 binfmt on an arm64 host" {
  export DOCKER_PLATFORM="linux/386"
  mock_linux_host aarch64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_docker_called "run --privileged --rm ${IMAGE} --install 386"
}

@test "installs only the foreign arch for multi-arch on an amd64 host" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  mock_linux_host x86_64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_docker_called "run --privileged --rm ${IMAGE} --install arm64$"
}

@test "installs every requested arch on an unrecognised host arch" {
  export DOCKER_PLATFORM="linux/arm64,linux/amd64"
  mock_linux_host riscv64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_docker_called "run --privileged --rm ${IMAGE} --install arm64,amd64"
}

@test "skips install when the needed handler is already registered" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  mock_linux_host x86_64
  touch "${BINFMT_MISC_DIR}/qemu-aarch64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "QEMU binfmt already registered for arm64: skipping install"
  assert_docker_not_called "run"
}

@test "an unrelated registered handler does not count" {
  export DOCKER_PLATFORM="linux/arm64"
  mock_linux_host x86_64
  touch "${BINFMT_MISC_DIR}/qemu-riscv64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_docker_called "run --privileged --rm ${IMAGE} --install arm64"
}

@test "podman installs through sudo" {
  export DOCKER_PLATFORM="linux/arm64"
  export IMAGE_BUILD_COMMAND="podman"
  mock_linux_host x86_64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "MOCK sudo podman run --privileged --rm ${IMAGE} --install arm64"
}

@test "QEMU_BINFMT_IMAGE overrides the image" {
  export DOCKER_PLATFORM="linux/arm64"
  export QEMU_BINFMT_IMAGE="registry.example.com/mirror/binfmt:1.2.3.4"
  mock_linux_host x86_64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_docker_called "run --privileged --rm registry.example.com/mirror/binfmt:1.2.3.4 --install arm64"
}

@test "falls back to apt-get when the binfmt image install fails" {
  export DOCKER_PLATFORM="linux/arm64"
  mock_linux_host x86_64
  printf '#!/usr/bin/env bash\nexit 1\n' > "${MOCK_BIN_DIR}/docker"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${MOCK_BIN_DIR}/apt-get"
  chmod +x "${MOCK_BIN_DIR}/apt-get"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "falling back to the OS package manager"
  assert_output_contains "MOCK sudo apt-get update"
  assert_output_contains "MOCK sudo apt-get install -y qemu-user-static binfmt-support"
  assert_output_contains "QEMU binfmt support installed for arm64"
}

@test "falls back to yum when the binfmt image install fails and there is no apt-get" {
  if command -v apt-get &>/dev/null; then
    skip "a real apt-get on this host would be chosen ahead of yum"
  fi
  export DOCKER_PLATFORM="linux/arm64"
  mock_linux_host x86_64
  printf '#!/usr/bin/env bash\nexit 1\n' > "${MOCK_BIN_DIR}/docker"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${MOCK_BIN_DIR}/yum"
  chmod +x "${MOCK_BIN_DIR}/yum"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "MOCK sudo yum install -y qemu-user-static"
  assert_output_contains "QEMU binfmt support installed for arm64"
}

@test "fails when the binfmt image install fails and there is no package manager" {
  if command -v apt-get &>/dev/null || command -v yum &>/dev/null; then
    skip "a real apt-get or yum on this host would be used"
  fi
  export DOCKER_PLATFORM="linux/arm64"
  mock_linux_host x86_64
  printf '#!/usr/bin/env bash\nexit 1\n' > "${MOCK_BIN_DIR}/docker"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -ne 0 ]
  assert_output_contains "No supported package manager found"
  assert_output_not_contains "QEMU binfmt support installed"
}

@test "podman falls back to apt-get when the binfmt image install fails" {
  export DOCKER_PLATFORM="linux/arm64"
  export IMAGE_BUILD_COMMAND="podman"
  mock_linux_host x86_64
  printf '#!/usr/bin/env bash\nexit 1\n' > "${MOCK_BIN_DIR}/podman"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${MOCK_BIN_DIR}/apt-get"
  chmod +x "${MOCK_BIN_DIR}/apt-get"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "MOCK sudo apt-get install -y qemu-user-static binfmt-support"
}

@test "local mode warns instead of installing" {
  export DOCKER_PLATFORM="linux/amd64,linux/arm64"
  export BUILD_MODE="local"
  mock_linux_host x86_64

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "QEMU binfmt not registered for arm64"
  assert_output_contains "--install arm64"
  assert_docker_not_called "run"
}

@test "local mode is silent when the handler is registered" {
  export DOCKER_PLATFORM="linux/arm64"
  export BUILD_MODE="local"
  mock_linux_host x86_64
  touch "${BINFMT_MISC_DIR}/qemu-aarch64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_not_contains "not registered"
}

# === Output messages ===

@test "outputs header with platform and build mode" {
  export DOCKER_PLATFORM="linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker Platform Setup"
  assert_output_contains "Platform: linux/amd64"
  assert_output_contains "Build mode:"
}

@test "outputs complete message" {
  export DOCKER_PLATFORM="linux/amd64"

  run "$SCRIPTS_DIR/docker-platform-setup"
  [ "$status" -eq 0 ]
  assert_output_contains "Docker platform setup complete"
}
