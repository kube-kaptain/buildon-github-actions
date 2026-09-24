#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-run-finalise: the post-substitution gate,
# IgnoreUnresolved markers and image pull secret references. Fixtures are in
# post-substitution form. Marker grammar is covered by convert-tokens-in-tree.bats.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-run-finalise"

setup() {
  TEST_DIR=$(create_test_dir "kubernetes-run-finalise")
  SUBSTITUTED="${TEST_DIR}/kaptain-out/run-environment/manifests-substituted"
  mkdir -p "${SUBSTITUTED}" "${TEST_DIR}/src/secrets"

  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"

  export OUTPUT_SUB_PATH="kaptain-out"
  write_secret_encryption_files "${TEST_DIR}" age
  export PROJECT_NAME="run-env-test"
  export BUILD_KIND="kubernetes-run-environment"
  export VERSION="1.0.0"
  export BUILD_MODE="build_server"
  export ENVIRONMENT_WORKLOAD_CONTENTS_SUB_PATH="kaptain-out/run-environment/manifests-substituted"

  setup_mock_decryption_providers

  cd "${TEST_DIR}"
}

write_manifest() {
  local name="${1}"
  cat > "${SUBSTITUTED}/${name}"
}

IGNORES_TSV="kaptain-out/run-environment/substitution-gate-ignores.tsv"

# =============================================================================
# The gate without markers
# =============================================================================


@test "run-finalise: a missing supported types file fails" {
  rm "${TEST_DIR}/kaptain-out/run-aggregate/secret-encryption-types"
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "Supported secret encryption types not found: kaptain-out/run-aggregate/secret-encryption-types"
}

@test "run-finalise: unresolved token outside a secret template fails" {
  write_manifest plain.yaml << 'EOF'
leftover: ${Unknown}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'Unknown'"
}

@test "run-finalise: a fully resolved tree passes the gate" {
  write_manifest plain.yaml << 'EOF'
resolved: yes
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "Gate passed"
}

@test "run-finalise: secret-template token without an encrypted value fails" {
  write_manifest thing.template.yaml << 'EOF'
secret: ${SomeSecret}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'SomeSecret' in a secret template"
}

@test "run-finalise: secret-template token with an encrypted value passes" {
  printf '%s' 'ciphertext' > src/secrets/SomeSecret.age
  write_manifest thing.template.yaml << 'EOF'
secret: ${SomeSecret}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "Gate passed"
}

@test "run-finalise: an unmarked tree writes no ignores file" {
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "${IGNORES_TSV}" ]
}

# =============================================================================
# IgnoreUnresolved markers: suppression
# =============================================================================

@test "run-finalise: bare IgnoreUnresolved suppresses every token on its line" {
  write_manifest plain.yaml << 'EOF'
expected: ${RuntimeThing}-${AlsoRuntime} # IgnoreUnresolved
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "Gate passed"
}

@test "run-finalise: IgnoreUnresolved with a specifier still fails on the other token" {
  write_manifest plain.yaml << 'EOF'
partial: ${AlsoRuntime}-${Missed} # IgnoreUnresolved: ${AlsoRuntime}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'Missed'"
  # Including its occurrence inside the marker text.
  [[ "$output" != *"unresolved token 'AlsoRuntime'"* ]] || return 1
}

@test "run-finalise: IgnoreUnresolvedAbove covers the line above" {
  write_manifest plain.yaml << 'EOF'
above: ${OneRt}
# IgnoreUnresolvedAbove
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "Gate passed"
}

@test "run-finalise: IgnoreUnresolvedBelow with a specifier covers the named token" {
  write_manifest plain.yaml << 'EOF'
# IgnoreUnresolvedBelow: ${FourRt}
below: ${FourRt}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "Gate passed"
}

@test "run-finalise: IgnoreUnresolvedLines covers bare numbers and line:token entries" {
  write_manifest plain.yaml << 'EOF'
# IgnoreUnresolvedLines: 2,3:${Third}
whole: ${OneRt}-${TwoRt}
named: ${Third}-${Missed}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'Missed'"
  [[ "$output" != *"unresolved token 'OneRt'"* ]] || return 1
  [[ "$output" != *"unresolved token 'Third'"* ]] || return 1
}

@test "run-finalise: records exemptions in the ignores audit file" {
  write_manifest plain.yaml << 'EOF'
expected: ${RuntimeThing} # IgnoreUnresolved
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${IGNORES_TSV}" ]
  awk -F'\t' '$1 == "plain.yaml" && $2 == "1" && $3 == "*" { found = 1 } END { exit found ? 0 : 1 }' "${IGNORES_TSV}"
  assert_output_contains "IgnoreUnresolved markers: 1 exemption(s) across 1 file(s)."
}

