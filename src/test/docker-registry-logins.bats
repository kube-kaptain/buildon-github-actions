#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

# Tests for docker-registry-logins script

load helpers

SCRIPT="$SCRIPTS_DIR/docker-registry-logins"

setup() {
  setup_mock_docker
  export IMAGE_BUILD_COMMAND="docker"
  export BUILD_PLATFORM="github-actions"
  export BUILD_PLATFORM_LOG_PROVIDER="stdout"
  export SECRET_METHOD="github"
  export SECRETS_JSON='{}'

  TEST_DIR=$(create_test_dir "docker-registry-logins")
  export OUTPUT_SUB_PATH="${TEST_DIR}/target"
  export GITHUB_OUTPUT="${TEST_DIR}/output"
  mkdir -p "${OUTPUT_SUB_PATH}" "$(dirname "${GITHUB_OUTPUT}")"
  : > "${GITHUB_OUTPUT}"

  # Create mock plugin directories matching script's PLUGINS_DIR layout
  MOCK_PLUGINS_DIR="${TEST_DIR}/plugins"
  mkdir -p "${MOCK_PLUGINS_DIR}/secret-value-providers"
  mkdir -p "${MOCK_PLUGINS_DIR}/docker-login-providers"

  # Mock get-secret-github: looks up key from SECRETS_JSON via bash
  cat > "${MOCK_PLUGINS_DIR}/secret-value-providers/get-secret-github" << 'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name="${1}"
# Simple JSON key lookup without yq dependency
value=$(echo "${SECRETS_JSON}" | python3 -c "import sys,json; d=json.load(sys.stdin); v=d.get('${name}',''); print(v)" 2>/dev/null || echo "")
if [[ -z "${value}" ]]; then
  echo "Secret not found: ${name}" >&2
  exit 1
fi
echo "${value}"
MOCK
  chmod +x "${MOCK_PLUGINS_DIR}/secret-value-providers/get-secret-github"

  # Mock docker-login-github-token: args are secret-method registry token actor
  cat > "${MOCK_PLUGINS_DIR}/docker-login-providers/docker-login-github-token" << 'MOCK'
#!/usr/bin/env bash
registry="${2}"
token="${3}"
actor="${4}"
if [[ -z "${token}" ]]; then
  echo "Token not provided" >&2
  exit 1
fi
echo "Logging in to ${registry} with GITHUB_TOKEN..."
echo "${token}" | ${IMAGE_BUILD_COMMAND} login "${registry}" -u "${actor}" --password-stdin
MOCK
  chmod +x "${MOCK_PLUGINS_DIR}/docker-login-providers/docker-login-github-token"

  # Mock docker-login-username-password: logs the action
  cat > "${MOCK_PLUGINS_DIR}/docker-login-providers/docker-login-username-password" << 'MOCK'
#!/usr/bin/env bash
PLUGINS_DIR="$(dirname "${0}")/.."
get_secret="${PLUGINS_DIR}/secret-value-providers/get-secret-${1}"
username=$("${get_secret}" "${3}") || exit 1
password=$("${get_secret}" "${4}") || exit 1
echo "Logging in to ${2} with username/password..."
echo "${password}" | ${IMAGE_BUILD_COMMAND} login "${2}" -u "${username}" --password-stdin
MOCK
  chmod +x "${MOCK_PLUGINS_DIR}/docker-login-providers/docker-login-username-password"

  # Mock docker-login-gcp-gar
  cat > "${MOCK_PLUGINS_DIR}/docker-login-providers/docker-login-gcp-gar" << 'MOCK'
#!/usr/bin/env bash
PLUGINS_DIR="$(dirname "${0}")/.."
get_secret="${PLUGINS_DIR}/secret-value-providers/get-secret-${1}"
sa_key=$("${get_secret}" "${3}") || exit 1
echo "Logging in to Google Artifact Registry..."
echo "${sa_key}" | ${IMAGE_BUILD_COMMAND} login -u _json_key --password-stdin "https://${2}"
MOCK
  chmod +x "${MOCK_PLUGINS_DIR}/docker-login-providers/docker-login-gcp-gar"

  # Mock docker-login-azure-acr
  cat > "${MOCK_PLUGINS_DIR}/docker-login-providers/docker-login-azure-acr" << 'MOCK'
#!/usr/bin/env bash
PLUGINS_DIR="$(dirname "${0}")/.."
get_secret="${PLUGINS_DIR}/secret-value-providers/get-secret-${1}"
client_id=$("${get_secret}" "${3}") || exit 1
client_secret=$("${get_secret}" "${4}") || exit 1
echo "Logging in to Azure ACR..."
echo "${client_secret}" | ${IMAGE_BUILD_COMMAND} login "${2}" -u "${client_id}" --password-stdin
MOCK
  chmod +x "${MOCK_PLUGINS_DIR}/docker-login-providers/docker-login-azure-acr"

}

teardown() {
  cleanup_mock_docker
}

