#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for reference scripts and setup-local-context.bash
#
# Verifies:
# - Each reference script calls sub-scripts in the correct order
# - Required environment variables are present at each step
# - Build type variations set TARGET_BRANCH correctly
# - basic-quality-checks exports QC configuration variables

bats_require_minimum_version 1.5.0

load helpers

# Create a mock script that logs its name and checks required env vars
create_mock_script() {
  local path="$1"
  cat > "$path" << 'MOCK'
#!/usr/bin/env bash
echo "$(basename "$0")" >> "$CALL_LOG"
for var in CURRENT_BRANCH TARGET_BRANCH BUILD_MODE BUILD_PLATFORM RELEASE_BRANCH DEFAULT_BRANCH REPOSITORY_NAME REPOSITORY_OWNER; do
  eval "val=\${$var:-}"
  if [[ -z "$val" ]]; then
    echo "MISSING REQUIRED VAR: $var (in $(basename "$0"))" >&2
    exit 1
  fi
done
MOCK
  chmod +x "$path"
}

setup() {
  # Hermetic against the invoking shell: these tests run the REAL
  # setup-local-context/detect-build-context, which deliberately respects
  # incoming values - leaked exports (e.g. from local kaptain testing)
  # would change behaviour or, for KAPTAIN_LOCAL_RELEASE, suppress the
  # branch vars entirely and kill every reference script.
  unset KAPTAIN_LOCAL_RELEASE KAPTAIN_BRANCH_OVERRIDE \
        DEFAULT_BRANCH TARGET_BRANCH RELEASE_BRANCH UPSTREAM_BRANCH \
        TARGET_REF REMOTE_NAME 2>/dev/null || true
  # Provide CURRENT_BRANCH like any CI invoker: runners check out detached
  # HEAD, and the local guesser hard-errors on detached-without-vars by
  # design. The bats suite IS an invoker - it supplies the context var.
  export CURRENT_BRANCH="test-branch"

  MOCK_DIR=$(create_test_dir "ref-scripts")
  rm -rf "$MOCK_DIR" && mkdir -p "$MOCK_DIR"
  MOCK_SCRIPTS_DIR="${MOCK_DIR}/main"
  MOCK_GENERATORS_DIR="${MOCK_DIR}/generators"
  export CALL_LOG="${MOCK_DIR}/call.log"
  > "$CALL_LOG"

  # Isolate the output dir from the mocks and the repo
  export OUTPUT_SUB_PATH="${MOCK_DIR}/output"

  mkdir -p "$MOCK_SCRIPTS_DIR" "$MOCK_GENERATORS_DIR"

  # Create all main script mocks
  for script in \
    load-project-kaptainpm-docker-logins kaptain-init load-final-kaptainpm-yaml \
    validate-tooling hook-pre-build basic-quality-checks docker-registry-logins docker-platform-setup \
    hook-pre-tagging-tests versions-and-naming hook-post-versions-and-naming change-source-note-write \
    release-change-data-generate release-change-data-oci-package \
    docker-build-dockerfile docker-build-retag docker-multi-tag git-push-tag docker-push-all \
    hook-pre-docker-prepare hook-post-docker-tests hook-pre-package-prepare hook-post-package-tests \
    kubernetes-manifests-package-prepare kubernetes-manifests-substitute kubernetes-manifests-package \
    kubernetes-product-aggregate \
    kubernetes-templates-import \
    kubernetes-lineage-data-generate \
    kubernetes-manifests-contract-generate \
    kubernetes-manifests-package-only-token-override \
    kubernetes-manifests-repo-provider-package kubernetes-manifests-repo-provider-publish \
    vendor-helm-render-and-process vendor-helm-render-validate vendor-helm-inject-build-details \
    spec-package-prepare spec-validate \
    layer-package-prepare layer-validate \
    kubernetes-run-aggregate kubernetes-run-substitute kubernetes-run-finalise \
    kubernetes-run-consumption-report kubernetes-run-package kubernetes-run-deploy-image-validate \
    kubernetes-run-image-deploy-manifests-templates-import kubernetes-run-image-deploy-manifests \
    kubernetes-run-image-deploy-manifests-package-prepare kubernetes-run-image-deploy-manifests-substitute \
    kubernetes-run-image-deploy-manifests-contract-generate \
    kubernetes-run-image-deploy-manifests-lineage-data-generate \
    kubernetes-run-image-deploy-manifests-package kubernetes-run-image-deploy-manifests-repo-provider-package \
    hook-pre-publish hook-post-build; do
    create_mock_script "$MOCK_SCRIPTS_DIR/$script"
  done

  # Create all generator script mocks
  for script in \
    generate-kubernetes-configmap generate-kubernetes-secret-template \
    generate-kubernetes-serviceaccount generate-kubernetes-workload \
    generate-kubernetes-poddisruptionbudget generate-kubernetes-service; do
    create_mock_script "$MOCK_GENERATORS_DIR/$script"
  done

  # Export so child processes (reference scripts) use mocks
  export SCRIPTS_DIR="$MOCK_SCRIPTS_DIR"
  export GENERATORS_DIR="$MOCK_GENERATORS_DIR"

  # Hook steps only run when the project configures a script for them, so the
  # call-order tests below have to configure one. The mocks never read the
  # path. The skip path gets its own test.
  for hook in HOOK_PRE_BUILD HOOK_POST_BUILD HOOK_PRE_TAGGING_TESTS \
              HOOK_POST_VERSIONS_AND_NAMING HOOK_PRE_DOCKER_PREPARE \
              HOOK_POST_DOCKER_TESTS HOOK_PRE_PACKAGE_PREPARE \
              HOOK_POST_PACKAGE_TESTS HOOK_PRE_PUBLISH; do
    export "${hook}_SCRIPT_SUB_PATH=hooks/test-hook.bash"
  done

  REF_DIR="$PROJECT_ROOT/src/scripts/reference"
}

