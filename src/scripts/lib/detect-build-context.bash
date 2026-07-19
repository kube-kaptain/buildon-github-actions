#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# detect-build-context - Auto-detect pre-yaml build context vars
#
# Sets git context, build mode/platform, branch config, and registry/namespace
# from git + filesystem inspection. All variables can be overridden via
# environment before sourcing. No side effects beyond env exports.
#
# Requires log_error to be available (sourced from lib/log.bash or stubbed).
#

# =============================================================================
# Git Context Auto-Detection
# =============================================================================

# Remote name detection:
#   1. REMOTE_NAME set via environment - use it
#   2. "origin" exists - use it (most common)
#   3. Only one remote - use it
#   4. No remotes - nominal "origin" (bootstrap: refs won't resolve, content
#      checks warn and skip; never fatal here)
#   5. Multiple remotes, none called "origin" - fail (explicit config required)
if [[ -z "${REMOTE_NAME:-}" ]]; then
  all_remotes=$(git remote 2>/dev/null || true)
  if [[ -z "${all_remotes}" ]]; then
    remote_count=0
  else
    remote_count=$(echo "${all_remotes}" | grep -c .)
  fi
  if [[ "${remote_count}" -eq 0 ]]; then
    REMOTE_NAME="origin"
    echo "WARNING: No git remotes configured - bootstrap mode, target refs will not resolve and content checks will be skipped with warnings" >&2
  elif echo "${all_remotes}" | grep -q '^origin$'; then
    REMOTE_NAME="origin"
  elif [[ "${remote_count}" -eq 1 ]]; then
    REMOTE_NAME="${all_remotes}"
  else
    log_error "Multiple remotes found but none called 'origin':"
    # shellcheck disable=SC2001  # Need sed to prepend to each line; bash parameter expansion can't do this
    echo "${all_remotes}" | sed 's/^/  /' >&2
    log_error "Set REMOTE_NAME to specify which remote to use"
    exit 1
  fi
fi

GIT_REMOTE_URL=$(git config --get "remote.${REMOTE_NAME}.url" 2>/dev/null || echo "")

# Current branch. Detached HEAD is a hard error on the local path: CI runs
# detached but always provides the vars; a human should check out a branch.
# No git repo at all (source archive / staged tree copy): bootstrap - default
# to main with a warning; steps that genuinely need git fail at their own
# point with their own errors.
export CURRENT_BRANCH="${CURRENT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")}"
if [[ "${CURRENT_BRANCH}" == "HEAD" ]]; then
  log_error "Detached HEAD: check out a branch, or provide CURRENT_BRANCH/TARGET_BRANCH/RELEASE_BRANCH via environment"
  exit 1
fi
if [[ -z "${CURRENT_BRANCH}" ]]; then
  CURRENT_BRANCH="main"
  echo "WARNING: Not a git repository (or no HEAD) - defaulting CURRENT_BRANCH to main (bootstrap)" >&2
fi

