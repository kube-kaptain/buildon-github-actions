#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-run-substitute.
#
# The post-substitution gate is tested in kubernetes-run-finalise.bats.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-run-substitute"

setup() {
  TEST_DIR=$(create_test_dir "kubernetes-run-substitute")
  PRUNED="${TEST_DIR}/kaptain-out/run-environment/manifests-pruned"
  mkdir -p "${PRUNED}" "${TEST_DIR}/src/config" "${TEST_DIR}/src/secrets"

  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"

  export OUTPUT_SUB_PATH="kaptain-out"
  write_secret_encryption_files "${TEST_DIR}" age
  export PROJECT_NAME="run-env-test"
  export BUILD_KIND="kubernetes-run-environment"
  export ENVIRONMENT_SHORT_NAME="test"
  export BUILD_MODE="build_server"
  # Keeps fixtures minimal; unreferenced-value tests turn it back on.
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="false"

  # prepare-substitution-tokens requires the full version/docker family.
  export VERSION="1.0.0"
  export VERSION_MAJOR="1" VERSION_MINOR="0" VERSION_PATCH="0"
  export VERSION_2_PART="1.0" VERSION_3_PART="1.0.0" VERSION_4_PART="1.0.0.0"
  export VERSION_DNS_SAFE="1-0-0" VERSION_2_PART_DNS_SAFE="1-0"
  export VERSION_3_PART_DNS_SAFE="1-0-0" VERSION_4_PART_DNS_SAFE="1-0-0-0"
  export GIT_TAG="v1.0.0" IS_RELEASE="false"
  export DOCKER_TAG="testtag" DOCKER_IMAGE_NAME="testimage"

  setup_mock_decryption_providers

  cd "${TEST_DIR}"
}

write_manifest() {
  local name="${1}"
  cat > "${PRUNED}/${name}"
}

# =============================================================================
# The gate is not here
# =============================================================================


@test "run-substitute: a missing supported types file fails" {
  rm "${TEST_DIR}/kaptain-out/run-aggregate/secret-encryption-types"
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "Supported secret encryption types not found: kaptain-out/run-aggregate/secret-encryption-types"
}

@test "run-substitute: unresolved tokens are left for the finalise gate" {
  write_manifest plain.yaml << 'EOF'
leftover: ${Unknown}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qF 'leftover: ${Unknown}' kaptain-out/run-environment/manifests-substituted/plain.yaml
  [ ! -f kaptain-out/run-environment/substitution-gate-ignores.tsv ]
}

# =============================================================================
# Nested token names and encrypted value suffixes
# =============================================================================

@test "run-substitute: reads the pruned tree, so a deleted manifest is neither substituted nor counted" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  printf '%s' 'gone' > src/config/OnlyInDeleted
  # Present in the merged tree, removed from the pruned one by a delete.
  mkdir -p kaptain-out/run-environment/manifests-aggregated
  printf 'value: ${OnlyInDeleted}\n' > kaptain-out/run-environment/manifests-aggregated/deleted.yaml
  write_manifest kept.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced config value 'OnlyInDeleted'"
  [ ! -e kaptain-out/run-environment/manifests-substituted/deleted.yaml ]
  [ -f kaptain-out/run-environment/manifests-substituted/kept.yaml ]
}

@test "run-substitute: referenced nested config and secret values are not unreferenced" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  mkdir -p src/config/Vendor src/secrets/Vendor
  printf '%s' 'db.internal' > src/config/Vendor/DbHost
  printf '%s' 'ciphertext' > src/secrets/Vendor/DbPassword.age
  write_manifest plain.yaml << 'EOF'
host: ${Vendor/DbHost}
EOF
  write_manifest thing.template.yaml << 'EOF'
secret: ${Vendor/DbPassword}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx '  - Vendor/DbHost' kaptain-out/run-environment/token-usage.yaml
}

@test "run-substitute: unreferenced values are named by token, nested path kept, suffix dropped" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  mkdir -p src/config/Vendor src/secrets/Vendor
  printf '%s' 'db.internal' > src/config/Vendor/DbHost
  printf '%s' 'ciphertext' > src/secrets/Vendor/DbPassword.age
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced config value 'Vendor/DbHost'"
  assert_output_contains "unreferenced secret value 'Vendor/DbPassword'"
  assert_output_not_contains "DbPassword.age"
  assert_output_contains "2 unreferenced config/secret value(s)"
}

@test "run-substitute: a run-platform build checks its own secret values too" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  export BUILD_KIND="kubernetes-run-platform-meta-environment"
  mkdir -p kaptain-out/run-platform-meta-environment/manifests-pruned
  printf 'plain: here\n' > kaptain-out/run-platform-meta-environment/manifests-pruned/plain.yaml
  printf '%s' 'ciphertext' > src/secrets/EnvApiToken.age
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced secret value 'EnvApiToken'"
}

