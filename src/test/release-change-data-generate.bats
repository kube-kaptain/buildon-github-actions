#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

setup() {
  setup_mock_git
}

teardown() {
  cleanup_test_repo "$TEST_REPO"
  cleanup_mock_git
}

# Create a test repo with Kaptain-annotated tags for release change data testing
# Usage: create_rcd_repo [num_extra_commits]
create_rcd_repo() {
  local extra_commits="${1:-2}"
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  # Create first tag (simulates prior Kaptain release)
  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  # Add commits after the first tag
  for i in $(seq 1 "$extra_commits"); do
    echo "change $i" >> content.txt
    git add content.txt
    git commit --quiet -m "Change $i for next release"
  done

  # Create second tag at HEAD (simulates current release being built)
  git tag -a "1.0.1" -m "Automatic release tag for version 1.0.1 of test-repo by Kaptain build script."

  export VERSION="1.0.1"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.1"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"
}

@test "generates YAML with correct version metadata" {
  create_rcd_repo

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"
  [ -f "$yaml_file" ]

  # Check top-level fields
  local version
  version=$(yq '.change.version' "$yaml_file")
  [ "$version" = "1.0.1" ]

  local project_name
  project_name=$(yq '.change.project-name' "$yaml_file")
  [ "$project_name" = "test-repo" ]

  local tag
  tag=$(yq '.change.tag' "$yaml_file")
  [ "$tag" = "1.0.1" ]
}

@test "finds previous Kaptain tag by annotation message" {
  create_rcd_repo

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  local prev_tag
  prev_tag=$(yq '.change.previous-tag' "$yaml_file")
  [ "$prev_tag" = "1.0.0" ]
}

@test "counts commits correctly" {
  create_rcd_repo 3

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  local count
  count=$(yq '.change.commit-count' "$yaml_file")
  [ "$count" = "3" ]

  local commits_len
  commits_len=$(yq '.change.commits | length' "$yaml_file")
  [ "$commits_len" = "3" ]
}

@test "commits are in oldest-first order" {
  create_rcd_repo 3

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  local first_msg
  first_msg=$(yq '.change.commits[0].message' "$yaml_file")
  [[ "$first_msg" == *"Change 1"* ]]

  local last_msg
  last_msg=$(yq '.change.commits[2].message' "$yaml_file")
  [[ "$last_msg" == *"Change 3"* ]]
}

