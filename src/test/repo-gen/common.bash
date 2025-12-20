#!/usr/bin/env bash
#
# common.bash - Shared functions for repo generation scripts
#

set -euo pipefail

# Initialize a new repo in the given directory
init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  cd "$dir"
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"
}

# Create a commit with a file
commit_file() {
  local filename="$1"
  local content="$2"
  local message="$3"
  echo "$content" > "$filename"
  git add "$filename"
  git commit --quiet -m "$message"
}

# Create an annotated tag (with 1s delay to ensure unique timestamps)
create_tag() {
  local tag="$1"
  local message="${2:-Test tag}"
  sleep 1
  git tag -m "$message" "$tag" HEAD
}

# Bundle the repo to fixtures
bundle_repo() {
  local name="$1"
  local fixtures_dir="${2:-$(dirname "$0")/../fixtures}"
  mkdir -p "$fixtures_dir"
  git bundle create "$fixtures_dir/${name}.bundle" --all
  echo "Created bundle: $fixtures_dir/${name}.bundle"
}

# Log what we're doing
log() {
  echo ">>> $*" >&2
}
