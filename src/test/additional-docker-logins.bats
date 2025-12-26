#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)

# Tests for additional-docker-logins script

load helpers

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  SCRIPT="$TEST_DIR/../scripts/main/additional-docker-logins"
  setup_mock_docker
  export SECRET_METHOD="github"
}

teardown() {
  cleanup_mock_docker
}

@test "additional-docker-logins: fails when CONFIG not provided" {
  export CONFIG=""
  export SECRETS_JSON='{}'

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "CONFIG is required" ]]
}

@test "additional-docker-logins: github-token type uses token from config" {
  read -r -d '' CONFIG <<'EOF' || true
ghcr.io:
  type: github-token
  token: test-token
  actor: test-user
EOF
  export CONFIG
  export SECRETS_JSON='{}'

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Logging in to ghcr.io with GITHUB_TOKEN" ]]
  assert_docker_called "login ghcr.io -u test-user --password-stdin"
}

@test "additional-docker-logins: github-token fails without token in config" {
  read -r -d '' CONFIG <<'EOF' || true
ghcr.io:
  type: github-token
  token: ""
  actor: test-user
EOF
  export CONFIG
  export SECRETS_JSON='{}'

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Token not provided" ]]
}

@test "additional-docker-logins: username-password type with ghcr.io" {
  read -r -d '' CONFIG <<'EOF' || true
ghcr.io:
  type: username-password
  username-secret: GHCR_USER
  password-secret: GHCR_PASS
EOF
  export CONFIG
  export SECRETS_JSON='{"GHCR_USER": "custom-user", "GHCR_PASS": "custom-pass"}'

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Logging in to ghcr.io with username/password" ]]
  assert_docker_called "login ghcr.io -u custom-user --password-stdin"
}

@test "additional-docker-logins: fails on unknown login type" {
  read -r -d '' CONFIG <<'EOF' || true
example.com:
  type: unknown-type
EOF
  export CONFIG
  export SECRETS_JSON='{}'

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown login type: unknown-type" ]]
}

@test "additional-docker-logins: fails when required secret is missing" {
  read -r -d '' CONFIG <<'EOF' || true
docker.io:
  type: username-password
  username-secret: MISSING_USER
  password-secret: MISSING_PASS
EOF
  export CONFIG
  export SECRETS_JSON='{}'

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Secret validation failed" ]]
  [[ "$output" =~ "Missing secrets:" ]]
  [[ "$output" =~ "MISSING_USER (docker.io)" ]]
  [[ "$output" =~ "MISSING_PASS (docker.io)" ]]
}

@test "additional-docker-logins: reports both missing and available secrets" {
  read -r -d '' CONFIG <<'EOF' || true
docker.io:
  type: username-password
  username-secret: DOCKER_USER
  password-secret: DOCKER_PASS
quay.io:
  type: username-password
  username-secret: QUAY_USER
  password-secret: QUAY_PASS
EOF
  export CONFIG
  # Only provide some secrets - QUAY ones are missing
  export SECRETS_JSON='{"DOCKER_USER": "myuser", "DOCKER_PASS": "mypass"}'

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Secret validation failed" ]]
  [[ "$output" =~ "Missing secrets:" ]]
  [[ "$output" =~ "QUAY_USER (quay.io)" ]]
  [[ "$output" =~ "QUAY_PASS (quay.io)" ]]
  [[ "$output" =~ "Available secrets:" ]]
  [[ "$output" =~ "DOCKER_USER (docker.io)" ]]
  [[ "$output" =~ "DOCKER_PASS (docker.io)" ]]
}

@test "additional-docker-logins: processes multiple registries" {
  read -r -d '' CONFIG <<'EOF' || true
docker.io:
  type: username-password
  username-secret: DOCKER_USER
  password-secret: DOCKER_PASS
quay.io:
  type: username-password
  username-secret: QUAY_USER
  password-secret: QUAY_PASS
EOF
  export CONFIG
  export SECRETS_JSON='{"DOCKER_USER": "user1", "DOCKER_PASS": "pass1", "QUAY_USER": "user2", "QUAY_PASS": "pass2"}'

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Logging in to docker.io with username/password" ]]
  [[ "$output" =~ "Logging in to quay.io with username/password" ]]
  [[ "$output" =~ "authenticated to 2 registry/registries" ]]
  assert_docker_called "login docker.io -u user1 --password-stdin"
  assert_docker_called "login quay.io -u user2 --password-stdin"
}

@test "additional-docker-logins: gcp-gar type reads service account key" {
  read -r -d '' CONFIG <<'EOF' || true
us-docker.pkg.dev:
  type: gcp-gar
  service-account-key-secret: GCP_SA_KEY
EOF
  export CONFIG
  export SECRETS_JSON='{"GCP_SA_KEY": "{\"type\":\"service_account\"}"}'

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Logging in to Google Artifact Registry" ]]
  assert_docker_called "login -u _json_key --password-stdin https://us-docker.pkg.dev"
}

@test "additional-docker-logins: azure-acr type uses service principal" {
  read -r -d '' CONFIG <<'EOF' || true
myregistry.azurecr.io:
  type: azure-acr
  client-id-secret: AZURE_CLIENT_ID
  client-secret-secret: AZURE_CLIENT_SECRET
  tenant-id-secret: AZURE_TENANT_ID
EOF
  export CONFIG
  export SECRETS_JSON='{"AZURE_CLIENT_ID": "app-id", "AZURE_CLIENT_SECRET": "secret", "AZURE_TENANT_ID": "tenant"}'

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Logging in to Azure ACR" ]]
  assert_docker_called "login myregistry.azurecr.io -u app-id --password-stdin"
}

@test "additional-docker-logins: mixed github-token and username-password" {
  read -r -d '' CONFIG <<'EOF' || true
ghcr.io:
  type: github-token
  token: gh-token
  actor: gh-user
docker.io:
  type: username-password
  username-secret: DOCKER_USER
  password-secret: DOCKER_PASS
EOF
  export CONFIG
  export SECRETS_JSON='{"DOCKER_USER": "myuser", "DOCKER_PASS": "mypass"}'

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Logging in to ghcr.io with GITHUB_TOKEN" ]]
  [[ "$output" =~ "Logging in to docker.io with username/password" ]]
  assert_docker_called "login ghcr.io -u gh-user --password-stdin"
  assert_docker_called "login docker.io -u myuser --password-stdin"
}
