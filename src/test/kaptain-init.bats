#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/kaptain-init
# Covers: no-layers passthrough, layer resolution, layerset expansion,
# merge order, cycle detection, duplicate detection, cache skip, schema validation

load helpers

SCRIPT="$SCRIPTS_DIR/kaptain-init"

setup() {
  TEST_DIR=$(create_test_dir "kaptain-init")
  REPO_DIR="${TEST_DIR}/repo"
  mkdir -p "${REPO_DIR}"
  cd "${REPO_DIR}"

  export BUILD_MODE="build_server"
  export IMAGE_BUILD_COMMAND="docker"
  export DOCKER_TARGET_REGISTRY="ghcr.io"
  export DOCKER_TARGET_NAMESPACE="kube-kaptain"

  # Mock docker for artifact-fetch (file-level extraction via docker cp)
  mkdir -p "${MOCK_BIN_DIR}"
  export MOCK_DOCKER_CALLS="${TEST_DIR}/docker-calls.log"

  # The mock docker (and mock extract-oci-image) read layer contents from
  # MOCK_LAYER_DIR/<image-path>/... Tests populate this before running.
  export MOCK_LAYER_DIR="${TEST_DIR}/mock-layers"
  mkdir -p "${MOCK_LAYER_DIR}"

  cat > "${MOCK_BIN_DIR}/docker" << 'MOCK'
#!/usr/bin/env bash
echo "$*" >> "${MOCK_DOCKER_CALLS:-/dev/null}"
case "$1" in
  pull) exit 0 ;;
  create)
    # Store the image ref so cp can find the right mock data
    echo "${2}" > "${MOCK_DOCKER_CALLS}.last-create"
    echo "mock-container-id"
    ;;
  cp)
    src_path="${2#*:}"
    dest="${3}"
    mkdir -p "${dest}"
    # Read back which image was created and find corresponding mock layer
    image_ref=$(cat "${MOCK_DOCKER_CALLS}.last-create" 2>/dev/null || echo "unknown")
    # Strip tag for directory lookup
    image_no_tag="${image_ref%:*}"
    mock_src="${MOCK_LAYER_DIR}/${image_no_tag}${src_path}"
    if [[ -f "${mock_src}" ]]; then
      cp "${mock_src}" "${dest}/"
    else
      exit 1
    fi
    ;;
  rm) exit 0 ;;
  *) exit 0 ;;
esac
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  # Mock check-jsonschema to always pass (schema files are placeholders)
  cat > "${MOCK_BIN_DIR}/check-jsonschema" << 'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
  chmod +x "${MOCK_BIN_DIR}/check-jsonschema"

  # Ensure yq is available (it should be, but guard)
  if ! command -v yq &>/dev/null; then
    skip "yq not available"
  fi

  build_kaptain_init_shim
}

# Build a focused shim scripts tree so we can inject a mock extract-oci-image
# without copying or mutating the real source tree. Everything kaptain-init
# touches via ${SCRIPT_DIR}/.. is symlinked from the real tree except the
# util/ directory, which is a real dir containing symlinks for the two other
# utils kaptain-init calls (artifact-resolve, artifact-fetch) and a plain
# mock file for extract-oci-image.
build_kaptain_init_shim() {
  local shim_root="${TEST_DIR}/shim"
  local real_scripts="${PROJECT_ROOT}/src/scripts"
  rm -rf "${shim_root}"
  # main/ and util/ are real dirs so kaptain-init's SCRIPT_DIR (and the
  # UTIL_DIR it derives) stay inside the shim. The scripts themselves are
  # symlinked from the real tree - file-level symlinks don't affect bash
  # path resolution, only directory-level ones do.
  mkdir -p "${shim_root}/scripts/main" "${shim_root}/scripts/util"

  ln -s "${real_scripts}/main/kaptain-init" "${shim_root}/scripts/main/kaptain-init"
  ln -s "${real_scripts}/defaults" "${shim_root}/scripts/defaults"
  ln -s "${real_scripts}/lib"      "${shim_root}/scripts/lib"
  ln -s "${real_scripts}/plugins"  "${shim_root}/scripts/plugins"
  ln -s "${PROJECT_ROOT}/src/schemas" "${shim_root}/schemas"

  ln -s "${real_scripts}/util/artifact-resolve" "${shim_root}/scripts/util/artifact-resolve"
  ln -s "${real_scripts}/util/artifact-fetch"   "${shim_root}/scripts/util/artifact-fetch"

  cat > "${shim_root}/scripts/util/extract-oci-image" << 'MOCK'
#!/usr/bin/env bash
# Mock extract-oci-image for kaptain-init.bats. Reads MOCK_LAYER_DIR/<image>
# and copies its contents into the output dir. Supports full-tree extract
# (no path args) and selective extract (one or more in-image paths).
image_ref="${1}"
output_dir="${2}"
shift 2
image_no_tag="${image_ref%:*}"
src="${MOCK_LAYER_DIR}/${image_no_tag}"
mkdir -p "${output_dir}"
if [[ $# -eq 0 ]]; then
  if [[ -d "${src}" ]]; then
    cp -R "${src}/." "${output_dir}/"
  fi
else
  for p in "$@"; do
    parent_dir="$(dirname "${p}")"
    case "${parent_dir}" in
      "/" | ".") dest_dir="${output_dir%/}" ;;
      *)         dest_dir="${output_dir%/}/${parent_dir#/}" ;;
    esac
    mkdir -p "${dest_dir}"
    if [[ -f "${src}${p}" ]]; then
      cp "${src}${p}" "${dest_dir}/"
    else
      exit 1
    fi
  done
fi
MOCK
  chmod +x "${shim_root}/scripts/util/extract-oci-image"

  SCRIPT="${shim_root}/scripts/main/kaptain-init"
}

