#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kubernetes-run-image-deploy-manifests: staging and
# fill-the-gaps generation of the deploy-manifests set.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$SCRIPTS_DIR/kubernetes-run-image-deploy-manifests"

setup() {
  TEST_DIR=$(create_test_dir "kubernetes-run-image-deploy-manifests")
  mkdir -p "${TEST_DIR}/kaptainpm/final"
  printf 'apiVersion: kaptain.org/1.2\nkind: kubernetes-run-environment\n' \
    > "${TEST_DIR}/kaptainpm/final/KaptainPM.yaml"
  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  : > "${GITHUB_OUTPUT}"
  export BUILD_PLATFORM="local"
  export PROJECT_NAME="run-foo"
  export VERSION="1.0.0"
  export OUTPUT_SUB_PATH="kaptain-out"
  cd "${TEST_DIR}"
}

teardown() {
  dump_bats_result
}

MANIFESTS="kaptain-out/run-image-deploy-manifests/manifests"
DEFAULTS="kaptain-out/run-image-deploy-manifests/defaults"

# =============================================================================
# Secret
# =============================================================================

@test "secret: generated with a project-prefixed environmentPassphrase token" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.stringData.environmentPassphrase' "${MANIFESTS}/secret.template.yaml")" = '${RunFoo/EnvironmentPassphrase}' ]
}

@test "secret: the token follows the configured name style" {
  TOKEN_NAME_STYLE=UPPER_SNAKE run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.stringData.environmentPassphrase' "${MANIFESTS}/secret.template.yaml")" = '${RUN_FOO/ENVIRONMENT_PASSPHRASE}' ]
}

@test "secret: user secret.template entries are kept alongside the passphrase" {
  mkdir -p src/environment/secret.template
  printf '%s' 'x' > src/environment/secret.template/apiKey
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.stringData.apiKey' "${MANIFESTS}/secret.template.yaml")" = "x" ]
  [ "$(yq '.stringData.environmentPassphrase' "${MANIFESTS}/secret.template.yaml")" = '${RunFoo/EnvironmentPassphrase}' ]
}

@test "secret: a user-supplied environmentPassphrase entry is not overwritten" {
  mkdir -p src/environment/secret.template
  printf '%s' 'mine' > src/environment/secret.template/environmentPassphrase
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.stringData.environmentPassphrase' "${MANIFESTS}/secret.template.yaml")" = "mine" ]
}

@test "secret: a supplied Secret manifest without environmentPassphrase fails" {
  mkdir -p src/environment/kubernetes
  cat > src/environment/kubernetes/secret.template.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: run-foo-secret-checksum
stringData:
  other: x
EOF
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "has no stringData.environmentPassphrase key"
}

@test "secret: a supplied Secret manifest with environmentPassphrase passes" {
  mkdir -p src/environment/kubernetes
  cat > src/environment/kubernetes/secret.template.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: run-foo-secret-checksum
stringData:
  environmentPassphrase: x
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Namespace
# =============================================================================

@test "namespace: generated into the set, named for the project, cluster-scoped with no spec" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.kind' "${MANIFESTS}/namespace.yaml")" = "Namespace" ]
  [ "$(yq '.metadata.name' "${MANIFESTS}/namespace.yaml")" = '${ProjectName}' ]
  [ "$(yq '.metadata | has("namespace")' "${MANIFESTS}/namespace.yaml")" = "false" ]
  [ "$(yq 'has("spec")' "${MANIFESTS}/namespace.yaml")" = "false" ]
}

@test "namespace: a run-platform's set gets its own too" {
  export PROJECT_NAME="run-platform-foo"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.name' "${MANIFESTS}/namespace.yaml")" = '${ProjectName}' ]
}

@test "namespace: carries spec.main.environment.namespace labels and annotations" {
  export ENV_NAMESPACE_ADDITIONAL_LABELS="tier=platform"
  export ENV_NAMESPACE_ADDITIONAL_ANNOTATIONS="owner=platform-team"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.labels.tier' "${MANIFESTS}/namespace.yaml")" = "platform" ]
  [ "$(yq '.metadata.annotations.owner' "${MANIFESTS}/namespace.yaml")" = "platform-team" ]
}