# Target derivation:
#   1. KAPTAIN_LOCAL_RELEASE - write NONE of the three; the release path owns
#      them (file policy applies at load, current branch must match it).
#   2. KAPTAIN_BRANCH_OVERRIDE=X - all three := X. Bare value = branch name
#      (remote-prefixed); refs/tags/T targets a tag; <remote>/<branch> is
#      used as written.
#   3. Branch upstream config - respected verbatim: tag upstream -> the plain
#      tag name; branch upstream -> <configured-remote>/<branch>; remote "."
#      -> the merge ref as a local branch name.
#   4. Guess: HEAD symbolic ref for the remote, single remote branch,
#      <remote>/main|master, fallback <remote>/main.
# Two dialects are emitted deliberately:
#   - The three vars carry the PRETTY name (origin/main, 1.34.4.1, mybranch)
#     for humans and name comparisons. A bare local branch name never equals
#     the remote-prefixed value, so no local build ever classifies as a
#     release-branch build; KAPTAIN_LOCAL_RELEASE is the only local release
#     path.
#   - TARGET_REF carries the fully-qualified resolved ref (refs/remotes/...,
#     refs/tags/..., refs/heads/...) as the no-further-guessing marker for
#     content checks. Consumers use it verbatim when present; absent (CI bare
#     names) they fall back to their own resolution.
# If the ref does not resolve (bootstrap, unpushed line), content checks warn
# and skip - never fatal here. Each of DEFAULT_BRANCH, TARGET_BRANCH,
# RELEASE_BRANCH remains independently overridable via environment.
if [[ -z "${KAPTAIN_LOCAL_RELEASE:-}" ]]; then
  if [[ -z "${UPSTREAM_BRANCH:-}" ]]; then
    UPSTREAM_REF=""
    if [[ -n "${KAPTAIN_BRANCH_OVERRIDE:-}" ]]; then
      case "${KAPTAIN_BRANCH_OVERRIDE}" in
        refs/tags/*)
          UPSTREAM_BRANCH="${KAPTAIN_BRANCH_OVERRIDE#refs/tags/}"
          UPSTREAM_REF="${KAPTAIN_BRANCH_OVERRIDE}"
          ;;
        refs/*)
          UPSTREAM_BRANCH="${KAPTAIN_BRANCH_OVERRIDE}"
          UPSTREAM_REF="${KAPTAIN_BRANCH_OVERRIDE}"
          ;;
        */*)
          UPSTREAM_BRANCH="${KAPTAIN_BRANCH_OVERRIDE}"
          UPSTREAM_REF="refs/remotes/${KAPTAIN_BRANCH_OVERRIDE}"
          ;;
        *)
          UPSTREAM_BRANCH="${REMOTE_NAME}/${KAPTAIN_BRANCH_OVERRIDE}"
          UPSTREAM_REF="refs/remotes/${REMOTE_NAME}/${KAPTAIN_BRANCH_OVERRIDE}"
          ;;
      esac
      echo "KAPTAIN_BRANCH_OVERRIDE: default/target/release all set to ${UPSTREAM_BRANCH} (${UPSTREAM_REF})" >&2
    else
      branch_upstream_remote=$(git config --get "branch.${CURRENT_BRANCH}.remote" 2>/dev/null || true)
      branch_upstream_merge=$(git config --get "branch.${CURRENT_BRANCH}.merge" 2>/dev/null || true)
      if [[ -n "${branch_upstream_merge}" ]]; then
        # Respect the branch's own config verbatim - no same-name second-guessing
        case "${branch_upstream_merge}" in
          refs/tags/*)
            UPSTREAM_BRANCH="${branch_upstream_merge#refs/tags/}"
            UPSTREAM_REF="${branch_upstream_merge}"
            ;;
          refs/heads/*)
            if [[ "${branch_upstream_remote}" == "." || -z "${branch_upstream_remote}" ]]; then
              UPSTREAM_BRANCH="${branch_upstream_merge#refs/heads/}"
              UPSTREAM_REF="${branch_upstream_merge}"
            else
              UPSTREAM_BRANCH="${branch_upstream_remote}/${branch_upstream_merge#refs/heads/}"
              UPSTREAM_REF="refs/remotes/${branch_upstream_remote}/${branch_upstream_merge#refs/heads/}"
            fi
            ;;
          *)
            UPSTREAM_BRANCH="${branch_upstream_merge}"
            UPSTREAM_REF="${branch_upstream_merge}"
            ;;
        esac
      else
        # Guess - result is always a remote branch. A release-line-looking
        # branch (anything starting main or master, whatever the suffix
        # convention) targets its OWN remote counterpart unconditionally:
        # pushed -> real content checks against its line; unpushed -> the ref
        # does not resolve, content checks warn and skip, and the guidance
        # names the push that restores them. Anything else: remote HEAD when
        # set (handles nonstandard default branches), else main/master by
        # existence, else blind main - a wrong guess degrades to warn+skip
        # with config guidance, never a hard failure.
        case "${CURRENT_BRANCH}" in
          main*|master*)
            UPSTREAM_BRANCH="${REMOTE_NAME}/${CURRENT_BRANCH}"
            ;;
        esac
        if [[ -z "${UPSTREAM_BRANCH:-}" ]]; then
          UPSTREAM_BRANCH=$(git symbolic-ref "refs/remotes/${REMOTE_NAME}/HEAD" 2>/dev/null | sed 's@^refs/remotes/@@' || true)
        fi
        if [[ -z "${UPSTREAM_BRANCH}" ]]; then
          if git rev-parse --verify --quiet "refs/remotes/${REMOTE_NAME}/main" >/dev/null 2>&1; then
            UPSTREAM_BRANCH="${REMOTE_NAME}/main"
          elif git rev-parse --verify --quiet "refs/remotes/${REMOTE_NAME}/master" >/dev/null 2>&1; then
            UPSTREAM_BRANCH="${REMOTE_NAME}/master"
          else
            UPSTREAM_BRANCH="${REMOTE_NAME}/main"
          fi
        fi
        UPSTREAM_REF="refs/remotes/${UPSTREAM_BRANCH}"
      fi
      unset branch_upstream_remote branch_upstream_merge
    fi
  fi
  export DEFAULT_BRANCH="${DEFAULT_BRANCH:-${UPSTREAM_BRANCH}}"
  export TARGET_BRANCH="${TARGET_BRANCH:-${UPSTREAM_BRANCH}}"
  export RELEASE_BRANCH="${RELEASE_BRANCH:-${UPSTREAM_BRANCH}}"
  # The marker only accompanies the value it describes: if TARGET_BRANCH was
  # env-overridden away from the derived value, do not attach a mismatched ref.
  if [[ "${TARGET_BRANCH}" == "${UPSTREAM_BRANCH}" && -n "${UPSTREAM_REF:-}" ]]; then
    export TARGET_REF="${TARGET_REF:-${UPSTREAM_REF}}"
  fi
fi

# Pass the kaptain knobs through so load and downstream see them
export KAPTAIN_BRANCH_OVERRIDE="${KAPTAIN_BRANCH_OVERRIDE:-}"
export KAPTAIN_LOCAL_RELEASE="${KAPTAIN_LOCAL_RELEASE:-}"

# Repository name from remote URL (works for SSH and HTTPS, with or without .git suffix)
export REPOSITORY_NAME="${REPOSITORY_NAME:-$(echo "${GIT_REMOTE_URL}" | sed 's|.*/||' | sed 's|\.git$||')}"