teardown() {
  :
}

# Helper: create a mock layer image's KaptainPM.yaml
# Usage: create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" <<< "yaml content"
create_mock_layer() {
  local image_path="${1}"
  local layer_dir="${MOCK_LAYER_DIR}/${image_path}"
  mkdir -p "${layer_dir}"
  cat > "${layer_dir}/KaptainPM.yaml"
}

# Helper: add an arbitrary file to a mock layer at an image-absolute path.
# Usage: add_mock_layer_file <image-path> <image-abs-path> <<< "content"
add_mock_layer_file() {
  local image_path="${1}"
  local file_path="${2}"
  local full="${MOCK_LAYER_DIR}/${image_path}${file_path}"
  mkdir -p "$(dirname "${full}")"
  cat > "${full}"
}

# =============================================================================
# No layers - passthrough
# =============================================================================

@test "no layers: copies project root to final unchanged" {
  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml" ]]
  run yq eval '.kind' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "KubeAppDockerDockerfile" ]]
  run yq eval '.spec.main.quality.branches.blockSlashes' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "true" ]]
}

@test "no layers: logs zero layers declared" {
  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Layers declared: 0"* ]]
}

# =============================================================================
# Missing KaptainPM.yaml
# =============================================================================

@test "fails when KaptainPM.yaml not found" {
  run "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"KaptainPM.yaml not found"* ]]
}

# =============================================================================
# Invalid YAML
# =============================================================================

@test "fails on invalid YAML syntax" {
  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
  broken: [indentation
EOF
  run "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Invalid YAML"* ]]
}

# =============================================================================
# Single config layer
# =============================================================================

@test "single layer: merges layer then project on top" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
        blockDoubleHyphens: true
      commits:
        requireConventional: true
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
  main:
    docker:
      dockerfile:
        subPath: src/docker
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml" ]]

  # Layer values present
  run yq eval '.spec.main.quality.branches.blockSlashes' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "true" ]]
  run yq eval '.spec.main.quality.commits.requireConventional' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "true" ]]

  # Project overrides present
  run yq eval '.kind' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "KubeAppDockerDockerfile" ]]
  run yq eval '.spec.main.docker.dockerfile.subPath' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "src/docker" ]]
}

@test "single layer: spec.layers removed from final output" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  run yq eval '.spec.layers' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "null" ]]
}

# =============================================================================
# Multiple config layers - merge order
# =============================================================================

@test "two layers: second layer overrides first" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    generators:
      workload:
        replicas: '1'
    quality:
      branches:
        blockSlashes: true
EOF

  create_mock_layer "ghcr.io/kube-kaptain/ha/ha-deployment" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    generators:
      workload:
        replicas: '3'
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
    - ha-deployment:2.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  # Second layer's replicas wins
  run yq eval '.spec.main.generators.workload.replicas' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "3" ]]

  # First layer's non-conflicting field preserved
  run yq eval '.spec.main.quality.branches.blockSlashes' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "true" ]]
}

@test "project root overrides all layers" {
  create_mock_layer "ghcr.io/kube-kaptain/ha/ha-deployment" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    generators:
      workload:
        replicas: '3'
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - ha-deployment:2.0
  main:
    generators:
      workload:
        replicas: '5'
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  # Project root wins
  run yq eval '.spec.main.generators.workload.replicas' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "5" ]]
}

# =============================================================================
# Layer-payload stripping
# =============================================================================