@test "namespace: a supplied Namespace is used and none is generated" {
  mkdir -p src/environment/kubernetes
  cat > src/environment/kubernetes/my-namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: ${ProjectName}
  labels:
    supplied: "yes"
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  assert_output_not_contains "Generating Namespace"
  [ ! -e "${MANIFESTS}/namespace.yaml" ]
  [ "$(yq '.metadata.labels.supplied' "${MANIFESTS}/my-namespace.yaml")" = "yes" ]
}

# =============================================================================
# ConfigMap
# =============================================================================

@test "configmap: generated with a project-name key and mounted when there is no source" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.data | keys | join(",")' "${MANIFESTS}/configmap.yaml")" = "project-name" ]
  [ "$(yq '.data.project-name' "${MANIFESTS}/configmap.yaml")" = '${ProjectName}' ]
  [ "$(yq '.spec.template.spec.volumes[] | select(.name == "configmap") | .configMap.name' "${MANIFESTS}/deployment.yaml")" = \
    "$(yq '.metadata.name' "${MANIFESTS}/configmap.yaml")" ]
}

@test "configmap: user entries are included" {
  mkdir -p src/environment/configmap
  printf '%s' 'v' > src/environment/configmap/key
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.data.key' "${MANIFESTS}/configmap.yaml")" = "v" ]
  [ "$(yq '.data.project-name' "${MANIFESTS}/configmap.yaml")" = '${ProjectName}' ]
}

@test "configmap: the project-name value follows the configured token style" {
  TOKEN_DELIMITER_STYLE=mustache TOKEN_NAME_STYLE=UPPER_SNAKE run "$SCRIPT"
  [ "$status" -eq 0 ]
  # Unsubstituted mustache tokens make the file unparseable as YAML.
  grep -qxF '  project-name: "{{ PROJECT_NAME }}"' "${MANIFESTS}/configmap.yaml"
}

@test "styles: every delimiter style generates, with no product labels left" {
  local style
  for style in shell mustache helm erb github-actions blade stringtemplate ognl t4 swift; do
    rm -rf kaptain-out
    TOKEN_DELIMITER_STYLE="${style}" run "$SCRIPT"
    [ "$status" -eq 0 ] || { echo "style ${style} failed"; return 1; }
    [ "$(grep -rlE 'part-of|kaptain.org/product' "${MANIFESTS}" | wc -l | tr -d ' ')" -eq 0 ] || { echo "style ${style} kept product labels"; return 1; }
  done
}

@test "configmap: a user-supplied project-name entry is not overwritten" {
  mkdir -p src/environment/configmap
  printf '%s' 'mine' > src/environment/configmap/project-name
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.data.project-name' "${MANIFESTS}/configmap.yaml")" = "mine" ]
}

@test "configmap: job mode CronJob and zero-scale Deployment both mount it" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '[.spec.jobTemplate.spec.template.spec.volumes[].name] | contains(["configmap"])' "${MANIFESTS}/cronjob.yaml")" = "true" ]
  [ "$(yq '[.spec.template.spec.volumes[].name] | contains(["configmap"])' "${MANIFESTS}/deployment.yaml")" = "true" ]
}

# =============================================================================
# Deploy workload
# =============================================================================

@test "deployment: runs /kd/bin/deploy with the deploy pod settings" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local spec='.spec.template.spec'
  local d="${MANIFESTS}/deployment.yaml"
  [ "$(yq "${spec}.containers[0].command[0]" "$d")" = "/kd/bin/deploy" ]
  [ "$(yq "${spec}.automountServiceAccountToken" "$d")" = "true" ]
  [ "$(yq "${spec}.terminationGracePeriodSeconds" "$d")" = "86400" ]
  [ "$(yq "${spec}.containers[0].securityContext.readOnlyRootFilesystem" "$d")" = "false" ]
  [ "$(yq "${spec}.containers[0] | has(\"ports\")" "$d")" = "false" ]
}

@test "deployment: memory and cpu request are project-prefixed tokens, no cpu limit" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local r='.spec.template.spec.containers[0].resources'
  local d="${MANIFESTS}/deployment.yaml"
  [ "$(yq "${r}.requests.memory" "$d")" = '${RunFoo/Memory}' ]
  [ "$(yq "${r}.limits.memory" "$d")" = '${RunFoo/Memory}' ]
  [ "$(yq "${r}.requests.cpu" "$d")" = '${RunFoo/CpuRequest}' ]
  [ "$(yq "${r}.limits | has(\"cpu\")" "$d")" = "false" ]
}