@test "run-substitute: a leftover deploy-manifests tree does not count as a reference" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  printf '%s' 'ciphertext' > src/secrets/EnvApiToken.age
  mkdir -p kaptain-out/run-image-deploy-manifests/manifests
  printf 'api-token: ${EnvApiToken}\n' > kaptain-out/run-image-deploy-manifests/manifests/secret.template.yaml
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced secret value 'EnvApiToken'"
}

@test "run-substitute: ENVIRONMENT_TYPE is env for an environment" {
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat kaptain-out/run-environment/config-final/EnvironmentType)" = "env" ]
}

@test "run-substitute: ENVIRONMENT_TYPE is meta-env for a run-platform" {
  export BUILD_KIND="kubernetes-run-platform-meta-environment"
  mkdir -p kaptain-out/run-platform-meta-environment/manifests-pruned
  printf 'plain: here\n' > kaptain-out/run-platform-meta-environment/manifests-pruned/plain.yaml
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat kaptain-out/run-platform-meta-environment/config-final/EnvironmentType)" = "meta-env" ]
}

@test "run-substitute: references are counted in the configured delimiter style" {
  export TOKEN_DELIMITER_STYLE="mustache"
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  mkdir -p src/config/Vendor
  printf '%s' 'db.internal' > src/config/Vendor/DbHost
  write_manifest plain.yaml << 'EOF'
host: {{ Vendor/DbHost }}
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx '  - Vendor/DbHost' kaptain-out/run-environment/token-usage.yaml
}

# =============================================================================
# Image pull secrets (spec.main.environment.autoGenerateImagePullSecrets)
# =============================================================================

PULL_SECRETS_DIR="kaptain-out/run-environment/manifests-substituted/kaptain-image-pull-secrets"

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
          image: registry/team/app:1.0.0
EOF
}

write_pull_secret_values() {
  local segment="${1}"
  mkdir -p "src/secrets/ImagePullSecrets/${segment}"
  printf '%s' 'ciphertext' > "src/secrets/ImagePullSecrets/${segment}/Username.age"
  printf '%s' 'ciphertext' > "src/secrets/ImagePullSecrets/${segment}/Password.age"
}

@test "run-substitute: pull secrets: one dockerconfigjson Secret template per registry referenced" {
  write_pulling_deployment app.yaml ghcr.io
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local generated="${PULL_SECRETS_DIR}/ghcr-io.template.yaml"
  [ "$(yq '.kind' "${generated}")" = "Secret" ]
  [ "$(yq '.type' "${generated}")" = "kubernetes.io/dockerconfigjson" ]
  [ "$(yq '.metadata.name' "${generated}")" = "ghcr.io" ]
  [ "$(yq '.metadata.namespace' "${generated}")" = "run-env-test" ]
  [ "$(yq '.stringData.".dockerconfigjson"' "${generated}")" = '{"auths":{"ghcr.io":{"username":"${ImagePullSecrets/GhcrIo/Username}","password":"${ImagePullSecrets/GhcrIo/Password}"}}}' ]
  [ -f kaptain-out/run-environment/image-pull-secrets-generated/kaptain-image-pull-secrets/ghcr-io.template.yaml ]
}

@test "run-substitute: pull secrets: a name built from a token is generated from its value" {
  printf '%s' 'ghcr.io' > src/config/EnvironmentDockerRegistry
  write_pulling_deployment app.yaml '${EnvironmentDockerRegistry}'
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.name' "${PULL_SECRETS_DIR}/ghcr-io.template.yaml")" = "ghcr.io" ]
}

@test "run-substitute: pull secrets: generated templates get the substitution pass" {
  mkdir -p src/config/ImagePullSecrets/GhcrIo
  printf '%s' 'robot' > src/config/ImagePullSecrets/GhcrIo/Username
  write_pulling_deployment app.yaml ghcr.io
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.stringData.".dockerconfigjson"' "${PULL_SECRETS_DIR}/ghcr-io.template.yaml")" = '{"auths":{"ghcr.io":{"username":"robot","password":"${ImagePullSecrets/GhcrIo/Password}"}}}' ]
  grep -qx '  - ImagePullSecrets/GhcrIo/Username' kaptain-out/run-environment/token-usage.yaml
}

@test "run-substitute: pull secrets: a name chained through config resolves with the configured passes" {
  export TOKEN_SUBSTITUTION_PASSES="2"
  # The inner token sorts first, so a single pass leaves it unresolved.
  printf '%s' '${ARegistryHost}' > src/config/EnvironmentDockerRegistry
  printf '%s' 'ghcr.io' > src/config/ARegistryHost
  write_pulling_deployment app.yaml '${EnvironmentDockerRegistry}'
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.name' "${PULL_SECRETS_DIR}/ghcr-io.template.yaml")" = "ghcr.io" ]
}

@test "run-substitute: pull secrets: generated templates get the configured passes" {
  export TOKEN_SUBSTITUTION_PASSES="2"
  mkdir -p src/config/ImagePullSecrets/GhcrIo
  # The inner token sorts first, so a single pass leaves it unresolved.
  printf '%s' '${ARobotName}' > src/config/ImagePullSecrets/GhcrIo/Username
  printf '%s' 'robot' > src/config/ARobotName
  write_pulling_deployment app.yaml ghcr.io
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.stringData.".dockerconfigjson"' "${PULL_SECRETS_DIR}/ghcr-io.template.yaml")" = '{"auths":{"ghcr.io":{"username":"robot","password":"${ImagePullSecrets/GhcrIo/Password}"}}}' ]
}