@test "layer-payload stripped before merge" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
layer-payload:
  - source: /scripts/build.bash
    destination: .kaptain/scripts/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  add_mock_layer_file "ghcr.io/kube-kaptain/quality/quality-strict" /scripts/build.bash <<< '#!/bin/sh
echo build'

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  # layer-payload should not appear in final
  run yq eval '.["layer-payload"]' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "null" ]]

  # Config values still there
  run yq eval '.spec.main.quality.branches.blockSlashes' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "true" ]]

  # Payload file actually landed at destination
  [[ -f "${REPO_DIR}/.kaptain/scripts/build.bash" ]]
}

@test "layer-payload: fails when source not in extracted layer" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
layer-payload:
  - source: /scripts/missing.bash
    destination: .kaptain/scripts/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"source not found in context listing"* ]]
  [[ "$output" == *"/scripts/missing.bash"* ]]
}

@test "layer-payload: fails when destination contains '..'" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
layer-payload:
  - source: /scripts/build.bash
    destination: ../escape/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  add_mock_layer_file "ghcr.io/kube-kaptain/quality/quality-strict" /scripts/build.bash <<< 'x'

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"parent-traversal"* ]]
}

@test "layer-payload: fails when destination is absolute" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
layer-payload:
  - source: /scripts/build.bash
    destination: /etc/evil/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  add_mock_layer_file "ghcr.io/kube-kaptain/quality/quality-strict" /scripts/build.bash <<< 'x'

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"must be relative"* ]]
}

@test "layer-payload: multiple files into same destination dir succeed" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
layer-payload:
  - source: /scripts/build.bash
    destination: .kaptain/scripts/
  - source: /scripts/other.bash
    destination: .kaptain/scripts/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  add_mock_layer_file "ghcr.io/kube-kaptain/quality/quality-strict" /scripts/build.bash <<< 'x'
  add_mock_layer_file "ghcr.io/kube-kaptain/quality/quality-strict" /scripts/other.bash <<< 'y'

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"payload ok: /scripts/build.bash -> .kaptain/scripts/"* ]]
  [[ "$output" == *"payload ok: /scripts/other.bash -> .kaptain/scripts/"* ]]
}

@test "layer-payload: multiple entries all land at their destinations" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
layer-payload:
  - source: /scripts/build.bash
    destination: .kaptain/scripts/
  - source: /config/settings.yaml
    destination: .kaptain/config/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  add_mock_layer_file "ghcr.io/kube-kaptain/quality/quality-strict" /scripts/build.bash <<< '#!/bin/sh'
  add_mock_layer_file "ghcr.io/kube-kaptain/quality/quality-strict" /config/settings.yaml <<< 'key: value'

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "${REPO_DIR}/.kaptain/scripts/build.bash" ]]
  [[ -f "${REPO_DIR}/.kaptain/config/settings.yaml" ]]
}

@test "layer-payload: tar.gz unpack extracts archive into destination" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
layer-payload:
  - source: /bundles/tools.tar.gz
    destination: .kaptain/tools/
    unpack: tar.gz
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  # Build a real tar.gz containing two files and stash it at the layer path
  local stage="${TEST_DIR}/tarball-stage"
  mkdir -p "${stage}/bundle"
  echo one > "${stage}/bundle/one.txt"
  echo two > "${stage}/bundle/two.txt"
  mkdir -p "${MOCK_LAYER_DIR}/ghcr.io/kube-kaptain/quality/quality-strict/bundles"
  ( cd "${stage}/bundle" && tar -czf "${MOCK_LAYER_DIR}/ghcr.io/kube-kaptain/quality/quality-strict/bundles/tools.tar.gz" . )

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "${REPO_DIR}/.kaptain/tools/one.txt" ]]
  [[ -f "${REPO_DIR}/.kaptain/tools/two.txt" ]]
}

# =============================================================================
# Layerset (composite layer) expansion
# =============================================================================

@test "layerset: expands sub-layers in order" {
  # quality-strict is a config layer
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  # docker-java is a config layer
  create_mock_layer "ghcr.io/kube-kaptain/docker/docker-java" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    docker:
      dockerfile:
        squash: squash
EOF

  # java-web-service is a layerset referencing the above two
  create_mock_layer "ghcr.io/kube-kaptain/java/java-web-service" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
    - docker-java:1.0
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  layers:
    - java-web-service:2.1
  main:
    generators:
      workload:
        replicas: '2'
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  # Layerset's kind
  run yq eval '.kind' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "KubeAppDockerDockerfile" ]]

  # Sub-layer values merged
  run yq eval '.spec.main.quality.branches.blockSlashes' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "true" ]]
  run yq eval '.spec.main.docker.dockerfile.squash' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "squash" ]]

  # Project root value
  run yq eval '.spec.main.generators.workload.replicas' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "2" ]]
}

