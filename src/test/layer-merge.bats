#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/layer-merge.bash
# Covers strip payload, deep merge, record step, and validate type

load helpers

setup() {
  TEST_DIR=$(create_test_dir "layer-merge")
  source "$LIB_DIR/layer-merge.bash"
}

teardown() {
  :
}

# =============================================================================
# layer_strip_payload
# =============================================================================

@test "strip_payload: removes layer-payload key" {
  cat > "${TEST_DIR}/input.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
layer-payload:
  - source: /scripts/build.bash
    destination: .kaptain/scripts/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  layer_strip_payload "${TEST_DIR}/input.yaml" "${TEST_DIR}/output.yaml"
  # layer-payload should be gone
  run yq eval '.["layer-payload"]' "${TEST_DIR}/output.yaml"
  [[ "$output" == "null" ]]
}

@test "strip_payload: preserves all other fields" {
  cat > "${TEST_DIR}/input.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
layer-payload:
  - source: /scripts/build.bash
    destination: .kaptain/scripts/
spec:
  main:
    quality:
      branches:
        blockSlashes: true
user-data:
  custom: value
EOF
  layer_strip_payload "${TEST_DIR}/input.yaml" "${TEST_DIR}/output.yaml"
  run yq eval '.apiVersion' "${TEST_DIR}/output.yaml"
  [[ "$output" == "kaptain.org/1.2" ]]
  run yq eval '.kind' "${TEST_DIR}/output.yaml"
  [[ "$output" == "KubeAppDockerDockerfile" ]]
  run yq eval '.spec.main.quality.branches.blockSlashes' "${TEST_DIR}/output.yaml"
  [[ "$output" == "true" ]]
  run yq eval '.["user-data"].custom' "${TEST_DIR}/output.yaml"
  [[ "$output" == "value" ]]
}

@test "strip_payload: no-op when layer-payload absent" {
  cat > "${TEST_DIR}/input.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  layer_strip_payload "${TEST_DIR}/input.yaml" "${TEST_DIR}/output.yaml"
  run yq eval '.spec.main.quality.branches.blockSlashes' "${TEST_DIR}/output.yaml"
  [[ "$output" == "true" ]]
}

# =============================================================================
# layer_deep_merge - scalars
# =============================================================================

@test "deep_merge: overlay scalar replaces base scalar" {
  cat > "${TEST_DIR}/base.yaml" << 'EOF'
kind: BaseKind
spec:
  main:
    quality:
      branches:
        blockSlashes: false
EOF
  cat > "${TEST_DIR}/overlay.yaml" << 'EOF'
kind: OverlayKind
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  layer_deep_merge "${TEST_DIR}/base.yaml" "${TEST_DIR}/overlay.yaml" "${TEST_DIR}/output.yaml"
  run yq eval '.kind' "${TEST_DIR}/output.yaml"
  [[ "$output" == "OverlayKind" ]]
  run yq eval '.spec.main.quality.branches.blockSlashes' "${TEST_DIR}/output.yaml"
  [[ "$output" == "true" ]]
}

# =============================================================================
# layer_deep_merge - maps
# =============================================================================

@test "deep_merge: maps are recursively merged" {
  cat > "${TEST_DIR}/base.yaml" << 'EOF'
spec:
  main:
    quality:
      branches:
        blockSlashes: true
    docker:
      dockerfile:
        squash: squash
EOF
  cat > "${TEST_DIR}/overlay.yaml" << 'EOF'
spec:
  main:
    quality:
      commits:
        requireConventional: true
    docker:
      dockerfile:
        noCache: true
EOF
  layer_deep_merge "${TEST_DIR}/base.yaml" "${TEST_DIR}/overlay.yaml" "${TEST_DIR}/output.yaml"
  # Base fields preserved
  run yq eval '.spec.main.quality.branches.blockSlashes' "${TEST_DIR}/output.yaml"
  [[ "$output" == "true" ]]
  run yq eval '.spec.main.docker.dockerfile.squash' "${TEST_DIR}/output.yaml"
  [[ "$output" == "squash" ]]
  # Overlay fields added
  run yq eval '.spec.main.quality.commits.requireConventional' "${TEST_DIR}/output.yaml"
  [[ "$output" == "true" ]]
  run yq eval '.spec.main.docker.dockerfile.noCache' "${TEST_DIR}/output.yaml"
  [[ "$output" == "true" ]]
}