@test "commit has required fields" {
  create_rcd_repo 1

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  # Check commit structure
  local hash
  hash=$(yq '.change.commits[0].hash' "$yaml_file")
  [ ${#hash} -eq 40 ]

  local abbrev
  abbrev=$(yq '.change.commits[0].abbreviated-hash' "$yaml_file")
  [ ${#abbrev} -ge 7 ]

  local tree
  tree=$(yq '.change.commits[0].tree' "$yaml_file")
  [ ${#tree} -eq 40 ]

  local author_name
  author_name=$(yq '.change.commits[0].author.name' "$yaml_file")
  [ "$author_name" = "Test User" ]

  local author_email
  author_email=$(yq '.change.commits[0].author.email' "$yaml_file")
  [ "$author_email" = "test@example.com" ]

  # author.date should be ISO 8601
  local author_date
  author_date=$(yq '.change.commits[0].author.date' "$yaml_file")
  [[ "$author_date" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T ]]

  # signature status should be present
  local sig_status
  sig_status=$(yq '.change.commits[0].signature.status' "$yaml_file")
  [ -n "$sig_status" ]
}

@test "creates versioned copy in docker context" {
  create_rcd_repo

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local versioned_file="$TEST_REPO/target/release-change-data/docker-context/release-change-data-1.0.1.yaml"
  [ -f "$versioned_file" ]

  # Content should match the plain file
  local plain_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"
  cmp -s "$plain_file" "$versioned_file"
}

@test "outputs RELEASE_CHANGE_DATA_FILE variable" {
  create_rcd_repo

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]
  assert_var_equals "RELEASE_CHANGE_DATA_FILE" "$TEST_REPO/target/release-change-data/release-change-data.yaml"
}

@test "outputs RELEASE_CHANGE_DATA_DOCKER_CONTEXT variable" {
  create_rcd_repo

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]
  assert_var_equals "RELEASE_CHANGE_DATA_DOCKER_CONTEXT" "$TEST_REPO/target/release-change-data/docker-context"
}

@test "handles first release with no prior tags" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  # Add a couple more commits
  echo "second" >> content.txt
  git add content.txt
  git commit --quiet -m "Second commit"

  # Tag HEAD as first release
  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  export VERSION="1.0.0"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.0"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  # previous-tag should be absent
  local prev_tag
  prev_tag=$(yq '.change.previous-tag' "$yaml_file")
  [ "$prev_tag" = "null" ]

  # Should include all commits (initial + second)
  local count
  count=$(yq '.change.commit-count' "$yaml_file")
  [ "$count" = "2" ]
}

@test "handles rebuild with zero commits" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  # Create first tag
  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  # Create second tag on SAME commit (rebuild scenario)
  git tag -a "1.0.1" -m "Automatic release tag for version 1.0.1 of test-repo by Kaptain build script."

  export VERSION="1.0.1"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.1"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  local count
  count=$(yq '.change.commit-count' "$yaml_file")
  [ "$count" = "0" ]

  local commits_len
  commits_len=$(yq '.change.commits | length' "$yaml_file")
  [ "$commits_len" = "0" ]
}

@test "ignores non-Kaptain tags (manual seed tags)" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  # Create a manual seed tag (different annotation message)
  git tag -a "0.9.0" -m "Manual seed tag for testing"

  # Add commits
  echo "change1" >> content.txt
  git add content.txt
  git commit --quiet -m "Change 1"

  # Create Kaptain tag
  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  export VERSION="1.0.0"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.0"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  # previous-tag should be absent (seed tag filtered out)
  local prev_tag
  prev_tag=$(yq '.change.previous-tag' "$yaml_file")
  [ "$prev_tag" = "null" ]

  # Should include ALL commits since there's no valid previous Kaptain tag
  local count
  count=$(yq '.change.commit-count' "$yaml_file")
  [ "$count" = "2" ]  # initial + Change 1
}

@test "ignores lightweight tags" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  # Create a lightweight tag (not annotated)
  git tag "0.5.0"

  # Add commits
  echo "change1" >> content.txt
  git add content.txt
  git commit --quiet -m "Change 1"

  # Create Kaptain tag
  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  export VERSION="1.0.0"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.0"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  # previous-tag should be absent (lightweight tag filtered out)
  local prev_tag
  prev_tag=$(yq '.change.previous-tag' "$yaml_file")
  [ "$prev_tag" = "null" ]
}

@test "handles merge commits with multiple parents" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  # Create first tag
  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  # Create a feature branch and merge it
  local default_branch
  default_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout -b feature --quiet
  echo "feature work" >> feature.txt
  git add feature.txt
  git commit --quiet -m "Feature work"

  git checkout "$default_branch" --quiet
  git merge --no-ff --quiet -m "Merge feature branch" feature

  # Create next tag
  git tag -a "1.0.1" -m "Automatic release tag for version 1.0.1 of test-repo by Kaptain build script."

  export VERSION="1.0.1"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.1"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  # Merge commit should have 2 parents
  local merge_parents_len
  merge_parents_len=$(yq '.change.commits[-1].parents | length' "$yaml_file")
  [ "$merge_parents_len" = "2" ]
}

@test "git-sha1 matches HEAD" {
  create_rcd_repo

  local head_sha
  head_sha=$(git rev-parse HEAD)

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  local yaml_sha
  yaml_sha=$(yq '.change.git-sha1' "$yaml_file")
  [ "$yaml_sha" = "$head_sha" ]
}

@test "generated timestamp is ISO 8601 UTC" {
  create_rcd_repo

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  local generated
  generated=$(yq '.change.generated' "$yaml_file")
  [[ "$generated" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\+00:00$ ]]
}

@test "fails when VERSION not set" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.0"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"
  unset VERSION

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -ne 0 ]
  assert_output_contains "VERSION"
}

@test "fails when PROJECT_NAME not set" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"
  export VERSION="1.0.0"
  export GIT_TAG="1.0.0"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"
  unset PROJECT_NAME

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -ne 0 ]
  assert_output_contains "PROJECT_NAME"
}

@test "fails when GIT_TAG not set" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"
  export VERSION="1.0.0"
  export PROJECT_NAME="test-repo"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"
  unset GIT_TAG

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -ne 0 ]
  assert_output_contains "GIT_TAG"
}