teardown() {
  dump_bats_result
  :
}

# Assert call log matches expected sequence exactly
assert_call_order() {
  local expected="$1"
  local actual
  actual=$(cat "$CALL_LOG" 2>/dev/null || echo "(empty)")

  if [[ "$actual" != "$expected" ]]; then
    echo "Call order mismatch!" >&3
    echo "--- Expected ---" >&3
    echo "$expected" >&3
    echo "--- Actual ---" >&3
    echo "$actual" >&3
    return 1
  fi
}


# =============================================================================
# Call Order Tests
# =============================================================================

@test "reference: basic-quality-checks calls scripts in correct order" {
  run bash "$REF_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
hook-post-build"
}

@test "reference: basic-quality-and-versioning calls scripts in correct order" {
  run bash "$REF_DIR/basic-quality-and-versioning"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
docker-multi-tag
hook-pre-publish
git-push-tag
docker-push-all
hook-post-build"
}

@test "reference: docker-build-dockerfile calls scripts in correct order" {
  run bash "$REF_DIR/docker-build-dockerfile"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
hook-pre-docker-prepare
docker-build-dockerfile
hook-post-docker-tests
docker-multi-tag
hook-pre-publish
git-push-tag
docker-push-all
hook-post-build"
}

@test "reference: docker-build-retag calls scripts in correct order" {
  run bash "$REF_DIR/docker-build-retag"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
docker-build-retag
hook-post-docker-tests
docker-multi-tag
hook-pre-publish
git-push-tag
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-app-docker-dockerfile calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-app-docker-dockerfile"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-templates-import
hook-pre-docker-prepare
docker-build-dockerfile
hook-post-docker-tests
generate-kubernetes-configmap
generate-kubernetes-secret-template
generate-kubernetes-serviceaccount
generate-kubernetes-workload
generate-kubernetes-poddisruptionbudget
generate-kubernetes-service
hook-pre-package-prepare
kubernetes-manifests-package-prepare
kubernetes-manifests-substitute
kubernetes-manifests-contract-generate
kubernetes-lineage-data-generate
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-app-docker-retag calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-app-docker-retag"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-templates-import
docker-build-retag
hook-post-docker-tests
generate-kubernetes-configmap
generate-kubernetes-secret-template
generate-kubernetes-serviceaccount
generate-kubernetes-workload
generate-kubernetes-poddisruptionbudget
generate-kubernetes-service
hook-pre-package-prepare
kubernetes-manifests-package-prepare
kubernetes-manifests-substitute
kubernetes-manifests-contract-generate
kubernetes-lineage-data-generate
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-app-manifests-only calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-app-manifests-only"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-templates-import
generate-kubernetes-configmap
generate-kubernetes-secret-template
generate-kubernetes-serviceaccount
generate-kubernetes-workload
generate-kubernetes-poddisruptionbudget
generate-kubernetes-service
hook-pre-package-prepare
kubernetes-manifests-package-prepare
kubernetes-manifests-package-only-token-override
kubernetes-manifests-substitute
kubernetes-manifests-contract-generate
kubernetes-lineage-data-generate
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: spec-check-filter-release calls scripts in correct order" {
  run bash "$REF_DIR/spec-check-filter-release"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
hook-pre-docker-prepare
spec-package-prepare
docker-build-dockerfile
spec-validate
hook-post-docker-tests
docker-multi-tag
hook-pre-publish
git-push-tag
docker-push-all
hook-post-build"
}