# =============================================================================
# IgnoreUnresolved markers: stale markers are fatal
# =============================================================================

@test "run-finalise: a stale marker fails a server build" {
  write_manifest plain.yaml << 'EOF'
gone: value # IgnoreUnresolved
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "holds no token-shaped content"
  assert_output_contains "IgnoreUnresolved marker problem(s)"
}

@test "run-finalise: a stale marker fails a local build too" {
  export BUILD_MODE="local"
  write_manifest plain.yaml << 'EOF'
gone: value # IgnoreUnresolved
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "Marker problems fail every"
}

@test "run-finalise: unresolved tokens fail a local build too" {
  export BUILD_MODE="local"
  write_manifest plain.yaml << 'EOF'
leftover: ${Unknown}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'Unknown'"
}

@test "run-finalise: a secret template without a value names both possible causes" {
  write_manifest thing.template.yaml << 'EOF'
secret: ${SomeSecret}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "no config value supplied it"
  assert_output_contains "no encrypted value at"
}

@test "run-finalise: a secret template without a value fails a local build too" {
  export BUILD_MODE="local"
  write_manifest thing.template.yaml << 'EOF'
secret: ${SomeSecret}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "run-finalise: a marker naming a token that resolved is stale" {
  # '${Known}-${Unknown} # IgnoreUnresolved: ${Known}' after substituting Known=yes.
  write_manifest plain.yaml << 'EOF'
resolved: yes-${Unknown} # IgnoreUnresolved: yes
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "is not a token reference"
}

@test "run-finalise: a marker naming a token absent from the line is stale" {
  write_manifest plain.yaml << 'EOF'
here: ${Present} # IgnoreUnresolved: ${Elsewhere}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "is not present on"
}

@test "run-finalise: IgnoreUnresolvedAbove on the first line fails" {
  write_manifest plain.yaml << 'EOF'
# IgnoreUnresolvedAbove
below: ${OneRt}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "has no line above it"
}

@test "run-finalise: a marker in a secret template covers legitimate token-shaped content" {
  write_manifest thing.template.yaml << 'EOF'
script: echo ${HOME} # IgnoreUnresolved
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "Gate passed"
}

@test "run-finalise: a specifier in a secret template leaves other tokens needing a value" {
  write_manifest thing.template.yaml << 'EOF'
line: ${HOME} ${SomeSecret} # IgnoreUnresolved: ${HOME}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'SomeSecret' in a secret template"
  assert_output_not_contains "unresolved token 'HOME'"
}

@test "run-finalise: a stale marker in a secret template still fails" {
  write_manifest thing.template.yaml << 'EOF'
plain: nothing # IgnoreUnresolved
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "IgnoreUnresolved marker problem"
}

# =============================================================================
# Nested token names and encrypted value suffixes
# =============================================================================

@test "run-finalise: unresolved nested token fails the gate" {
  write_manifest plain.yaml << 'EOF'
leftover: ${Vendor/Unknown}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'Vendor/Unknown'"
}

@test "run-finalise: nested secret-template token without a value fails" {
  printf '%s' 'ciphertext' > src/secrets/DbPassword.age
  write_manifest thing.template.yaml << 'EOF'
secret: ${Vendor/DbPassword}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'Vendor/DbPassword' in a secret template"
}

@test "run-finalise: nested secret-template token with a nested value passes" {
  mkdir -p src/secrets/Vendor
  printf '%s' 'ciphertext' > src/secrets/Vendor/DbPassword.sha256.aes256.10k
  write_manifest thing.template.yaml << 'EOF'
secret: ${Vendor/DbPassword}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "Gate passed"
}

@test "run-finalise: the gate matches tokens in the configured delimiter style" {
  export TOKEN_DELIMITER_STYLE="mustache"
  write_manifest plain.yaml << 'EOF'
leftover: {{ Vendor/Unknown }}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'Vendor/Unknown'"
}

# =============================================================================
# Gate placement: after the yq patches, before the checksum pass
# =============================================================================

@test "run-finalise: a token injected by a yq patch fails the gate" {
  write_manifest configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app
data:
  mode: plain
EOF
  write_manifest configmap.yaml.yq-expression-list-inject << 'EOF'
.data.mode = "${Injected}"
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "1 patch(es) applied"
  assert_output_contains "configmap.yaml: unresolved token 'Injected'"
}

@test "run-finalise: a missing secret value is reported by the gate, not the checksum pass" {
  write_manifest secret.template.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: app-secret-checksum
stringData:
  password: ${SomeSecret}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'SomeSecret' in a secret template"
  assert_output_not_contains "Resource checksum pass"
  assert_output_not_contains "upstream substitution gate should have failed"
}

# =============================================================================
# Image pull secret references (generation is tested in kubernetes-run-substitute.bats)
# =============================================================================

write_pulling_deployment() {
  local file="${1}" registry="${2}"
  write_manifest "${file}" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${file%.yaml}
spec:
  template:
    spec:
      imagePullSecrets:
        - name: ${registry}
      containers:
        - name: app
          image: ${registry}/team/app:1.0.0
EOF
}

@test "run-finalise: pull secret references: a reference with a generated Secret passes" {
  write_pulling_deployment app.yaml ghcr.io
  mkdir -p "${SUBSTITUTED}/kaptain-image-pull-secrets"
  write_manifest kaptain-image-pull-secrets/ghcr-io.template.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: ghcr.io
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{"auths":{"ghcr.io":{"username":"${ImagePullSecrets/GhcrIo/Username}","password":"${ImagePullSecrets/GhcrIo/Password}"}}}'
EOF
  mkdir -p src/secrets/ImagePullSecrets/GhcrIo
  printf '%s' 'ciphertext' > src/secrets/ImagePullSecrets/GhcrIo/Username.age
  printf '%s' 'ciphertext' > src/secrets/ImagePullSecrets/GhcrIo/Password.age
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "Every referenced image pull secret has a Secret."
}

@test "run-finalise: pull secret references: a reference with a supplied Secret passes" {
  write_pulling_deployment app.yaml ghcr.io
  write_manifest pull-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: ghcr.io
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30=
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "run-finalise: pull secret references: a reference without a Secret fails with generation off" {
  export ENV_AUTO_GENERATE_IMAGE_PULL_SECRETS="false"
  write_pulling_deployment app.yaml ghcr.io
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "imagePullSecrets name 'ghcr.io' has no Secret in the tree"
}

@test "run-finalise: pull secret references: a reference a yq patch adds needs a Secret" {
  write_manifest app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
        - name: app
          image: ghcr.io/team/app:1.0.0
EOF
  write_manifest app.yaml.yq-expression-list-pull << 'EOF'
.spec.template.spec.imagePullSecrets = [{"name": "ghcr.io"}]
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "1 patch(es) applied"
  assert_output_contains "imagePullSecrets name 'ghcr.io' has no Secret in the tree"
}

@test "run-finalise: pull secret references: every missing Secret is listed before failing" {
  write_pulling_deployment one.yaml ghcr.io
  write_pulling_deployment two.yaml registry.example.com
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "'ghcr.io' has no Secret"
  assert_output_contains "'registry.example.com' has no Secret"
  assert_output_contains "2 image pull secret reference(s) without a Secret"
}

# =============================================================================
# Run-platform builds: the same secret handling as env builds
# =============================================================================

@test "run-finalise: run-platform: a secret-template token without a value fails the gate" {
  export BUILD_KIND="kubernetes-run-platform-meta-environment"
  write_manifest thing.template.yaml << 'EOF'
secret: ${SomeSecret}
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unresolved token 'SomeSecret' in a secret template"
}

@test "run-finalise: run-platform: Secret templates are checksummed at build" {
  export BUILD_KIND="kubernetes-run-platform-meta-environment"
  printf '%s' 'ciphertext' > src/secrets/SomeSecret.age
  write_manifest secret.template.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: app-secret-checksum
stringData:
  password: ${SomeSecret}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local name
  name=$(yq '.metadata.name' kaptain-out/run-environment/manifests-final/secret.template.yaml)
  [[ "${name}" == app-* && "${name}" != app-secret-checksum ]]
}

@test "run-finalise: run-platform: the content data carries the short run kind" {
  export BUILD_KIND="kubernetes-run-platform-meta-environment"
  write_manifest plain.yaml << 'EOF'
resolved: yes
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local cm=kaptain-out/run-environment/manifests-final/kaptain-environment-content-data.yaml
  [ "$(yq '.metadata.labels."kaptain.org/run-kind"' "${cm}")" = "run-platform" ]
}

@test "run-finalise: an environment's content data carries the short run kind" {
  write_manifest plain.yaml << 'EOF'
resolved: yes
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local cm=kaptain-out/run-environment/manifests-final/kaptain-environment-content-data.yaml
  [ "$(yq '.metadata.labels."kaptain.org/run-kind"' "${cm}")" = "environment" ]
}

teardown() {
  dump_bats_result
}
