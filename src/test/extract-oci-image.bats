#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

SCRIPT="$UTIL_DIR/extract-oci-image"

# Custom mock: handles image inspect, pull, create, cp, rm.
# Control variables (exported before running the script):
#   MOCK_IMAGE_EXISTS   - true/false: whether image inspect finds a cached image (default: true)
#   MOCK_CP_FAIL_PATHS  - space-separated paths that cp should fail on (default: empty)
setup() {
  local base_dir
  base_dir=$(create_test_dir "extract-oci-image")
  export OUTPUT_DIR="${base_dir}/output"
  export MOCK_DOCKER_CALLS="${base_dir}/calls.log"
  export MOCK_IMAGE_EXISTS="true"
  export MOCK_CP_FAIL_PATHS=""
  export MOCK_SAVE_LAYER_FILES=""
  export MOCK_SAVE_WHITEOUTS=""
  export IMAGE_BUILD_COMMAND="docker"

  mkdir -p "${MOCK_BIN_DIR}"
  cat > "${MOCK_BIN_DIR}/docker" << 'MOCK'
#!/usr/bin/env bash
echo "$*" >> "${MOCK_DOCKER_CALLS}"
case "$1" in
  image)
    case "$2" in
      inspect)
        if [[ "${MOCK_IMAGE_EXISTS:-true}" == "true" ]]; then exit 0; else exit 1; fi
        ;;
      save)
        tmp_save=$(mktemp -d "$(dirname "${MOCK_DOCKER_CALLS}")/docker-save-XXXXXX")
        mkdir -p "${tmp_save}/abc123"
        layer_dir="${tmp_save}/layer_content"
        mkdir -p "${layer_dir}"
        if [[ -n "${MOCK_SAVE_LAYER_FILES:-}" ]]; then
          for f in ${MOCK_SAVE_LAYER_FILES}; do
            mkdir -p "${layer_dir}/$(dirname "${f#/}")"
            touch "${layer_dir}/${f#/}"
          done
        fi
        if [[ -n "${MOCK_SAVE_WHITEOUTS:-}" ]]; then
          for wh in ${MOCK_SAVE_WHITEOUTS}; do
            wh_dir="$(dirname "${wh#/}")"
            wh_base="$(basename "${wh}")"
            mkdir -p "${layer_dir}/${wh_dir}"
            touch "${layer_dir}/${wh_dir}/.wh.${wh_base}"
          done
        fi
        tar -c -C "${layer_dir}" -f "${tmp_save}/abc123/layer.tar" .
        printf '[{"Config":"abc123.json","RepoTags":["mock:latest"],"Layers":["abc123/layer.tar"]}]\n' > "${tmp_save}/manifest.json"
        tar -c -C "${tmp_save}" -f - manifest.json abc123/layer.tar
        rm -rf "${tmp_save}"
        ;;
    esac
    ;;
  pull)
    exit 0
    ;;
  create)
    echo "mock-container-abc123"
    ;;
  cp)
    src_path="${2#*:}"
    dest="${3}"
    if [[ -n "${MOCK_CP_FAIL_PATHS:-}" ]] && [[ "${MOCK_CP_FAIL_PATHS}" == *"${src_path}"* ]]; then
      exit 1
    fi
    # Whole-image extraction (src is /) - just succeed
    if [[ "${src_path}" == "/" ]]; then
      exit 0
    fi
    mkdir -p "${dest}"
    touch "${dest}/$(basename "${src_path}")"
    ;;
  rm)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker"
  cp "${MOCK_BIN_DIR}/docker" "${MOCK_BIN_DIR}/podman"
  chmod +x "${MOCK_BIN_DIR}/podman"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
}

teardown() {
  :
}

# =============================================================================
# Missing arguments
# =============================================================================

@test "fails when no arguments provided" {
  run "${SCRIPT}"
  [ "${status}" -ne 0 ]
}

@test "fails when output-dir not provided" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0"
  [ "${status}" -ne 0 ]
}

@test "fails when IMAGE_BUILD_COMMAND not set" {
  unset IMAGE_BUILD_COMMAND
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -ne 0 ]
}

# =============================================================================
# Cache behaviour
# =============================================================================

@test "pulls image when not in local cache" {
  export MOCK_IMAGE_EXISTS="false"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_docker_called "pull ghcr.io/test/img:1.0"
}

@test "skips pull when image is already in local cache" {
  export MOCK_IMAGE_EXISTS="true"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_docker_not_called "pull"
}

@test "logs cache hit message when image is cached" {
  export MOCK_IMAGE_EXISTS="true"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_output_contains "Using cached ghcr.io/test/img:1.0"
}

@test "logs pull message when image is not cached" {
  export MOCK_IMAGE_EXISTS="false"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_output_contains "Pulling ghcr.io/test/img:1.0"
}