@test "deep_merge: overlay adds new top-level keys" {
  cat > "${TEST_DIR}/base.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  cat > "${TEST_DIR}/overlay.yaml" << 'EOF'
kind: KubeAppDockerDockerfile
user-data:
  custom: value
EOF
  layer_deep_merge "${TEST_DIR}/base.yaml" "${TEST_DIR}/overlay.yaml" "${TEST_DIR}/output.yaml"
  run yq eval '.apiVersion' "${TEST_DIR}/output.yaml"
  [[ "$output" == "kaptain.org/1.2" ]]
  run yq eval '.kind' "${TEST_DIR}/output.yaml"
  [[ "$output" == "KubeAppDockerDockerfile" ]]
  run yq eval '.["user-data"].custom' "${TEST_DIR}/output.yaml"
  [[ "$output" == "value" ]]
}

# =============================================================================
# layer_deep_merge - lists
# =============================================================================

@test "deep_merge: overlay list replaces base list entirely" {
  cat > "${TEST_DIR}/base.yaml" << 'EOF'
spec:
  layers:
    - quality-strict:1.0
    - docker-java:1.0
EOF
  cat > "${TEST_DIR}/overlay.yaml" << 'EOF'
spec:
  layers:
    - ha-deployment:2.0
EOF
  layer_deep_merge "${TEST_DIR}/base.yaml" "${TEST_DIR}/overlay.yaml" "${TEST_DIR}/output.yaml"
  run yq eval '.spec.layers | length' "${TEST_DIR}/output.yaml"
  [[ "$output" == "1" ]]
  run yq eval '.spec.layers[0]' "${TEST_DIR}/output.yaml"
  [[ "$output" == "ha-deployment:2.0" ]]
}

# =============================================================================
# layer_deep_merge - three-way merge (chained)
# =============================================================================

@test "deep_merge: three-way merge preserves all non-conflicting fields" {
  cat > "${TEST_DIR}/layer1.yaml" << 'EOF'
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  cat > "${TEST_DIR}/layer2.yaml" << 'EOF'
spec:
  main:
    quality:
      commits:
        requireConventional: true
EOF
  cat > "${TEST_DIR}/project.yaml" << 'EOF'
kind: KubeAppDockerDockerfile
spec:
  main:
    docker:
      dockerfile:
        subPath: src/docker
EOF
  layer_deep_merge "${TEST_DIR}/layer1.yaml" "${TEST_DIR}/layer2.yaml" "${TEST_DIR}/merged12.yaml"
  layer_deep_merge "${TEST_DIR}/merged12.yaml" "${TEST_DIR}/project.yaml" "${TEST_DIR}/final.yaml"
  run yq eval '.spec.main.quality.branches.blockSlashes' "${TEST_DIR}/final.yaml"
  [[ "$output" == "true" ]]
  run yq eval '.spec.main.quality.commits.requireConventional' "${TEST_DIR}/final.yaml"
  [[ "$output" == "true" ]]
  run yq eval '.spec.main.docker.dockerfile.subPath' "${TEST_DIR}/final.yaml"
  [[ "$output" == "src/docker" ]]
  run yq eval '.kind' "${TEST_DIR}/final.yaml"
  [[ "$output" == "KubeAppDockerDockerfile" ]]
}

@test "deep_merge: later layer overrides earlier layer scalar" {
  cat > "${TEST_DIR}/layer1.yaml" << 'EOF'
spec:
  main:
    generators:
      workload:
        replicas: '1'
EOF
  cat > "${TEST_DIR}/layer2.yaml" << 'EOF'
spec:
  main:
    generators:
      workload:
        replicas: '3'
EOF
  layer_deep_merge "${TEST_DIR}/layer1.yaml" "${TEST_DIR}/layer2.yaml" "${TEST_DIR}/output.yaml"
  run yq eval '.spec.main.generators.workload.replicas' "${TEST_DIR}/output.yaml"
  [[ "$output" == "3" ]]
}