@test "defaults: Memory 100Mi and CpuRequest 100m are written" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "${DEFAULTS}/RunFoo/Memory")" = "100Mi" ]
  [ "$(cat "${DEFAULTS}/RunFoo/CpuRequest")" = "100m" ]
}

@test "defaults: a user-supplied Memory default is not overwritten" {
  mkdir -p src/environment/defaults/RunFoo
  printf '%s' '256Mi' > src/environment/defaults/RunFoo/Memory
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "${DEFAULTS}/RunFoo/Memory")" = "256Mi" ]
}

@test "cronjob: job mode runs /kd/bin/deploy with the deploy pod settings" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson run "$SCRIPT"
  [ "$status" -eq 0 ]
  local spec='.spec.jobTemplate.spec.template.spec'
  local c="${MANIFESTS}/cronjob.yaml"
  [ "$(yq "${spec}.containers[0].command[0]" "$c")" = "/kd/bin/deploy" ]
  [ "$(yq "${spec}.automountServiceAccountToken" "$c")" = "true" ]
  [ "$(yq "${spec}.terminationGracePeriodSeconds" "$c")" = "86400" ]
  [ "$(yq "${spec}.containers[0].securityContext.readOnlyRootFilesystem" "$c")" = "false" ]
  [ "$(yq "${spec}.containers[0] | has(\"ports\")" "$c")" = "false" ]
  [ "$(yq "${spec}.containers[0].resources.requests.memory" "$c")" = '${RunFoo/Memory}' ]
}

cronjob_env() {
  yq ".spec.jobTemplate.spec.template.spec.containers[0].env[] | select(.name == \"$1\") | .value" "${MANIFESTS}/cronjob.yaml"
}

@test "cronjob: job mode sets the post-deploy sleeps in seconds, defaulting to 10m and 24h" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_SUCCESS)" = "600" ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_FAILURE)" = "86400" ]
}

@test "cronjob: configured post-deploy sleeps convert each unit" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson \
    ENV_JOB_POST_DEPLOY_SLEEP_AFTER_SUCCESS=15m ENV_JOB_POST_DEPLOY_SLEEP_AFTER_FAILURE=2w run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_SUCCESS)" = "900" ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_FAILURE)" = "1209600" ]
}

@test "cronjob: a unit-less post-deploy sleep is seconds" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson \
    ENV_JOB_POST_DEPLOY_SLEEP_AFTER_SUCCESS=45 ENV_JOB_POST_DEPLOY_SLEEP_AFTER_FAILURE=0 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_SUCCESS)" = "45" ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_FAILURE)" = "0" ]
}

@test "cronjob: a zero post-deploy sleep is kept" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson \
    ENV_JOB_POST_DEPLOY_SLEEP_AFTER_SUCCESS=0s ENV_JOB_POST_DEPLOY_SLEEP_AFTER_FAILURE=3d run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_SUCCESS)" = "0" ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_FAILURE)" = "259200" ]
}

@test "cronjob: a post-deploy sleep of exactly a year is accepted" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson \
    ENV_JOB_POST_DEPLOY_SLEEP_AFTER_SUCCESS=365d ENV_JOB_POST_DEPLOY_SLEEP_AFTER_FAILURE=31536000 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_SUCCESS)" = "31536000" ]
  [ "$(cronjob_env POST_DEPLOY_SLEEP_FAILURE)" = "31536000" ]
}

@test "cronjob: post-deploy sleeps over a year fail, in any unit" {
  local value
  for value in 366d 53w 8761h 525601m 31536001s 31536001; do
    ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson ENV_JOB_POST_DEPLOY_SLEEP_AFTER_FAILURE="${value}" run "$SCRIPT"
    [ "$status" -ne 0 ] || { echo "${value} was accepted"; return 1; }
    assert_output_contains "ENV_JOB_POST_DEPLOY_SLEEP_AFTER_FAILURE must be seconds, or an integer and one of s m h d w, up to a year"
  done
}

@test "cronjob: a post-deploy sleep with a leading zero fails" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson ENV_JOB_POST_DEPLOY_SLEEP_AFTER_SUCCESS=010m run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "ENV_JOB_POST_DEPLOY_SLEEP_AFTER_SUCCESS must be seconds"
}

