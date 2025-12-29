# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# helpers.bash - Shared test helper functions

# Get project root
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Path to scripts, repo providers, and fixtures
SCRIPTS_DIR="$PROJECT_ROOT/src/scripts/main"
PLUGINS_DIR="$PROJECT_ROOT/src/scripts/plugins"
REPO_PROVIDERS_DIR="$PLUGINS_DIR/kubernetes-manifests-repo-providers"
FIXTURES_DIR="$PROJECT_ROOT/src/test/fixtures"
MOCK_BIN_DIR="$PROJECT_ROOT/src/test/mock-bin"

# Set up mock git that filters push
setup_mock_git() {
  mkdir -p "$MOCK_BIN_DIR"
  cat > "$MOCK_BIN_DIR/git" << 'MOCKGIT'
#!/usr/bin/env bash
if [[ "$1" == "push" ]]; then
  exit 0
fi
exec /usr/bin/git "$@"
MOCKGIT
  chmod +x "$MOCK_BIN_DIR/git"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

# Clean up mock git
cleanup_mock_git() {
  rm -rf "$MOCK_BIN_DIR"
}

# Clone a test repo from a fixture bundle
clone_fixture() {
  local fixture_name="$1"
  local bundle_path="$FIXTURES_DIR/${fixture_name}.bundle"
  local repo_dir

  if [[ ! -f "$bundle_path" ]]; then
    echo "Fixture not found: $bundle_path" >&2
    return 1
  fi

  repo_dir=$(mktemp -d)
  git clone --quiet "$bundle_path" "$repo_dir" 2>/dev/null
  cd "$repo_dir"
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Set up local main branch if it exists on remote
  if git rev-parse --verify origin/main &>/dev/null; then
    git branch main origin/main &>/dev/null || true
  fi

  echo "$repo_dir"
}

# Create a temporary git repository for testing (legacy, prefer clone_fixture)
create_test_repo() {
  local repo_dir
  repo_dir=$(mktemp -d)

  cd "$repo_dir"
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit
  echo "initial" > README.md
  git add README.md
  git commit --quiet -m "Initial commit"

  echo "$repo_dir"
}

# Cleanup test repository
cleanup_test_repo() {
  local repo_dir="$1"
  if [[ -d "$repo_dir" ]]; then
    rm -rf "$repo_dir"
  fi
}

# Create a branch with specific commits
create_branch_with_commits() {
  local branch_name="$1"
  shift
  local commit_messages=("$@")

  git checkout -b "$branch_name" --quiet

  for msg in "${commit_messages[@]}"; do
    echo "$msg" >> content.txt
    git add content.txt
    git commit --quiet -m "$msg"
  done
}

# Create a tag
create_tag() {
  local tag="$1"
  git tag "$tag"
}

# Get current branch
get_current_branch() {
  git rev-parse --abbrev-ref HEAD
}

# Create merge commit (for testing merge detection)
create_merge_commit() {
  local branch_to_merge="$1"
  git merge --no-ff --quiet -m "Merge $branch_to_merge" "$branch_to_merge"
}

# Assert output contains string
assert_output_contains() {
  local expected="$1"
  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected output to contain: $expected"
    echo "Actual output: $output"
    return 1
  fi
}

# Assert output does not contain string
assert_output_not_contains() {
  local unexpected="$1"
  if [[ "$output" == *"$unexpected"* ]]; then
    echo "Expected output NOT to contain: $unexpected"
    echo "Actual output: $output"
    return 1
  fi
}

# Assert variable equals value
assert_var_equals() {
  local var_name="$1"
  local expected="$2"
  local actual

  actual=$(echo "$output" | grep "^${var_name}=" | cut -d= -f2-)

  if [[ "$actual" != "$expected" ]]; then
    echo "Expected $var_name=$expected"
    echo "Actual $var_name=$actual"
    return 1
  fi
}

# Set up mock docker that logs calls
setup_mock_docker() {
  export MOCK_DOCKER_CALLS=$(mktemp)
  mkdir -p "$MOCK_BIN_DIR"
  cat > "$MOCK_BIN_DIR/docker" << 'MOCKDOCKER'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_DOCKER_CALLS"
if [[ "$1" == "manifest" && "$2" == "inspect" ]]; then
  if [[ "${MOCK_DOCKER_MANIFEST_EXISTS:-false}" == "true" ]]; then
    exit 0
  else
    exit 1
  fi
fi
exit 0
MOCKDOCKER
  chmod +x "$MOCK_BIN_DIR/docker"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

# Clean up mock docker
cleanup_mock_docker() {
  rm -f "$MOCK_DOCKER_CALLS"
  rm -f "$MOCK_BIN_DIR/docker"
}

# Assert docker was called with specific args
assert_docker_called() {
  local expected="$1"
  # Use -- to prevent patterns starting with - from being interpreted as grep options
  if ! grep -q -- "$expected" "$MOCK_DOCKER_CALLS" 2>/dev/null; then
    echo "Expected docker to be called with: $expected"
    echo "Actual calls:"
    cat "$MOCK_DOCKER_CALLS" 2>/dev/null || echo "(none)"
    return 1
  fi
}

# Assert docker was NOT called with specific command
assert_docker_not_called() {
  local unexpected="$1"
  if grep -q "^$unexpected" "$MOCK_DOCKER_CALLS" 2>/dev/null; then
    echo "Expected docker NOT to be called with: $unexpected"
    echo "Actual calls:"
    cat "$MOCK_DOCKER_CALLS"
    return 1
  fi
}

# Set up mock npm that logs calls
setup_mock_npm() {
  export MOCK_NPM_CALLS=$(mktemp)
  mkdir -p "$MOCK_BIN_DIR"
  cat > "$MOCK_BIN_DIR/npm" << 'MOCKNPM'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_NPM_CALLS"
if [[ "$1" == "pack" ]]; then
  # Create a fake tarball and output its name
  tarball_name="package-1.0.0.tgz"
  touch "$tarball_name"
  echo "$tarball_name"
  exit 0
fi
if [[ "$1" == "publish" ]]; then
  exit 0
fi
exit 0
MOCKNPM
  chmod +x "$MOCK_BIN_DIR/npm"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

# Clean up mock npm
cleanup_mock_npm() {
  rm -f "$MOCK_NPM_CALLS"
  rm -f "$MOCK_BIN_DIR/npm"
}

# Assert npm was called with specific args
assert_npm_called() {
  local expected="$1"
  if ! grep -q -- "$expected" "$MOCK_NPM_CALLS" 2>/dev/null; then
    echo "Expected npm to be called with: $expected"
    echo "Actual calls:"
    cat "$MOCK_NPM_CALLS" 2>/dev/null || echo "(none)"
    return 1
  fi
}

# Assert npm was NOT called with specific args
assert_npm_not_called() {
  local unexpected="$1"
  if grep -q "$unexpected" "$MOCK_NPM_CALLS" 2>/dev/null; then
    echo "Expected npm NOT to be called with: $unexpected"
    echo "Actual calls:"
    cat "$MOCK_NPM_CALLS"
    return 1
  fi
}

# Set up mock gem that logs calls
setup_mock_gem() {
  export MOCK_GEM_CALLS=$(mktemp)
  mkdir -p "$MOCK_BIN_DIR"
  cat > "$MOCK_BIN_DIR/gem" << 'MOCKGEM'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_GEM_CALLS"
if [[ "$1" == "build" ]]; then
  # Extract gem name from gemspec path
  gemspec_path="$2"
  gemspec_name=$(basename "$gemspec_path" .gemspec)
  # Create a fake .gem file in current directory
  gem_file="${gemspec_name}-1.0.0.gem"
  touch "$gem_file"
  echo "  Successfully built RubyGem"
  echo "  Name: $gemspec_name"
  echo "  Version: 1.0.0"
  echo "  File: $gem_file"
  exit 0
fi
if [[ "$1" == "push" ]]; then
  exit 0
fi
exit 0
MOCKGEM
  chmod +x "$MOCK_BIN_DIR/gem"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

# Clean up mock gem
cleanup_mock_gem() {
  rm -f "$MOCK_GEM_CALLS"
  rm -f "$MOCK_BIN_DIR/gem"
}

# Assert gem was called with specific args
assert_gem_called() {
  local expected="$1"
  if ! grep -q -- "$expected" "$MOCK_GEM_CALLS" 2>/dev/null; then
    echo "Expected gem to be called with: $expected"
    echo "Actual calls:"
    cat "$MOCK_GEM_CALLS" 2>/dev/null || echo "(none)"
    return 1
  fi
}

# Assert gem was NOT called with specific args
assert_gem_not_called() {
  local unexpected="$1"
  if grep -q "$unexpected" "$MOCK_GEM_CALLS" 2>/dev/null; then
    echo "Expected gem NOT to be called with: $unexpected"
    echo "Actual calls:"
    cat "$MOCK_GEM_CALLS"
    return 1
  fi
}

# Set up mock mvn that logs calls
setup_mock_mvn() {
  export MOCK_MVN_CALLS=$(mktemp)
  mkdir -p "$MOCK_BIN_DIR"
  cat > "$MOCK_BIN_DIR/mvn" << 'MOCKMVN'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_MVN_CALLS"
if [[ "$1" == "deploy:deploy-file" ]]; then
  echo "[INFO] BUILD SUCCESS"
  exit 0
fi
exit 0
MOCKMVN
  chmod +x "$MOCK_BIN_DIR/mvn"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

# Clean up mock mvn
cleanup_mock_mvn() {
  rm -f "$MOCK_MVN_CALLS"
  rm -f "$MOCK_BIN_DIR/mvn"
}

# Assert mvn was called with specific args
assert_mvn_called() {
  local expected="$1"
  if ! grep -q -- "$expected" "$MOCK_MVN_CALLS" 2>/dev/null; then
    echo "Expected mvn to be called with: $expected"
    echo "Actual calls:"
    cat "$MOCK_MVN_CALLS" 2>/dev/null || echo "(none)"
    return 1
  fi
}

# Assert mvn was NOT called with specific args
assert_mvn_not_called() {
  local unexpected="$1"
  if grep -q "$unexpected" "$MOCK_MVN_CALLS" 2>/dev/null; then
    echo "Expected mvn NOT to be called with: $unexpected"
    echo "Actual calls:"
    cat "$MOCK_MVN_CALLS"
    return 1
  fi
}

# Set up mock nuget that logs calls
setup_mock_nuget() {
  export MOCK_NUGET_CALLS=$(mktemp)
  mkdir -p "$MOCK_BIN_DIR"
  # Mock nuget command
  cat > "$MOCK_BIN_DIR/nuget" << 'MOCKNUGET'
#!/usr/bin/env bash
echo "nuget $*" >> "$MOCK_NUGET_CALLS"
if [[ "$1" == "pack" ]]; then
  # Extract package ID from nuspec path
  nuspec_path="$2"
  nuspec_name=$(basename "$nuspec_path" .nuspec)
  # Create a fake .nupkg file in current directory
  nupkg_file="${nuspec_name}.1.0.0.nupkg"
  touch "$nupkg_file"
  echo "Successfully created package '$nupkg_file'"
  exit 0
fi
exit 0
MOCKNUGET
  chmod +x "$MOCK_BIN_DIR/nuget"
  # Mock dotnet command
  cat > "$MOCK_BIN_DIR/dotnet" << 'MOCKDOTNET'
#!/usr/bin/env bash
echo "dotnet $*" >> "$MOCK_NUGET_CALLS"
if [[ "$1" == "nuget" && "$2" == "push" ]]; then
  echo "Pushing package..."
  exit 0
fi
if [[ "$1" == "pack" ]]; then
  # Extract package ID from nuspec path
  nuspec_path="$2"
  nuspec_name=$(basename "$nuspec_path" .nuspec)
  # Create a fake .nupkg file in output directory
  nupkg_file="${nuspec_name}.1.0.0.nupkg"
  touch "$nupkg_file"
  echo "Successfully created package '$nupkg_file'"
  exit 0
fi
exit 0
MOCKDOTNET
  chmod +x "$MOCK_BIN_DIR/dotnet"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

# Clean up mock nuget
cleanup_mock_nuget() {
  rm -f "$MOCK_NUGET_CALLS"
  rm -f "$MOCK_BIN_DIR/nuget"
  rm -f "$MOCK_BIN_DIR/dotnet"
}

# Assert nuget/dotnet was called with specific args
assert_nuget_called() {
  local expected="$1"
  if ! grep -q -- "$expected" "$MOCK_NUGET_CALLS" 2>/dev/null; then
    echo "Expected nuget/dotnet to be called with: $expected"
    echo "Actual calls:"
    cat "$MOCK_NUGET_CALLS" 2>/dev/null || echo "(none)"
    return 1
  fi
}

# Assert nuget/dotnet was NOT called with specific args
assert_nuget_not_called() {
  local unexpected="$1"
  if grep -q "$unexpected" "$MOCK_NUGET_CALLS" 2>/dev/null; then
    echo "Expected nuget/dotnet NOT to be called with: $unexpected"
    echo "Actual calls:"
    cat "$MOCK_NUGET_CALLS"
    return 1
  fi
}