@test "reference: layer-and-layerset-build calls scripts in correct order" {
  run bash "$REF_DIR/layer-and-layerset-build"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
hook-pre-docker-prepare
layer-package-prepare
docker-build-dockerfile
layer-validate
hook-post-docker-tests
docker-multi-tag
hook-pre-publish
git-push-tag
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-bundle-resources calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-bundle-resources"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-templates-import
hook-pre-package-prepare
kubernetes-manifests-package-prepare
kubernetes-manifests-package-only-token-override
kubernetes-manifests-substitute
kubernetes-manifests-contract-generate
kubernetes-lineage-data-generate
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-product-aggregate calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-product-aggregate"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
hook-pre-package-prepare
kubernetes-product-aggregate
kubernetes-manifests-package-prepare
kubernetes-manifests-package-only-token-override
kubernetes-manifests-substitute
kubernetes-manifests-contract-generate
kubernetes-lineage-data-generate
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-bundle-docker-retag calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-bundle-docker-retag"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-templates-import
docker-build-retag
hook-post-docker-tests
hook-pre-package-prepare
kubernetes-manifests-package-prepare
kubernetes-manifests-substitute
kubernetes-manifests-contract-generate
kubernetes-lineage-data-generate
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-bundle-docker-dockerfile calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-bundle-docker-dockerfile"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-templates-import
hook-pre-docker-prepare
docker-build-dockerfile
hook-post-docker-tests
hook-pre-package-prepare
kubernetes-manifests-package-prepare
kubernetes-manifests-substitute
kubernetes-manifests-contract-generate
kubernetes-lineage-data-generate
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-bundle-vendor-helm-rendered calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-bundle-vendor-helm-rendered"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-templates-import
vendor-helm-render-and-process
hook-post-docker-tests
hook-pre-package-prepare
vendor-helm-render-validate
kubernetes-manifests-package-prepare
vendor-helm-inject-build-details
kubernetes-manifests-package-only-token-override
kubernetes-manifests-substitute
kubernetes-manifests-contract-generate
kubernetes-lineage-data-generate
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-run-environment calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-run-environment"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-run-image-deploy-manifests-templates-import
hook-pre-package-prepare
kubernetes-run-aggregate
kubernetes-run-substitute
kubernetes-run-finalise
kubernetes-run-consumption-report
kubernetes-lineage-data-generate
kubernetes-run-package
kubernetes-run-deploy-image-validate
kubernetes-run-image-deploy-manifests
kubernetes-run-image-deploy-manifests-package-prepare
kubernetes-run-image-deploy-manifests-substitute
kubernetes-run-image-deploy-manifests-contract-generate
kubernetes-run-image-deploy-manifests-lineage-data-generate
kubernetes-run-image-deploy-manifests-package
kubernetes-run-image-deploy-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

@test "reference: kubernetes-run-platform-meta-environment calls scripts in correct order" {
  run bash "$REF_DIR/kubernetes-run-platform-meta-environment"
  [ "$status" -eq 0 ]

  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
hook-pre-build
basic-quality-checks
docker-registry-logins
docker-platform-setup
hook-pre-tagging-tests
versions-and-naming
hook-post-versions-and-naming
change-source-note-write
release-change-data-generate
release-change-data-oci-package
kubernetes-run-image-deploy-manifests-templates-import
hook-pre-package-prepare
kubernetes-run-image-deploy-manifests
kubernetes-run-image-deploy-manifests-package-prepare
kubernetes-run-image-deploy-manifests-substitute
kubernetes-run-image-deploy-manifests-contract-generate
kubernetes-run-image-deploy-manifests-lineage-data-generate
kubernetes-run-image-deploy-manifests-package
kubernetes-run-image-deploy-manifests-repo-provider-package
kubernetes-run-aggregate
kubernetes-run-substitute
kubernetes-run-finalise
kubernetes-run-consumption-report
kubernetes-lineage-data-generate
kubernetes-run-package
kubernetes-run-deploy-image-validate
hook-post-package-tests
docker-multi-tag
hook-pre-publish
git-push-tag
kubernetes-manifests-repo-provider-publish
docker-push-all
hook-post-build"
}

# =============================================================================
# setup-local-context.bash Tests
# =============================================================================

@test "setup-local-context: all required variables are set" {
  run bash -c '
    export BUILD_PLATFORM_LOG_PROVIDER=stdout
    export OUTPUT_SUB_PATH='"${MOCK_DIR}"'/output
    source "'"$PROJECT_ROOT"'/src/scripts/lib/setup-local-context.bash"
    missing=""
    for var in CURRENT_BRANCH TARGET_BRANCH BUILD_MODE BUILD_PLATFORM \
               BUILD_PLATFORM_LOG_PROVIDER RELEASE_BRANCH DEFAULT_BRANCH \
               REPOSITORY_NAME REPOSITORY_OWNER; do
      eval "val=\${$var:-}"
      if [[ -z "$val" ]]; then
        missing="$missing $var"
      fi
    done
    if [[ -n "$missing" ]]; then
      echo "MISSING:$missing"
      exit 1
    fi
    echo "ALL_SET"
  '
  [ "$status" -eq 0 ]
  assert_output_contains "ALL_SET"
}

@test "setup-local-context: TARGET_BRANCH defaults to upstream branch" {
  run bash -c '
    export BUILD_PLATFORM_LOG_PROVIDER=stdout
    export OUTPUT_SUB_PATH='"${MOCK_DIR}"'/output
    source "'"$PROJECT_ROOT"'/src/scripts/lib/setup-local-context.bash"
    echo "TARGET_BRANCH=$TARGET_BRANCH"
  '
  [ "$status" -eq 0 ]
  assert_output_contains "TARGET_BRANCH=origin/"
}

@test "setup-local-context: TARGET_BRANCH defaults to upstream when not overridden" {
  run bash -c '
    export BUILD_PLATFORM_LOG_PROVIDER=stdout
    export OUTPUT_SUB_PATH='"${MOCK_DIR}"'/output
    source "'"$PROJECT_ROOT"'/src/scripts/lib/setup-local-context.bash"
    echo "TARGET_BRANCH=$TARGET_BRANCH"
  '
  [ "$status" -eq 0 ]
  assert_output_contains "TARGET_BRANCH=origin/"
}

@test "setup-local-context: TARGET_BRANCH can be overridden via environment" {
  run bash -c '
    export TARGET_BRANCH=custom/branch
    export BUILD_PLATFORM_LOG_PROVIDER=stdout
    export OUTPUT_SUB_PATH='"${MOCK_DIR}"'/output
    source "'"$PROJECT_ROOT"'/src/scripts/lib/setup-local-context.bash"
    echo "TARGET_BRANCH=$TARGET_BRANCH"
  '
  [ "$status" -eq 0 ]
  assert_output_contains "TARGET_BRANCH=custom/branch"
}


# =============================================================================
# QC Variable Export Test
# =============================================================================

@test "basic-quality-checks reference: QC variables are exported to sub-scripts" {
  # Replace the basic-quality-checks mock with one that checks QC vars
  cat > "$MOCK_SCRIPTS_DIR/basic-quality-checks" << 'MOCK'
#!/usr/bin/env bash
echo "$(basename "$0")" >> "$CALL_LOG"
for var in QC_BLOCK_SLASH_CONTAINING_BRANCHES QC_BLOCK_DOUBLE_HYPHEN_CONTAINING_BRANCHES \
           QC_REQUIRE_CONVENTIONAL_BRANCHES QC_REQUIRE_CONVENTIONAL_COMMITS \
           QC_BLOCK_CONVENTIONAL_COMMITS QC_BLOCK_DUPLICATE_COMMIT_MESSAGES; do
  eval "val=\${$var:-__UNSET__}"
  if [[ "$val" == "__UNSET__" ]]; then
    echo "MISSING QC VAR: $var" >&2
    exit 1
  fi
done
MOCK
  chmod +x "$MOCK_SCRIPTS_DIR/basic-quality-checks"

  run bash "$REF_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]
}

@test "reference: hook steps are skipped when no hook script is configured" {
  unset HOOK_PRE_BUILD_SCRIPT_SUB_PATH HOOK_POST_BUILD_SCRIPT_SUB_PATH \
        HOOK_PRE_TAGGING_TESTS_SCRIPT_SUB_PATH \
        HOOK_POST_VERSIONS_AND_NAMING_SCRIPT_SUB_PATH \
        HOOK_PRE_DOCKER_PREPARE_SCRIPT_SUB_PATH \
        HOOK_POST_DOCKER_TESTS_SCRIPT_SUB_PATH \
        HOOK_PRE_PACKAGE_PREPARE_SCRIPT_SUB_PATH \
        HOOK_POST_PACKAGE_TESTS_SCRIPT_SUB_PATH \
        HOOK_PRE_PUBLISH_SCRIPT_SUB_PATH

  run bash "$REF_DIR/basic-quality-checks"
  [ "$status" -eq 0 ]

  # Same order as the configured case, minus the two hook steps
  assert_call_order "validate-tooling
load-project-kaptainpm-docker-logins
docker-registry-logins
kaptain-init
load-final-kaptainpm-yaml
basic-quality-checks"
}

# load-final-kaptainpm-yaml may move the output dir (to a configured
# outputSubPath), so run_step keeps its output file in kaptainpm/ meanwhile.
write_mover_step() {
  mkdir -p "${MOCK_DIR}/movers"
  cat > "${MOCK_DIR}/movers/load-final-kaptainpm-yaml" << 'MOVER'
#!/usr/bin/env bash
set -euo pipefail
printf 'MOVED_VALUE=yes\n' >> "${REFERENCE_SCRIPT_OUTPUT}"
mkdir -p "${OUTPUT_SUB_PATH}"
mv "${OUTPUT_SUB_PATH}" "${MOVED_TO}"
printf 'OUTPUT_SUB_PATH=%s\n' "${MOVED_TO}" >> "${REFERENCE_SCRIPT_OUTPUT}"
MOVER
  cat > "${MOCK_DIR}/movers/validate-tooling" << 'WIPER'
#!/usr/bin/env bash
set -euo pipefail
rm -rf "${OUTPUT_SUB_PATH}"
printf 'WIPED_VALUE=yes\n' >> "${REFERENCE_SCRIPT_OUTPUT}"
WIPER
  cat > "${MOCK_DIR}/movers/failer" << 'FAILER'
#!/usr/bin/env bash
printf 'PARTIAL=yes\n' >> "${REFERENCE_SCRIPT_OUTPUT}"
exit 3
FAILER
  cat > "${MOCK_DIR}/movers/plain" << 'PLAIN'
#!/usr/bin/env bash
[[ "${REFERENCE_SCRIPT_OUTPUT}" == "${OUTPUT_SUB_PATH}/reference-script-output/plain" ]] || exit 9
printf 'PLAIN_VALUE=yes\n' >> "${REFERENCE_SCRIPT_OUTPUT}"
PLAIN
  chmod +x "${MOCK_DIR}/movers/"*
}

# A reference-style script running one step from the test dir, as the real
# ones run from the repo root
# Usage: write_mover_reference <step>
write_mover_reference() {
  cat > "${MOCK_DIR}/movers-reference" << REF
#!/usr/bin/env bash
set -euo pipefail
cd "${MOCK_DIR}"
source "${PROJECT_ROOT}/src/scripts/lib/setup-local-context.bash"
run_step ${1}
echo "OSP=\${OUTPUT_SUB_PATH} VALUE=\${MOVED_VALUE:-}\${PLAIN_VALUE:-}\${WIPED_VALUE:-}"
REF
  chmod +x "${MOCK_DIR}/movers-reference"
}

@test "setup-local-context: the loader step can move the output dir and keep its outputs" {
  write_mover_step
  write_mover_reference load-final-kaptainpm-yaml
  BUILD_PLATFORM_LOG_PROVIDER=stdout OUTPUT_SUB_PATH="${MOCK_DIR}/output" \
    MOVED_TO="${MOCK_DIR}/moved" SCRIPTS_DIR="${MOCK_DIR}/movers" \
    run "${MOCK_DIR}/movers-reference"
  [[ "$status" -eq 0 ]] || return 1
  assert_output_contains "OSP=${MOCK_DIR}/moved VALUE=yes"
  grep -qx 'MOVED_VALUE=yes' "${MOCK_DIR}/moved/reference-script-output/load-final-kaptainpm-yaml" || return 1
  [[ ! -e "${MOCK_DIR}/output" ]] || return 1
  [[ ! -e "${MOCK_DIR}/kaptainpm/reference-script-output" ]] || return 1
}

@test "setup-local-context: other steps write their outputs straight into the output dir" {
  write_mover_step
  write_mover_reference plain
  BUILD_PLATFORM_LOG_PROVIDER=stdout OUTPUT_SUB_PATH="${MOCK_DIR}/output" \
    SCRIPTS_DIR="${MOCK_DIR}/movers" \
    run "${MOCK_DIR}/movers-reference"
  [[ "$status" -eq 0 ]] || return 1
  assert_output_contains "VALUE=yes"
  grep -qx 'PLAIN_VALUE=yes' "${MOCK_DIR}/output/reference-script-output/plain" || return 1
}

@test "setup-local-context: a failing step stops the script and keeps its partial output" {
  write_mover_step
  write_mover_reference failer
  BUILD_PLATFORM_LOG_PROVIDER=stdout OUTPUT_SUB_PATH="${MOCK_DIR}/output" \
    SCRIPTS_DIR="${MOCK_DIR}/movers" \
    run "${MOCK_DIR}/movers-reference"
  [[ "$status" -eq 3 ]] || return 1
  [[ "$output" != *"OSP="* ]] || return 1
  grep -qx 'PARTIAL=yes' "${MOCK_DIR}/output/reference-script-output/failer" || return 1
}

@test "setup-local-context: the validate-tooling step can wipe the output dir and keep its outputs" {
  write_mover_step
  write_mover_reference validate-tooling
  mkdir -p "${MOCK_DIR}/output/earlier-run"
  BUILD_PLATFORM_LOG_PROVIDER=stdout OUTPUT_SUB_PATH="${MOCK_DIR}/output" \
    SCRIPTS_DIR="${MOCK_DIR}/movers" \
    run "${MOCK_DIR}/movers-reference"
  [[ "$status" -eq 0 ]] || return 1
  assert_output_contains "VALUE=yes"
  grep -qx 'WIPED_VALUE=yes' "${MOCK_DIR}/output/reference-script-output/validate-tooling" || return 1
  [[ ! -e "${MOCK_DIR}/output/earlier-run" ]] || return 1
  [[ ! -e "${MOCK_DIR}/kaptainpm/reference-script-output" ]] || return 1
}

@test "setup-local-context: sourcing it leaves the output dir alone" {
  mkdir -p "${MOCK_DIR}/output"
  printf 'keep' > "${MOCK_DIR}/output/sentinel"
  run bash -c '
    export BUILD_PLATFORM_LOG_PROVIDER=stdout
    export OUTPUT_SUB_PATH='"${MOCK_DIR}"'/output
    source "'"$PROJECT_ROOT"'/src/scripts/lib/setup-local-context.bash"
  '
  [[ "$status" -eq 0 ]] || return 1
  [[ -f "${MOCK_DIR}/output/sentinel" ]] || return 1
}
