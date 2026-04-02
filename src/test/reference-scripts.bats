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
  MOCK_DIR=$(create_test_dir "ref-scripts")
  rm -rf "$MOCK_DIR" && mkdir -p "$MOCK_DIR"
  MOCK_SCRIPTS_DIR="${MOCK_DIR}/main"
  MOCK_GENERATORS_DIR="${MOCK_DIR}/generators"
  export CALL_LOG="${MOCK_DIR}/call.log"
  > "$CALL_LOG"

  # Isolate output dir so setup-local-context's rm -rf doesn't delete mocks
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
    kubernetes-manifests-package-prepare kubernetes-manifests-package \
    kubernetes-manifests-package-only-token-override \
    kubernetes-manifests-repo-provider-package kubernetes-manifests-repo-provider-publish \
    spec-package-prepare spec-validate \
    aws-eks-cluster-management-prepare aws-eks-cluster-management-pre-build-validate \
    aws-eks-cluster-management-post-build-validate \
    layer-package-prepare layer-validate \
    hook-post-build; do
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

  REF_DIR="$PROJECT_ROOT/src/scripts/reference"
}

teardown() {
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
docker-multi-tag
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
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
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
docker-build-retag
generate-kubernetes-configmap
generate-kubernetes-secret-template
generate-kubernetes-serviceaccount
generate-kubernetes-workload
generate-kubernetes-poddisruptionbudget
generate-kubernetes-service
hook-pre-package-prepare
kubernetes-manifests-package-prepare
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
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
generate-kubernetes-configmap
generate-kubernetes-secret-template
generate-kubernetes-serviceaccount
generate-kubernetes-workload
generate-kubernetes-poddisruptionbudget
generate-kubernetes-service
hook-pre-package-prepare
kubernetes-manifests-package-only-token-override
kubernetes-manifests-package-prepare
kubernetes-manifests-package
kubernetes-manifests-repo-provider-package
hook-post-package-tests
docker-multi-tag
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
git-push-tag
docker-push-all
hook-post-build"
}

@test "reference: aws-eks-cluster-management calls scripts in correct order" {
  run bash "$REF_DIR/aws-eks-cluster-management"
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
aws-eks-cluster-management-prepare
hook-pre-docker-prepare
aws-eks-cluster-management-pre-build-validate
docker-build-dockerfile
aws-eks-cluster-management-post-build-validate
hook-post-docker-tests
docker-multi-tag
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
git-push-tag
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
