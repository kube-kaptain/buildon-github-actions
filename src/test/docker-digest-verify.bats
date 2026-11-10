#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/docker-digest-verify.bash - checking that a FROM tag@digest
# pin still matches what the tag resolves to, per image store, and finding the
# pinned FROM lines and the platform each pulls for.

bats_require_minimum_version 1.5.0

load helpers

INDEX="sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c"
AMD64="sha256:1c4eef651f65e2f7daee7ee785882ac164b02b78fb74503052a26dc061c90474"
OTHER="sha256:757d680068d77be46fd1ea20fb21db16f150468c5e7079a08a2e4705aec096ac"

setup() {
  WORK=$(create_test_dir "docker-digest-verify")
  export MOCK_CALLS="${WORK}/calls.log"
  : > "${MOCK_CALLS}"
  mkdir -p "${MOCK_BIN_DIR}"
  # Image store mock. MOCK_STORE picks what `info` reports (containerd or
  # classic); inspect answers come from MOCK_REPO_DIGESTS (podman),
  # MOCK_TAG_ID / MOCK_PLATFORM_ID (containerd) and MOCK_TAG_ID / MOCK_PIN_ID
  # (classic). MOCK_PULL_FAILS fails pulls of references containing it.
  # MOCK_INSPECT_FAILS=true fails the RepoDigests inspect.
  # Like podman, the RepoDigests inspect writes each digest and then a lone
  # newline as separate writes. MOCK_SLOW_WRITES=true makes every write come
  # late, as from a tool held up between writes; a write that finds its reader
  # gone ends the tool with 141, as SIGPIPE does.
  cat > "${MOCK_BIN_DIR}/docker" << 'MOCK'
#!/usr/bin/env bash
echo "$*" >> "${MOCK_CALLS}"
ref="${!#}"
late_write() {
  if [[ "${MOCK_SLOW_WRITES:-false}" == "true" ]]; then
    sleep 0.2
  fi
  echo "$1" 2> /dev/null || exit 141
}
case "$1" in
  pull)
    if [[ -n "${MOCK_PULL_FAILS:-}" && "${ref}" == *"${MOCK_PULL_FAILS}"* ]]; then
      exit 1
    fi
    ;;
  info)
    if [[ "${MOCK_STORE:-classic}" == "containerd" ]]; then
      late_write "[[driver-type io.containerd.snapshotter.v1]]"
      late_write "[[more driver status]]"
    fi
    ;;
  image)
    if [[ "$*" == *RepoDigests* ]]; then
      if [[ "${MOCK_INSPECT_FAILS:-false}" == "true" ]]; then
        echo "Error: mock inspect failure" >&2
        exit 125
      fi
      for repo_digest in ${MOCK_REPO_DIGESTS:-}; do
        late_write "${repo_digest}"
      done
      late_write ""
    elif [[ "$*" == *--platform* ]]; then
      echo "${MOCK_PLATFORM_ID:-}"
    elif [[ "${ref}" == *@* ]]; then
      echo "${MOCK_PIN_ID:-}"
    else
      echo "${MOCK_TAG_ID:-}"
    fi
    ;;
esac
exit 0
MOCK
  chmod +x "${MOCK_BIN_DIR}/docker"
  cp "${MOCK_BIN_DIR}/docker" "${MOCK_BIN_DIR}/podman"
  export PATH="${MOCK_BIN_DIR}:${PATH}"
  export IMAGE_BUILD_COMMAND="docker"

  # shellcheck source=src/scripts/lib/docker-digest-verify.bash
  source "$LIB_DIR/docker-digest-verify.bash"
}

teardown() {
  dump_bats_result
}

write_dockerfile() {
  cat > "${WORK}/Dockerfile"
}

