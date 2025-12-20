# helpers.bash - Shared test helper functions

# Get project root
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Path to scripts and fixtures
SCRIPTS_DIR="$PROJECT_ROOT/src/scripts"
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