run_logins() {
  # Copy the entire scripts tree then overlay mock plugins.
  # log.bash resolves ../plugins relative to itself via BASH_SOURCE,
  # so everything must be real files/dirs - symlinks break path resolution.
  local shim_base="${TEST_DIR}/shim-scripts"
  rm -rf "${shim_base}"
  cp -r "${SCRIPTS_DIR}/.." "${shim_base}"
  # Overlay mock login and secret providers
  cp -f "${MOCK_PLUGINS_DIR}/secret-value-providers/"* "${shim_base}/plugins/secret-value-providers/"
  cp -f "${MOCK_PLUGINS_DIR}/docker-login-providers/"* "${shim_base}/plugins/docker-login-providers/"
  run "${shim_base}/main/docker-registry-logins"
}

@test "docker-registry-logins: fails when DOCKER_REGISTRY_LOGINS not provided" {
  export DOCKER_REGISTRY_LOGINS=""

  run_logins

  [ "$status" -ne 0 ]
  assert_output_contains "DOCKER_REGISTRY_LOGINS is required"
}

@test "docker-registry-logins: github-token type uses token from config" {
  read -r -d '' DOCKER_REGISTRY_LOGINS <<'EOF' || true
ghcr.io:
  type: github-token
  token: test-token
  actor: test-user
EOF
  export DOCKER_REGISTRY_LOGINS

  run_logins

  [ "$status" -eq 0 ]
  assert_output_contains "Logging in to ghcr.io with GITHUB_TOKEN"
  assert_docker_called "login ghcr.io -u test-user --password-stdin"
}

@test "docker-registry-logins: github-token fails without token in config" {
  read -r -d '' DOCKER_REGISTRY_LOGINS <<'EOF' || true
ghcr.io:
  type: github-token
  token: ""
  actor: test-user
EOF
  export DOCKER_REGISTRY_LOGINS

  run_logins

  [ "$status" -ne 0 ]
}

@test "docker-registry-logins: username-password type with ghcr.io" {
  read -r -d '' DOCKER_REGISTRY_LOGINS <<'EOF' || true
ghcr.io:
  type: username-password
  username-secret: GHCR_USER
  password-secret: GHCR_PASS
EOF
  export DOCKER_REGISTRY_LOGINS
  export SECRETS_JSON='{"GHCR_USER": "custom-user", "GHCR_PASS": "custom-pass"}'

  run_logins

  [ "$status" -eq 0 ]
  assert_output_contains "Logging in to ghcr.io with username/password"
  assert_docker_called "login ghcr.io -u custom-user --password-stdin"
}

@test "docker-registry-logins: fails on unknown login type" {
  read -r -d '' DOCKER_REGISTRY_LOGINS <<'EOF' || true
example.com:
  type: unknown-type
EOF
  export DOCKER_REGISTRY_LOGINS

  run_logins

  [ "$status" -ne 0 ]
}

@test "docker-registry-logins: fails when required secret is missing" {
  read -r -d '' DOCKER_REGISTRY_LOGINS <<'EOF' || true
docker.io:
  type: username-password
  username-secret: MISSING_USER
  password-secret: MISSING_PASS
EOF
  export DOCKER_REGISTRY_LOGINS
  export SECRETS_JSON='{}'

  run_logins

  [ "$status" -ne 0 ]
  assert_output_contains "Secret validation failed"
}

@test "docker-registry-logins: processes multiple registries" {
  read -r -d '' DOCKER_REGISTRY_LOGINS <<'EOF' || true
docker.io:
  type: username-password
  username-secret: DOCKER_USER
  password-secret: DOCKER_PASS
quay.io:
  type: username-password
  username-secret: QUAY_USER
  password-secret: QUAY_PASS
EOF
  export DOCKER_REGISTRY_LOGINS
  export SECRETS_JSON='{"DOCKER_USER": "user1", "DOCKER_PASS": "pass1", "QUAY_USER": "user2", "QUAY_PASS": "pass2"}'

  run_logins

  [ "$status" -eq 0 ]
  assert_output_contains "Logging in to docker.io with username/password"
  assert_output_contains "Logging in to quay.io with username/password"
  assert_docker_called "login docker.io -u user1 --password-stdin"
  assert_docker_called "login quay.io -u user2 --password-stdin"
}

@test "docker-registry-logins: mixed github-token and username-password" {
  read -r -d '' DOCKER_REGISTRY_LOGINS <<'EOF' || true
ghcr.io:
  type: github-token
  token: gh-token
  actor: gh-user
docker.io:
  type: username-password
  username-secret: DOCKER_USER
  password-secret: DOCKER_PASS
EOF
  export DOCKER_REGISTRY_LOGINS
  export SECRETS_JSON='{"DOCKER_USER": "myuser", "DOCKER_PASS": "mypass"}'

  run_logins

  [ "$status" -eq 0 ]
  assert_output_contains "Logging in to ghcr.io with GITHUB_TOKEN"
  assert_output_contains "Logging in to docker.io with username/password"
  assert_docker_called "login ghcr.io -u gh-user --password-stdin"
  assert_docker_called "login docker.io -u myuser --password-stdin"
}