# =============================================================================
# Output directory
# =============================================================================

@test "creates output directory if it does not exist" {
  local new_dir="${OUTPUT_DIR}/does/not/exist"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${new_dir}" "/KaptainPM.yaml"
  [ "${status}" -eq 0 ]
  [ -d "${new_dir}" ]
}

@test "succeeds when output directory already exists" {
  mkdir -p "${OUTPUT_DIR}"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/KaptainPM.yaml"
  [ "${status}" -eq 0 ]
}

# =============================================================================
# Single path extraction
# =============================================================================

@test "extracts root-level file to output directory" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/KaptainPM.yaml"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/KaptainPM.yaml" ]
}

@test "extracts subdirectory file preserving path structure" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/dirA/config.yaml"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/dirA/config.yaml" ]
}

@test "extracts deeply nested file preserving full path structure" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/a/b/c/deep.yaml"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/a/b/c/deep.yaml" ]
}

@test "extracts path without leading slash preserving directory structure" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "scripts/deploy.sh"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/scripts/deploy.sh" ]
}

@test "extracts relative path three levels deep preserving full structure" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "a/b/c/deep.yaml"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/a/b/c/deep.yaml" ]
}

@test "logs extracted path on success" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/KaptainPM.yaml"
  [ "${status}" -eq 0 ]
  assert_output_contains "Extracted: /KaptainPM.yaml"
}

# =============================================================================
# Multiple paths - collision avoidance
# =============================================================================

@test "extracts multiple files in one call" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/KaptainPM.yaml" "/dirA/config.yaml"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/KaptainPM.yaml" ]
  [ -f "${OUTPUT_DIR}/dirA/config.yaml" ]
}

@test "avoids collision for same filename in different image directories" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/dirA/config.yaml" "/dirB/config.yaml"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/dirA/config.yaml" ]
  [ -f "${OUTPUT_DIR}/dirB/config.yaml" ]
}

# =============================================================================
# Whole-image extraction
# =============================================================================

@test "extracts entire image when no paths given" {
  export MOCK_SAVE_LAYER_FILES="/scripts/deploy.sh"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_docker_called "image save ghcr.io/test/img:1.0"
  [ -f "${OUTPUT_DIR}/scripts/deploy.sh" ]
}

@test "does not create container for whole-image extraction" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_docker_not_called "create"
}

@test "logs whole-image extraction message" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_output_contains "Extracting entire image filesystem"
}

@test "warns about whiteout files in extracted image" {
  export MOCK_SAVE_WHITEOUTS="/scripts/old.sh"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_output_contains "WARNING:"
  assert_output_contains ".wh.old.sh"
}

@test "leaves whiteout files in output directory" {
  export MOCK_SAVE_WHITEOUTS="/scripts/old.sh"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/scripts/.wh.old.sh" ]
}

# =============================================================================
# Failure on missing path
# =============================================================================

@test "fails when requested path is not in image" {
  export MOCK_CP_FAIL_PATHS="/missing/file.yaml"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/missing/file.yaml"
  [ "${status}" -ne 0 ]
}

@test "logs error message identifying the path that failed" {
  export MOCK_CP_FAIL_PATHS="/not/there.yaml"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/not/there.yaml"
  [ "${status}" -ne 0 ]
  assert_output_contains "ERROR:"
  assert_output_contains "/not/there.yaml"
}

@test "fails on first missing path without extracting subsequent paths" {
  export MOCK_CP_FAIL_PATHS="/first.yaml"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/first.yaml" "/second.yaml"
  [ "${status}" -ne 0 ]
  [ ! -f "${OUTPUT_DIR}/second.yaml" ]
}

# =============================================================================
# Container cleanup
# =============================================================================

@test "removes container after successful extraction" {
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/KaptainPM.yaml"
  [ "${status}" -eq 0 ]
  assert_docker_called "rm mock-container-abc123"
}

@test "removes container after failed extraction" {
  export MOCK_CP_FAIL_PATHS="/missing.yaml"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/missing.yaml"
  [ "${status}" -ne 0 ]
  assert_docker_called "rm mock-container-abc123"
}

# =============================================================================
# Podman support
# =============================================================================

@test "works with podman as IMAGE_BUILD_COMMAND" {
  export IMAGE_BUILD_COMMAND="podman"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}" "/KaptainPM.yaml"
  [ "${status}" -eq 0 ]
  [ -f "${OUTPUT_DIR}/KaptainPM.yaml" ]
}

@test "pulls via podman when image not in local cache" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_IMAGE_EXISTS="false"
  run "${SCRIPT}" "ghcr.io/test/img:1.0" "${OUTPUT_DIR}"
  [ "${status}" -eq 0 ]
  assert_docker_called "pull ghcr.io/test/img:1.0"
}