# Run the check in a shell set up as its callers are (extract-oci-image,
# docker-build-dockerfile): set -euo pipefail on.
# Usage: run_as_callers_do <tagged-ref> <digest> <platform>
run_as_callers_do() {
  run bash -c 'set -euo pipefail
    source "$1/../defaults/platform.bash"
    source "$1/log.bash"
    source "$1/docker-digest-verify.bash"
    shift
    verify_digest_matches_tag "$@"' as-callers-do "${LIB_DIR}" "$@"
}

# =============================================================================
# verify_digest_matches_tag - per image store
# =============================================================================

@test "podman: index digest among the tag's RepoDigests matches" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_REPO_DIGESTS="docker.io/library/alpine@${INDEX} docker.io/library/alpine@${AMD64}"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${INDEX}" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/amd64 docker.io/library/alpine:3.21.3" "${MOCK_CALLS}" || return 1
}

@test "podman: platform digest among the tag's RepoDigests matches" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_REPO_DIGESTS="docker.io/library/alpine@${INDEX} docker.io/library/alpine@${AMD64}"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${AMD64}" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
}

@test "podman: a digest not among the tag's RepoDigests is a mismatch" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_REPO_DIGESTS="docker.io/library/alpine@${INDEX} docker.io/library/alpine@${AMD64}"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${OTHER}" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"Digest mismatch for linux/amd64"* ]] || return 1
}

@test "podman: still writing after the pin's line is no mismatch, under the callers' pipefail" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_SLOW_WRITES="true"
  export MOCK_REPO_DIGESTS="docker.io/library/alpine@${AMD64} docker.io/library/alpine@${INDEX}"
  run_as_callers_do "docker.io/library/alpine:3.21.3" "${INDEX}" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  [[ "$output" == *"Digest verified for linux/amd64"* ]] || return 1
}

@test "podman: a pin on the first of several lines is verified with more still to come" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_SLOW_WRITES="true"
  export MOCK_REPO_DIGESTS="docker.io/library/alpine@${AMD64} docker.io/library/alpine@${INDEX}"
  run_as_callers_do "docker.io/library/alpine:3.21.3" "${AMD64}" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  [[ "$output" == *"Digest verified for linux/amd64"* ]] || return 1
}

@test "podman: a real mismatch is still one with slow writes" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_SLOW_WRITES="true"
  export MOCK_REPO_DIGESTS="docker.io/library/alpine@${AMD64} docker.io/library/alpine@${INDEX}"
  run_as_callers_do "docker.io/library/alpine:3.21.3" "${OTHER}" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"Digest mismatch for linux/amd64"* ]] || return 1
}

@test "podman: an inspect that fails is reported as that, not as a mismatch" {
  export IMAGE_BUILD_COMMAND="podman"
  export MOCK_INSPECT_FAILS="true"
  run_as_callers_do "docker.io/library/alpine:3.21.3" "${INDEX}" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"Could not inspect docker.io/library/alpine:3.21.3 to verify digest ${INDEX}"* ]] || return 1
  [[ "$output" != *"Digest mismatch"* ]] || return 1
}

@test "containerd: the store is detected with docker still writing after the matching status" {
  export MOCK_STORE="containerd"
  export MOCK_SLOW_WRITES="true"
  export MOCK_TAG_ID="${INDEX}"
  export MOCK_PLATFORM_ID="${AMD64}"
  run_as_callers_do "docker.io/library/alpine:3.21.3" "${AMD64}" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "image inspect --platform linux/amd64" "${MOCK_CALLS}" || return 1
}

@test "containerd: index digest matches the tag's Id" {
  export MOCK_STORE="containerd"
  export MOCK_TAG_ID="${INDEX}"
  export MOCK_PLATFORM_ID="${AMD64}"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${INDEX}" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
}

@test "containerd: platform digest matches the tag's platform Id" {
  export MOCK_STORE="containerd"
  export MOCK_TAG_ID="${INDEX}"
  export MOCK_PLATFORM_ID="${AMD64}"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${AMD64}" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "image inspect --platform linux/amd64" "${MOCK_CALLS}" || return 1
}