@test "cronjob: a compound post-deploy sleep fails" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson ENV_JOB_POST_DEPLOY_SLEEP_AFTER_SUCCESS=1h30m run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "ENV_JOB_POST_DEPLOY_SLEEP_AFTER_SUCCESS must be seconds"
}

@test "cronjob: the job-mode companion Deployment carries no post-deploy sleeps" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson run "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q 'POST_DEPLOY_SLEEP' "${MANIFESTS}/deployment.yaml"
}

@test "deployment mode: the Deployment carries no post-deploy sleeps" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q 'POST_DEPLOY_SLEEP' "${MANIFESTS}/deployment.yaml"
}

# =============================================================================
# Image pull secrets (spec.main.environment.imagePullSecrets)
# =============================================================================

@test "pull secrets: enabled by default on the Deployment, naming the registry token" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.spec.template.spec.imagePullSecrets[0].name' "${MANIFESTS}/deployment.yaml")" = '${EnvironmentDockerRegistry}' ]
}

@test "pull secrets: DISABLED leaves them off the Deployment" {
  ENV_IMAGE_PULL_SECRETS=DISABLED run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.spec.template.spec | has("imagePullSecrets")' "${MANIFESTS}/deployment.yaml")" = "false" ]
}

@test "pull secrets: DISABLED leaves them off the CronJob and the zero-scale Deployment" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson ENV_IMAGE_PULL_SECRETS=DISABLED run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.spec.jobTemplate.spec.template.spec | has("imagePullSecrets")' "${MANIFESTS}/cronjob.yaml")" = "false" ]
  [ "$(yq '.spec.template.spec | has("imagePullSecrets")' "${MANIFESTS}/deployment.yaml")" = "false" ]
}

@test "pull secrets: job mode carries them on the CronJob and the zero-scale Deployment by default" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.spec.jobTemplate.spec.template.spec.imagePullSecrets[0].name' "${MANIFESTS}/cronjob.yaml")" = '${EnvironmentDockerRegistry}' ]
  [ "$(yq '.spec.template.spec.imagePullSecrets[0].name' "${MANIFESTS}/deployment.yaml")" = '${EnvironmentDockerRegistry}' ]
}

@test "pull secrets: an inherited app-level workload setting does not leak in" {
  KUBERNETES_WORKLOAD_IMAGE_PULL_SECRETS=DISABLED run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.spec.template.spec | has("imagePullSecrets")' "${MANIFESTS}/deployment.yaml")" = "true" ]
}

@test "pull secrets: a value other than ENABLED or DISABLED fails" {
  ENV_IMAGE_PULL_SECRETS=false run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "ENV_IMAGE_PULL_SECRETS must be 'ENABLED' or 'DISABLED', got 'false'"
}

# =============================================================================
# Image auto-update annotations
# =============================================================================

@test "auto-update: keelson polls with @every and omits the default mimic strategy" {
  ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson run "$SCRIPT"
  [ "$status" -eq 0 ]
  local a='.metadata.annotations'
  [ "$(yq "${a}.\"keelson.pro/poll-schedule\"" "${MANIFESTS}/deployment.yaml")" = "@every 1m" ]
  [ "$(yq "${a} | has(\"keelson.pro/field-manager-strategy\")" "${MANIFESTS}/deployment.yaml")" = "false" ]
}

@test "auto-update: keelson accepts a seconds poll schedule" {
  ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson ENV_IMAGE_AUTO_UPDATE_POLL_SCHEDULE=30s run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.annotations."keelson.pro/poll-schedule"' "${MANIFESTS}/deployment.yaml")" = "@every 30s" ]
}

@test "auto-update: keelson states a non-default field-manager strategy" {
  ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson ENV_IMAGE_AUTO_UPDATE_FIELD_MANAGER_STRATEGY=claim run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.annotations."keelson.pro/field-manager-strategy"' "${MANIFESTS}/deployment.yaml")" = "claim" ]
}

@test "auto-update: keel polls with @every" {
  ENV_IMAGE_AUTO_UPDATE_PROVIDER=keel run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.annotations."keel.sh/pollSchedule"' "${MANIFESTS}/deployment.yaml")" = "@every 1m" ]
}

# =============================================================================
# RBAC
# =============================================================================

@test "rbac: ClusterRoleBinding name leads with the Environment token" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.name' "${MANIFESTS}/clusterrolebinding.yaml")" = '${Environment}.${ProjectName}' ]
}