# Repository owner from remote URL (path segment before repo name)
export REPOSITORY_OWNER="${REPOSITORY_OWNER:-$(echo "${GIT_REMOTE_URL}" | sed -E 's|.*[:/]([^/]+)/[^/]+$|\1|')}"

# Bootstrap (no remote URL to parse): directory name and a nominal owner so
# the env contract stays complete; publishing anywhere real requires a remote.
if [[ -z "${REPOSITORY_NAME}" ]]; then
  REPOSITORY_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
  echo "WARNING: No remote URL - REPOSITORY_NAME defaulted to directory name '${REPOSITORY_NAME}' (bootstrap)" >&2
fi
if [[ -z "${REPOSITORY_OWNER}" ]]; then
  REPOSITORY_OWNER="${USER:-local}"
  echo "WARNING: No remote URL - REPOSITORY_OWNER defaulted to '${REPOSITORY_OWNER}' (bootstrap)" >&2
fi


# =============================================================================
# Build Context
# =============================================================================

export BUILD_MODE="${BUILD_MODE:-local}"
export BUILD_PLATFORM="${BUILD_PLATFORM:-local}"
export BUILD_PLATFORM_LOG_PROVIDER="${BUILD_PLATFORM_LOG_PROVIDER:-stdout}"

export DOCKER_REGISTRY_LOGINS="{}"
export SECRET_METHOD='env'

# =============================================================================
# Branch Configuration
# =============================================================================

export MERGE_CANDIDATE_CREATOR="${MERGE_CANDIDATE_CREATOR:-$(git config user.name 2>/dev/null || whoami)}"


# =============================================================================
# Registry and Namespace Auto-Detection
# =============================================================================

# Auto-detect registry from CI provider config files in the repo
if [[ -z "${DOCKER_TARGET_REGISTRY:-}" ]]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  # shellcheck disable=SC2012
  if ls "${REPO_ROOT}"/.github/workflows/*.y*ml >/dev/null 2>&1; then
    DOCKER_TARGET_REGISTRY="ghcr.io"
  elif [[ -f "${REPO_ROOT}/.gitlab-ci.yml" ]]; then
    DOCKER_TARGET_REGISTRY="registry.gitlab.com"
  else
    DOCKER_TARGET_REGISTRY="localhost"
  fi
fi
export DOCKER_TARGET_REGISTRY

# Namespace is everything between domain and repo name in the git URL, lowercased
if [[ -z "${DOCKER_TARGET_NAMESPACE:-}" ]] && [[ -n "${GIT_REMOTE_URL}" ]]; then
  # Extract the path from the URL (strip domain and repo name)
  # SSH:   git@github.com:org/repo.git      -> org
  # HTTPS: https://github.com/org/repo      -> org
  # HTTPS: https://gitlab.com/g/sub/repo    -> g/sub
  url_path=""
  if [[ "${GIT_REMOTE_URL}" == *"://"* ]]; then
    # HTTPS: strip scheme + domain, then strip repo name
    url_path=$(echo "${GIT_REMOTE_URL}" | sed -E 's|https?://[^/]+/||' | sed 's|/[^/]*$||' | sed 's|\.git$||')
  else
    # SSH: strip user@host:, then strip repo name
    url_path=$(echo "${GIT_REMOTE_URL}" | sed -E 's|[^:]+:||' | sed 's|/[^/]*$||' | sed 's|\.git$||')
  fi
  DOCKER_TARGET_NAMESPACE=$(echo "${url_path}" | tr '[:upper:]' '[:lower:]')
  unset url_path
else
  DOCKER_TARGET_NAMESPACE="${BUILD_MODE}"
fi
export DOCKER_TARGET_NAMESPACE