@test "containerd: a digest matching neither Id is a mismatch" {
  export MOCK_STORE="containerd"
  export MOCK_TAG_ID="${INDEX}"
  export MOCK_PLATFORM_ID="${AMD64}"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${OTHER}" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"Digest mismatch"* ]] || return 1
}

@test "classic: the pin's Id equal to the tag's Id matches, and the pin is untagged" {
  export MOCK_TAG_ID="sha256:config"
  export MOCK_PIN_ID="sha256:config"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${INDEX}" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/amd64 docker.io/library/alpine@${INDEX}" "${MOCK_CALLS}" || return 1
  grep -q -- "rmi docker.io/library/alpine@${INDEX}" "${MOCK_CALLS}" || return 1
}

@test "classic: a different Id is a mismatch" {
  export MOCK_TAG_ID="sha256:config"
  export MOCK_PIN_ID="sha256:otherconfig"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${OTHER}" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"Digest mismatch"* ]] || return 1
}

@test "classic: two empty Ids are a mismatch, not a match" {
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${INDEX}" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"Digest mismatch"* ]] || return 1
}

@test "classic: a pin that cannot be pulled is a mismatch" {
  export MOCK_TAG_ID="sha256:config"
  export MOCK_PIN_ID="sha256:config"
  export MOCK_PULL_FAILS="@"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${INDEX}" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
}

@test "a tag that cannot be pulled fails before any inspect" {
  export MOCK_PULL_FAILS="alpine:3.21.3"
  run verify_digest_matches_tag "docker.io/library/alpine:3.21.3" "${INDEX}" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"Failed to pull docker.io/library/alpine:3.21.3"* ]] || return 1
  [[ $(grep -c "image inspect" "${MOCK_CALLS}") -eq 0 ]] || return 1
}

# =============================================================================
# verify_dockerfile_from_digests - which FROM lines, and for which platform
# =============================================================================

@test "dockerfile: a tag@digest FROM is verified for the platform being built" {
  export MOCK_TAG_ID="sha256:config" MOCK_PIN_ID="sha256:config"
  write_dockerfile << EOF
FROM alpine:3.21.3@${INDEX}
RUN true
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/arm64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/arm64 alpine:3.21.3$" "${MOCK_CALLS}" || return 1
}

@test "dockerfile: FROM lines without both a tag and a digest are not pulled" {
  write_dockerfile << EOF
FROM alpine:3.21.3 AS one
FROM alpine@${INDEX} AS two
FROM scratch
FROM one
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  [[ $(grep -c "pull" "${MOCK_CALLS}") -eq 0 ]] || return 1
}

@test "dockerfile: lowercase from, other flags and AS are handled" {
  export MOCK_TAG_ID="sha256:config" MOCK_PIN_ID="sha256:config"
  write_dockerfile << EOF
from --some-flag=x alpine:3.21.3@${INDEX} as base
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/amd64 alpine:3.21.3$" "${MOCK_CALLS}" || return 1
}

@test "dockerfile: a registry port is not mistaken for the tag" {
  export MOCK_TAG_ID="sha256:config" MOCK_PIN_ID="sha256:config"
  write_dockerfile << EOF
FROM localhost:5000/team/app:1.2@${INDEX}
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/amd64 localhost:5000/team/app:1.2$" "${MOCK_CALLS}" || return 1
  grep -q -- "pull --platform linux/amd64 localhost:5000/team/app@${INDEX}" "${MOCK_CALLS}" || return 1
}

@test "dockerfile: a literal FROM --platform is the platform verified" {
  export MOCK_TAG_ID="sha256:config" MOCK_PIN_ID="sha256:config"
  write_dockerfile << EOF
FROM --platform=linux/arm64 alpine:3.21.3@${INDEX}
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/arm64 alpine:3.21.3$" "${MOCK_CALLS}" || return 1
  [[ $(grep -c "linux/amd64" "${MOCK_CALLS}") -eq 0 ]] || return 1
}