@test "rbac: ClusterRoleBinding subject is the ServiceAccount in the Environment namespace" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.subjects[0].namespace' "${MANIFESTS}/clusterrolebinding.yaml")" = '${Environment}' ]
  [ "$(yq '.metadata.namespace' "${MANIFESTS}/serviceaccount.yaml")" = '${Environment}' ]
}

@test "rbac: parent delegation RoleBinding lives in and binds the Environment namespace" {
  ENV_CLUSTER_SCOPED_DELEGATION=parent run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(yq '.metadata.name' "${MANIFESTS}/rolebinding.yaml")" = '${ProjectName}' ]
  [ "$(yq '.metadata.namespace' "${MANIFESTS}/rolebinding.yaml")" = '${Environment}' ]
  [ "$(yq '.subjects[0].namespace' "${MANIFESTS}/rolebinding.yaml")" = '${Environment}' ]
}

# =============================================================================
# Not part of a product
# =============================================================================

@test "product: no product labels or ProductName token in deployment mode" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(grep -rlE 'part-of|kaptain.org/product|ProductName' "${MANIFESTS}" | wc -l | tr -d ' ')" -eq 0 ]
}

@test "product: no product labels or ProductName token in job mode" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(grep -rlE 'part-of|kaptain.org/product|ProductName' "${MANIFESTS}" | wc -l | tr -d ' ')" -eq 0 ]
}

# =============================================================================
# Job mode zero-scale Deployment
# =============================================================================

@test "job mode: zero-scale Deployment shares base name, ServiceAccount and Secret, sleeps" {
  ENV_DEPLOY_MODE=job ENV_IMAGE_AUTO_UPDATE_PROVIDER=keelson run "$SCRIPT"
  [ "$status" -eq 0 ]
  local d="${MANIFESTS}/deployment.yaml"
  local spec='.spec.template.spec'
  [ ! -f "${MANIFESTS}/deployment-debug.yaml" ]
  [ "$(yq '.metadata.name' "$d")" = "$(yq '.metadata.name' "${MANIFESTS}/cronjob.yaml")" ]
  [ "$(yq '.spec.replicas' "$d")" = "0" ]
  [ "$(yq "${spec}.containers[0].command | join(\" \")" "$d")" = "sleep infinity" ]
  [ "$(yq "${spec}.serviceAccountName" "$d")" = '${ProjectName}' ]
  [ "$(yq "${spec}.volumes[] | select(.name == \"secret\") | .secret.secretName" "$d")" = \
    "$(yq '.spec.jobTemplate.spec.template.spec.volumes[] | select(.name == "secret") | .secret.secretName' "${MANIFESTS}/cronjob.yaml")" ]
}

# =============================================================================
# Seed-and-compare marker
# =============================================================================

@test "marker: seed-and-compare marker sits in a namespace that must never exist" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local m="${MANIFESTS}/run-environment-seed-and-compare-marker.yaml"
  [ "$(yq '.metadata.namespace' "$m")" = "do-not-deploy-kaptain-seed-and-compare-marker-file-only" ]
  [ "$(yq '.data.imageDeployManifestsApplyMode' "$m")" = "seed-and-compare" ]
}

@test "marker: no marker for enforce-state-normally" {
  ENV_IMAGE_DEPLOY_MANIFESTS_APPLY_MODE=enforce-state-normally run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "${MANIFESTS}/run-environment-seed-and-compare-marker.yaml" ]
}

# =============================================================================
# Environment token guard
# =============================================================================

@test "guard: an Environment value in the deploy-image config fails" {
  mkdir -p src/environment/config
  printf '%s' 'prod' > src/environment/config/Environment
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "the Environment token is supplied by whatever applies this set"
}

@test "guard: an EnvironmentShortName value in the deploy-image defaults fails" {
  mkdir -p src/environment/defaults
  printf '%s' 'prod' > src/environment/defaults/EnvironmentShortName
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  assert_output_contains "the EnvironmentShortName token is supplied by whatever applies this set"
}