# =============================================================================
# layer_record_step
# =============================================================================

@test "record_step: creates numbered file in interpolation dir" {
  local interp_dir="${TEST_DIR}/interpolation"
  cat > "${TEST_DIR}/source.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
EOF
  layer_record_step 0 "layer-quality-strict-1.0" "${TEST_DIR}/source.yaml" "${interp_dir}"
  [[ -f "${interp_dir}/00-layer-quality-strict-1.0.yaml" ]]
}

@test "record_step: zero-pads single digit step numbers" {
  local interp_dir="${TEST_DIR}/interpolation"
  cat > "${TEST_DIR}/source.yaml" << 'EOF'
test: data
EOF
  layer_record_step 3 "something" "${TEST_DIR}/source.yaml" "${interp_dir}"
  [[ -f "${interp_dir}/03-something.yaml" ]]
}

@test "record_step: handles double digit step numbers" {
  local interp_dir="${TEST_DIR}/interpolation"
  cat > "${TEST_DIR}/source.yaml" << 'EOF'
test: data
EOF
  layer_record_step 12 "step-twelve" "${TEST_DIR}/source.yaml" "${interp_dir}"
  [[ -f "${interp_dir}/12-step-twelve.yaml" ]]
}

@test "record_step: file content matches source" {
  local interp_dir="${TEST_DIR}/interpolation"
  cat > "${TEST_DIR}/source.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  layer_record_step 0 "test" "${TEST_DIR}/source.yaml" "${interp_dir}"
  run diff "${TEST_DIR}/source.yaml" "${interp_dir}/00-test.yaml"
  [[ "$status" -eq 0 ]]
}

@test "record_step: creates interpolation directory if missing" {
  local interp_dir="${TEST_DIR}/does/not/exist"
  cat > "${TEST_DIR}/source.yaml" << 'EOF'
test: data
EOF
  layer_record_step 0 "test" "${TEST_DIR}/source.yaml" "${interp_dir}"
  [[ -d "${interp_dir}" ]]
  [[ -f "${interp_dir}/00-test.yaml" ]]
}

# =============================================================================
# layer_validate_type - config layers
# =============================================================================

@test "validate_type: config layer with spec content is valid" {
  cat > "${TEST_DIR}/layer.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  main:
    quality:
      branches:
        blockSlashes: true
    docker:
      dockerfile:
        squash: squash
EOF
  layer_validate_type "${TEST_DIR}/layer.yaml"
}

@test "validate_type: config layer with no spec is valid" {
  cat > "${TEST_DIR}/layer.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
EOF
  layer_validate_type "${TEST_DIR}/layer.yaml"
}

# =============================================================================
# layer_validate_type - layersets (composite layers)
# =============================================================================

@test "validate_type: layerset with only spec.layers is valid" {
  cat > "${TEST_DIR}/layer.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
    - docker-java:1.0
EOF
  layer_validate_type "${TEST_DIR}/layer.yaml"
}

@test "validate_type: layerset with spec.layers and kind is valid" {
  cat > "${TEST_DIR}/layer.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
kind: KubeAppDockerDockerfile
spec:
  layers:
    - quality-strict:1.0
EOF
  layer_validate_type "${TEST_DIR}/layer.yaml"
}

# =============================================================================
# layer_validate_type - invalid combinations
# =============================================================================

@test "validate_type: spec.layers with other spec content is invalid" {
  cat > "${TEST_DIR}/layer.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  layers:
    - quality-strict:1.0
  main:
    quality:
      branches:
        blockSlashes: true
EOF
  run layer_validate_type "${TEST_DIR}/layer.yaml"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"main"* ]]
}

@test "validate_type: spec.layers with multiple other spec keys is invalid" {
  cat > "${TEST_DIR}/layer.yaml" << 'EOF'
apiVersion: kaptain.org/1.2
spec:
  layers:
    - quality-strict:1.0
  main:
    quality:
      branches:
        blockSlashes: true
  platform:
    githubActions:
      release:
        enabled: true
EOF
  run layer_validate_type "${TEST_DIR}/layer.yaml"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"main"* ]]
  [[ "$output" == *"platform"* ]]
}