@test "dockerfile: FROM --platform=\$BUILDPLATFORM is verified for this host" {
  export MOCK_TAG_ID="sha256:config" MOCK_PIN_ID="sha256:config"
  local host
  host=$(build_host_platform)
  [[ -n "${host}" ]] || skip "host arch $(uname -m) has no linux platform mapping"
  write_dockerfile << 'EOF'
FROM --platform=$BUILDPLATFORM alpine:3.21.3@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c AS build
FROM --platform=${BUILDPLATFORM} busybox:1.37@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/riscv64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform ${host} alpine:3.21.3$" "${MOCK_CALLS}" || return 1
  grep -q -- "pull --platform ${host} busybox:1.37$" "${MOCK_CALLS}" || return 1
}

@test "dockerfile: FROM --platform=\$TARGETPLATFORM is verified for the platform being built" {
  export MOCK_TAG_ID="sha256:config" MOCK_PIN_ID="sha256:config"
  write_dockerfile << 'EOF'
FROM --platform=$TARGETPLATFORM alpine:3.21.3@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/riscv64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/riscv64 alpine:3.21.3$" "${MOCK_CALLS}" || return 1
}

@test "dockerfile: an unresolvable FROM --platform variable warns and is not verified" {
  write_dockerfile << 'EOF'
FROM --platform=$MYPLATFORM alpine:3.21.3@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  [[ "$output" == *"FROM platform cannot be resolved, digest not verified"* ]] || return 1
  [[ $(grep -c "pull" "${MOCK_CALLS}") -eq 0 ]] || return 1
}

@test "dockerfile: an image built from a variable warns and is not verified" {
  write_dockerfile << 'EOF'
ARG BASE=alpine:3.21.3@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
FROM ${BASE}
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  [[ "$output" == *"FROM is not a direct image reference, digest not verified"* ]] || return 1
  [[ $(grep -c "pull" "${MOCK_CALLS}") -eq 0 ]] || return 1
}

@test "dockerfile: a FROM split over continuation lines is still verified" {
  export MOCK_TAG_ID="sha256:config" MOCK_PIN_ID="sha256:config"
  write_dockerfile << EOF
FROM --platform=linux/arm64 \\
    alpine:3.21.3@${INDEX} \\
    AS base
RUN true
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/arm64 alpine:3.21.3$" "${MOCK_CALLS}" || return 1
}

@test "dockerfile: an invalid digest fails without pulling" {
  write_dockerfile << 'EOF'
FROM alpine:3.21.3@sha256:abc
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  [[ "$output" == *"Invalid digest 'sha256:abc'"* ]] || return 1
  [[ $(grep -c "pull" "${MOCK_CALLS}") -eq 0 ]] || return 1
}

@test "dockerfile: every pinned FROM is checked even after one fails" {
  write_dockerfile << EOF
FROM alpine:3.21.3@${INDEX} AS one
FROM busybox:1.37@${INDEX}
EOF
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 1 ]] || return 1
  grep -q -- "pull --platform linux/amd64 alpine:3.21.3$" "${MOCK_CALLS}" || return 1
  grep -q -- "pull --platform linux/amd64 busybox:1.37$" "${MOCK_CALLS}" || return 1
}

@test "dockerfile: a final line without a trailing newline is read" {
  export MOCK_TAG_ID="sha256:config" MOCK_PIN_ID="sha256:config"
  printf 'FROM alpine:3.21.3@%s' "${INDEX}" > "${WORK}/Dockerfile"
  run verify_dockerfile_from_digests "${WORK}/Dockerfile" "linux/amd64"
  [[ "$status" -eq 0 ]] || return 1
  grep -q -- "pull --platform linux/amd64 alpine:3.21.3$" "${MOCK_CALLS}" || return 1
}