@test "unsigned commits have signature status No and verification N" {
  create_rcd_repo 1

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  local sig_status
  sig_status=$(yq '.change.commits[0].signature.status' "$yaml_file")
  [ "$sig_status" = "No" ]

  local sig_verification
  sig_verification=$(yq '.change.commits[0].signature.verification' "$yaml_file")
  [ "$sig_verification" = "N" ]
}

@test "previous-git-sha1 matches previous tag commit" {
  create_rcd_repo

  local prev_sha
  prev_sha=$(git rev-parse "1.0.0^{commit}")

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  local yaml_prev_sha
  yaml_prev_sha=$(yq '.change.previous-git-sha1' "$yaml_file")
  [ "$yaml_prev_sha" = "$prev_sha" ]
}

@test "picks closest Kaptain tag when multiple exist" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  # Create first Kaptain tag (far away)
  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  # Add commits
  echo "change1" >> content.txt
  git add content.txt
  git commit --quiet -m "Change 1"

  # Create second Kaptain tag (closer)
  git tag -a "1.0.1" -m "Automatic release tag for version 1.0.1 of test-repo by Kaptain build script."

  # Add more commits
  echo "change2" >> content.txt
  git add content.txt
  git commit --quiet -m "Change 2"

  # Create current tag
  git tag -a "1.0.2" -m "Automatic release tag for version 1.0.2 of test-repo by Kaptain build script."

  export VERSION="1.0.2"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.2"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  # Should pick 1.0.1 (closest), not 1.0.0
  local prev_tag
  prev_tag=$(yq '.change.previous-tag' "$yaml_file")
  [ "$prev_tag" = "1.0.1" ]

  # Should only have 1 commit (between 1.0.1 and HEAD)
  local count
  count=$(yq '.change.commit-count' "$yaml_file")
  [ "$count" = "1" ]
}

# === Change Source Detection Tests ===

# Helper: create a repo with a prior tag, then make a commit with a specific message as HEAD
create_rcd_repo_with_head_message() {
  local message="${1}"
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  echo "change" >> content.txt
  git add content.txt
  git commit --quiet -m "${message}"

  git tag -a "1.0.1" -m "Automatic release tag for version 1.0.1 of test-repo by Kaptain build script."

  export VERSION="1.0.1"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.1"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"
}

@test "detects GitHub PR merge as change source" {
  create_rcd_repo_with_head_message "Merge pull request #42 from myorg/feature-branch"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-type' "$yaml_file")" = "github-pull-request" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "PR #42 from myorg/feature-branch" ]
  [ "$(yq '.change.change-source-branch' "$yaml_file")" = "feature-branch" ]
}

@test "detects GitHub squash merge as change source" {
  create_rcd_repo_with_head_message "Add new feature (#99)"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-type' "$yaml_file")" = "github-pull-request" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "PR #99" ]
}

@test "detects Azure DevOps PR as change source" {
  create_rcd_repo_with_head_message "Merged PR 456: Add authentication module"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-type' "$yaml_file")" = "azure-pull-request" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "PR 456: Add authentication module" ]
}

@test "detects Bitbucket PR as change source" {
  create_rcd_repo_with_head_message "Merged in feature-xyz (pull request #78)"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-type' "$yaml_file")" = "bitbucket-pull-request" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "PR #78 from feature-xyz" ]
  [ "$(yq '.change.change-source-branch' "$yaml_file")" = "feature-xyz" ]
}

@test "detects git branch merge as change source" {
  create_rcd_repo_with_head_message "Merge branch 'feature-abc' into 'main'"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-type' "$yaml_file")" = "git-branch-merge" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "feature-abc into main" ]
  [ "$(yq '.change.change-source-branch' "$yaml_file")" = "feature-abc" ]
}

@test "detects git branch merge without target as change source" {
  create_rcd_repo_with_head_message "Merge branch 'hotfix-123'"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-type' "$yaml_file")" = "git-branch-merge" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "hotfix-123" ]
  [ "$(yq '.change.change-source-branch' "$yaml_file")" = "hotfix-123" ]
}

@test "detects direct push as change source" {
  create_rcd_repo_with_head_message "Fix a bug directly on main"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-type' "$yaml_file")" = "direct" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "null" ]
}