# =============================================================================
# Duplicate detection
# =============================================================================

@test "fails on duplicate layer reference" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Duplicate"* ]]
}

@test "fails on same layer different versions" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
    - quality-strict:2.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Duplicate"* ]]
}

# =============================================================================
# Interpolation recording
# =============================================================================

@test "interpolation steps recorded for single layer" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  # Should have layer step, merged-layers step, and project-applied step
  local interp_dir="${REPO_DIR}/kaptainpm/interpolation"
  [[ -d "${interp_dir}" ]]
  local file_count
  file_count=$(ls -1 "${interp_dir}"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
  [[ "${file_count}" -ge 2 ]]
}

@test "interpolation dir contains project-applied as final step" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  # project-applied should be in the interpolation steps (not necessarily last)
  ls -1 "${REPO_DIR}/kaptainpm/interpolation"/*.yaml | grep -q "project-applied"
  # Last interpolation step should be metadata-stripped
  local last_file
  last_file=$(ls -1 "${REPO_DIR}/kaptainpm/interpolation"/*.yaml | sort | tail -1)
  [[ "$(basename "${last_file}")" == *"metadata-stripped"* ]]
}

# =============================================================================
# Original layer preservation
# =============================================================================

@test "original layer KaptainPM.yaml preserved in layers dir" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
layer-payload:
  - source: /scripts/build.bash
    destination: .kaptain/scripts/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  # The layer-payload source must exist in the mock layer so the consumption-
  # time validate_layer_payload call doesn't fail. The actual content is
  # irrelevant to this test - what matters is the preserved manifest below.
  add_mock_layer_file "ghcr.io/kube-kaptain/quality/quality-strict" "/scripts/build.bash" <<< "dummy"

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  # Original file with layer-payload intact
  local preserved="${REPO_DIR}/kaptainpm/layers/ghcr.io/kube-kaptain/quality/quality-strict/KaptainPM.yaml"
  [[ -f "${preserved}" ]]
  run yq eval '.["layer-payload"] | length' "${preserved}"
  [[ "$output" == "1" ]]
}

# =============================================================================
# Local build cache
# =============================================================================

@test "local build: processes when project root is newer than final" {
  export BUILD_MODE="local"
  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  mkdir -p "${REPO_DIR}/kaptainpm/final"
  # Create final file in the past
  cp "${REPO_DIR}/KaptainPM.yaml" "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  touch -t 202501010000 "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"

  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"skipping re-resolution"* ]]
}

@test "build_server: always processes even when final is newer" {
  export BUILD_MODE="build_server"
  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  mkdir -p "${REPO_DIR}/kaptainpm/final"
  cp "${REPO_DIR}/KaptainPM.yaml" "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  touch "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"

  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"skipping re-resolution"* ]]
}

# =============================================================================
# Layer missing KaptainPM.yaml
# =============================================================================

@test "fails when layer image has no KaptainPM.yaml" {
  # Create empty mock layer dir (no KaptainPM.yaml)
  mkdir -p "${MOCK_LAYER_DIR}/ghcr.io/kube-kaptain/quality/quality-strict"

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Failed to extract /KaptainPM.yaml"* ]]
}

# =============================================================================
# user-data merge
# =============================================================================

@test "user-data from layer merged with project" {
  create_mock_layer "ghcr.io/kube-kaptain/quality/quality-strict" << 'EOF'
apiVersion: kaptain.org/1.2
user-data:
  code-analysis:
    rules: standard
    fail-on-warning: false
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
user-data:
  code-analysis:
    fail-on-warning: true
spec:
  layers:
    - quality-strict:1.0
EOF
  run "$SCRIPT"
  [[ "$status" -eq 0 ]]

  # Layer default preserved
  run yq eval '.["user-data"]["code-analysis"].rules' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "standard" ]]

  # Project override wins
  run yq eval '.["user-data"]["code-analysis"]["fail-on-warning"]' "${REPO_DIR}/kaptainpm/final/KaptainPM.yaml"
  [[ "$output" == "true" ]]
}

# =============================================================================
# Clean previous output
# =============================================================================

@test "cleans previous interpolation dir on re-run" {
  cat > "${REPO_DIR}/KaptainPM.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF

  # Create stale interpolation file
  mkdir -p "${REPO_DIR}/kaptainpm/interpolation"
  echo "stale" > "${REPO_DIR}/kaptainpm/interpolation/99-stale.yaml"

  run "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ ! -f "${REPO_DIR}/kaptainpm/interpolation/99-stale.yaml" ]]
}