@test "run-substitute: pull secrets: values only the generated Secrets use are referenced" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  write_pulling_deployment app.yaml ghcr.io
  write_pull_secret_values GhcrIo
  run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "run-substitute: pull secrets: a value no generated Secret uses is unreferenced" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  write_pulling_deployment app.yaml ghcr.io
  write_pull_secret_values GhcrIo
  write_pull_secret_values DockerIo
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced secret value 'ImagePullSecrets/DockerIo/Password'"
  assert_output_contains "unreferenced secret value 'ImagePullSecrets/DockerIo/Username'"
  assert_output_not_contains "'ImagePullSecrets/GhcrIo/"
  assert_output_contains "2 unreferenced config/secret value(s)"
}

@test "run-substitute: pull secrets: an unused value only warns when unreferenced values are tolerated" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="false"
  write_pull_secret_values DockerIo
  write_manifest plain.yaml << 'EOF'
nothing: here
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_contains "unreferenced secret value 'ImagePullSecrets/DockerIo/Username'"
}

@test "run-substitute: pull secrets: values are unreferenced when generation is off" {
  export ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="true"
  export ENV_AUTO_GENERATE_IMAGE_PULL_SECRETS="false"
  write_pulling_deployment app.yaml ghcr.io
  write_pull_secret_values GhcrIo
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "unreferenced secret value 'ImagePullSecrets/GhcrIo/Password'"
  [ ! -e "${PULL_SECRETS_DIR}" ]
}

@test "run-substitute: pull secrets: a registry referenced twice gets one Secret" {
  write_pulling_deployment one.yaml ghcr.io
  write_pulling_deployment two.yaml ghcr.io
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(find "${PULL_SECRETS_DIR}" -type f | grep -c .)" -eq 1 ]
}

@test "run-substitute: pull secrets: a ServiceAccount reference is generated too" {
  write_manifest serviceaccount.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
imagePullSecrets:
  - name: registry.example.com
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${PULL_SECRETS_DIR}/registry-example-com.template.yaml" ]
}

@test "run-substitute: pull secrets: a supplied Secret of the same name is left alone" {
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
  assert_output_contains "ghcr.io: supplied by pull-secret.yaml, not generated"
  [ ! -e "${PULL_SECRETS_DIR}" ]
}

@test "run-substitute: pull secrets: the token names follow the configured name style" {
  export TOKEN_NAME_STYLE="UPPER_SNAKE"
  write_pulling_deployment app.yaml ghcr.io
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qF '${IMAGE_PULL_SECRETS/GHCR_IO/USERNAME}' "${PULL_SECRETS_DIR}/ghcr-io.template.yaml"
}

@test "run-substitute: pull secrets: two registries converting to the same segment fail" {
  write_pulling_deployment one.yaml a.example.com
  write_pulling_deployment two.yaml a-example.com
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "both convert to 'a-example-com'"
}

@test "run-substitute: pull secrets: a name that is not a valid Secret name fails" {
  write_pulling_deployment app.yaml Registry.Example.com
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "'Registry.Example.com' is not a valid Secret name"
}

@test "run-substitute: pull secrets: the reserved directory may not be supplied" {
  mkdir -p "${PRUNED}/kaptain-image-pull-secrets"
  write_manifest kaptain-image-pull-secrets/mine.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mine
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "kaptain-image-pull-secrets/ is reserved"
}

@test "run-substitute: pull secrets: a file left unparseable by an unresolved token is left to the gate" {
  write_pulling_deployment app.yaml ghcr.io
  write_manifest watch.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: watch
data:
  namespaces: [${Missing}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${PULL_SECRETS_DIR}/ghcr-io.template.yaml" ]
}

@test "run-substitute: pull secrets: an unparseable file without a token fails" {
  write_manifest broken.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
data: [unclosed
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "broken.yaml: not parseable YAML"
}

@test "run-substitute: pull secrets: generation off writes nothing" {
  export ENV_AUTO_GENERATE_IMAGE_PULL_SECRETS="false"
  write_pulling_deployment app.yaml ghcr.io
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "${PULL_SECRETS_DIR}" ]
}

@test "run-substitute: pull secrets: run-platform builds generate them too" {
  export BUILD_KIND="kubernetes-run-platform-meta-environment"
  mkdir -p kaptain-out/run-platform-meta-environment/manifests-pruned
  PRUNED="kaptain-out/run-platform-meta-environment/manifests-pruned"
  write_pulling_deployment app.yaml ghcr.io
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f kaptain-out/run-platform-meta-environment/manifests-substituted/kaptain-image-pull-secrets/ghcr-io.template.yaml ]
}

teardown() {
  dump_bats_result
}