@test "detects GitLab MR as change source" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  echo "change" >> content.txt
  git add content.txt
  # GitLab merge commits have branch in subject and MR reference in body
  git commit --quiet -m "Merge branch 'feature-gl' into 'main'" -m "See merge request mygroup/myproject!321"

  git tag -a "1.0.1" -m "Automatic release tag for version 1.0.1 of test-repo by Kaptain build script."

  export VERSION="1.0.1"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.1"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-type' "$yaml_file")" = "gitlab-merge-request" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "MR mygroup/myproject!321" ]
  [ "$(yq '.change.change-source-branch' "$yaml_file")" = "feature-gl" ]
}

# === Change Source Note Reading Tests ===

@test "reads change source note from HEAD" {
  create_rcd_repo_with_head_message "Fix something"

  # Write a note directly (simulating what change-source-note-write does on PR build)
  git notes --ref=kaptain-change-source add -m "merge-candidate-branch: feature-from-note
merge-candidate-creator: noteuser" HEAD

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-note-found' "$yaml_file")" = "true" ]
  # Note branch overrides pattern-matched branch
  [ "$(yq '.change.change-source-branch' "$yaml_file")" = "feature-from-note" ]
  [ "$(yq '.change.change-source-merge-candidate-creator' "$yaml_file")" = "noteuser" ]
}

@test "reads change source note from second parent of merge commit" {
  TEST_REPO=$(create_test_repo)
  cd "$TEST_REPO"

  git tag -a "1.0.0" -m "Automatic release tag for version 1.0.0 of test-repo by Kaptain build script."

  # Create a feature branch with a note on its tip
  local default_branch
  default_branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout -b feature-noted --quiet
  echo "feature work" >> feature.txt
  git add feature.txt
  git commit --quiet -m "Feature work"

  # Write note to feature branch tip (simulating PR build)
  git notes --ref=kaptain-change-source add -m "merge-candidate-branch: feature-noted
merge-candidate-creator: featuredev" HEAD

  # Merge back to default branch (creates merge commit where HEAD^2 = feature tip)
  git checkout "$default_branch" --quiet
  git merge --no-ff --quiet -m "Merge pull request #55 from org/feature-noted" feature-noted

  git tag -a "1.0.1" -m "Automatic release tag for version 1.0.1 of test-repo by Kaptain build script."

  export VERSION="1.0.1"
  export PROJECT_NAME="test-repo"
  export GIT_TAG="1.0.1"
  export OUTPUT_SUB_PATH="$TEST_REPO/target"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-note-found' "$yaml_file")" = "true" ]
  # Note branch overrides pattern-matched branch
  [ "$(yq '.change.change-source-branch' "$yaml_file")" = "feature-noted" ]
  [ "$(yq '.change.change-source-merge-candidate-creator' "$yaml_file")" = "featuredev" ]
  # Pattern matching still detects the type
  [ "$(yq '.change.change-source-type' "$yaml_file")" = "github-pull-request" ]
}

@test "change-source-note-found is false when no note exists" {
  create_rcd_repo_with_head_message "Direct commit"

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  [ "$(yq '.change.change-source-note-found' "$yaml_file")" = "false" ]
  [ "$(yq '.change.change-source-merge-candidate-creator' "$yaml_file")" = "null" ]
}

@test "pattern matching still runs when note is present" {
  create_rcd_repo_with_head_message "Merged PR 789: Add new endpoint"

  # Add a note too
  git notes --ref=kaptain-change-source add -m "merge-candidate-branch: feature-endpoint" HEAD

  run "$SCRIPTS_DIR/release-change-data-generate"
  [ "$status" -eq 0 ]

  local yaml_file="$TEST_REPO/target/release-change-data/release-change-data.yaml"

  # Pattern matching detects Azure PR
  [ "$(yq '.change.change-source-type' "$yaml_file")" = "azure-pull-request" ]
  [ "$(yq '.change.change-source-ref-data' "$yaml_file")" = "PR 789: Add new endpoint" ]
  # Note provides the branch (Azure pattern can't extract it)
  [ "$(yq '.change.change-source-branch' "$yaml_file")" = "feature-endpoint" ]
  [ "$(yq '.change.change-source-note-found' "$yaml_file")" = "true" ]
}
