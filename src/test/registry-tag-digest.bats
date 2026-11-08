#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kaptain contributors (Fred Cooke)
#
# Tests for util/registry-tag-digest: the registry digest of an image tag,
# from skopeo's raw manifest or the registry API's Docker-Content-Digest.

bats_require_minimum_version 1.5.0

load helpers

SCRIPT="$UTIL_DIR/registry-tag-digest"

API_DIGEST="sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"

setup() {
  TEST_DIR=$(create_test_dir "registry-tag-digest")
  export MOCK_CURL_URLS="${TEST_DIR}/curl-urls"
  mkdir -p "${MOCK_BIN_DIR}"

  # Mock skopeo: prints MOCK_SKOPEO_RAW as the raw manifest, fails when unset
  cat > "${MOCK_BIN_DIR}/skopeo" << 'MOCK'
#!/usr/bin/env bash
[[ -n "${MOCK_SKOPEO_RAW:-}" ]] || exit 1
printf '%s' "${MOCK_SKOPEO_RAW}"
MOCK

  # Mock curl: no auth challenge on /v2/, and a HEAD on a manifest answers
  # with MOCK_API_DIGEST as Docker-Content-Digest (no header when unset)
  cat > "${MOCK_BIN_DIR}/curl" << 'MOCK'
#!/usr/bin/env bash
url="${!#}"
echo "${url}" >> "${MOCK_CURL_URLS}"
case "${url}" in
  */v2/)
    printf 'HTTP/1.1 200 OK\r\n\r\n'
    ;;
  */manifests/*)
    printf 'HTTP/1.1 200 OK\r\n'
    [[ -n "${MOCK_API_DIGEST:-}" ]] && printf 'Docker-Content-Digest: %s\r\n' "${MOCK_API_DIGEST}"
    printf '\r\n'
    ;;
esac
exit 0
MOCK
  chmod +x "${MOCK_BIN_DIR}/skopeo" "${MOCK_BIN_DIR}/curl"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  unset MOCK_SKOPEO_RAW MOCK_API_DIGEST
}

teardown() {
  dump_bats_result
}

@test "skopeo: the digest is the SHA-256 of the raw manifest bytes, trailing newline included" {
  export MOCK_SKOPEO_RAW=$'{"schemaVersion":2}\n'
  local expected
  expected="sha256:$(printf '%s' "${MOCK_SKOPEO_RAW}" | shasum -a 256 | awk '{print $1}')"
  run --separate-stderr "$SCRIPT" "ghcr.io/org/app:1.0"
  [[ "$status" -eq 0 ]] || return 1
  [[ "$output" == "${expected}" ]] || return 1
  [[ ! -e "${MOCK_CURL_URLS}" ]] || return 1
}

@test "registry API: a failed skopeo falls back to Docker-Content-Digest" {
  export MOCK_API_DIGEST="${API_DIGEST}"
  run --separate-stderr "$SCRIPT" "ghcr.io/org/app:1.0"
  [[ "$status" -eq 0 ]] || return 1
  [[ "$output" == "${API_DIGEST}" ]] || return 1
  grep -qx "https://ghcr.io/v2/org/app/manifests/1.0" "${MOCK_CURL_URLS}" || return 1
}

@test "registry API: Docker Hub is reached at registry-1.docker.io" {
  export MOCK_API_DIGEST="${API_DIGEST}"
  run --separate-stderr "$SCRIPT" "docker.io/library/alpine:3.21.3"
  [[ "$status" -eq 0 ]] || return 1
  [[ "$output" == "${API_DIGEST}" ]] || return 1
  grep -qx "https://registry-1.docker.io/v2/library/alpine/manifests/3.21.3" "${MOCK_CURL_URLS}" || return 1
  [[ "$(grep -c "://docker.io/" "${MOCK_CURL_URLS}")" -eq 0 ]] || return 1
}

@test "a registry port is not mistaken for the tag" {
  export MOCK_API_DIGEST="${API_DIGEST}"
  run --separate-stderr "$SCRIPT" "localhost:5000/team/app:1.2"
  [[ "$status" -eq 0 ]] || return 1
  grep -qx "https://localhost:5000/v2/team/app/manifests/1.2" "${MOCK_CURL_URLS}" || return 1
}

@test "no digest from either source fails" {
  run --separate-stderr "$SCRIPT" "ghcr.io/org/app:1.0"
  [[ "$status" -eq 1 ]] || return 1
  [[ -z "$output" ]] || return 1
  [[ "$stderr" == *"Could not read the registry digest of ghcr.io/org/app:1.0"* ]] || return 1
}

@test "a ref without a tag, with a digest, or without a registry fails" {
  local ref
  for ref in "ghcr.io/org/app" "ghcr.io/org/app:1.0@${API_DIGEST}" "app:1.0" "localhost:5000/app"; do
    run --separate-stderr "$SCRIPT" "${ref}"
    [[ "$status" -eq 1 ]] || { echo "accepted: ${ref}"; return 1; }
    [[ "$stderr" == *"needs registry/path/name:tag"* ]] || { echo "wrong error for: ${ref}"; return 1; }
  done
}
