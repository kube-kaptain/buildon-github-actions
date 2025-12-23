#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# gen-quality-scenarios.bash - Generate repos for testing quality checks
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.bash"

OUTPUT_DIR="${1:-$SCRIPT_DIR/output}"
mkdir -p "$OUTPUT_DIR"

# Scenario: Clean feature branch - should pass all checks
log "Creating: qc-clean (clean feature branch)"
init_repo "$OUTPUT_DIR/qc-clean"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b fix-something --quiet
commit_file "fix.txt" "fixed" "Fix the bug in login validation"
bundle_repo "qc-clean" "$SCRIPT_DIR/../fixtures"

# Scenario: GitHub default branch name
log "Creating: qc-bad-branch-name (testuser-patch-1)"
init_repo "$OUTPUT_DIR/qc-bad-branch-name"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b testuser-patch-1 --quiet
commit_file "fix.txt" "fixed" "Proper commit message here"
bundle_repo "qc-bad-branch-name" "$SCRIPT_DIR/../fixtures"

# Scenario: Branch with slash
log "Creating: qc-branch-with-slash (feature/something)"
init_repo "$OUTPUT_DIR/qc-branch-with-slash"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b feature/something --quiet
commit_file "feature.txt" "feature" "Add the feature"
bundle_repo "qc-branch-with-slash" "$SCRIPT_DIR/../fixtures"

# Scenario: Update filename commit (single file change)
log "Creating: qc-update-commit (Update README.md)"
init_repo "$OUTPUT_DIR/qc-update-commit"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b fix-docs --quiet
echo "# Updated" > README.md
git add README.md
git commit --quiet -m "Update README.md"
bundle_repo "qc-update-commit" "$SCRIPT_DIR/../fixtures"

# Scenario: Create filename commit
log "Creating: qc-create-commit (Create newfile.txt)"
init_repo "$OUTPUT_DIR/qc-create-commit"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b add-file --quiet
commit_file "newfile.txt" "new content" "Create newfile.txt"
bundle_repo "qc-create-commit" "$SCRIPT_DIR/../fixtures"

# Scenario: Delete filename commit
log "Creating: qc-delete-commit (Delete somefile.txt)"
init_repo "$OUTPUT_DIR/qc-delete-commit"
commit_file "README.md" "# Test repo" "Initial commit"
commit_file "somefile.txt" "to delete" "Add file to delete later"
git checkout -b remove-file --quiet
git rm --quiet somefile.txt
git commit --quiet -m "Delete somefile.txt"
bundle_repo "qc-delete-commit" "$SCRIPT_DIR/../fixtures"

# Scenario: Merge commit in branch
log "Creating: qc-merge-commit (has merge commit)"
init_repo "$OUTPUT_DIR/qc-merge-commit"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b side-branch --quiet
commit_file "side.txt" "side" "Side branch change"
git checkout main --quiet
git checkout -b feature-with-merge --quiet
commit_file "feature.txt" "feature" "Feature change"
git merge --no-ff --quiet -m "Merge side-branch" side-branch
bundle_repo "qc-merge-commit" "$SCRIPT_DIR/../fixtures"

# Scenario: Branch not rebased (main has moved ahead)
log "Creating: qc-not-rebased (main moved ahead)"
init_repo "$OUTPUT_DIR/qc-not-rebased"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b old-feature --quiet
commit_file "feature.txt" "feature" "Old feature work"
git checkout main --quiet
commit_file "hotfix.txt" "hotfix" "Hotfix on main"
git checkout old-feature --quiet
bundle_repo "qc-not-rebased" "$SCRIPT_DIR/../fixtures"

# Scenario: Update with extra text (copilot style) - should still flag
log "Creating: qc-update-copilot (Update README.md with extra text)"
init_repo "$OUTPUT_DIR/qc-update-copilot"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b fix-readme --quiet
echo "# Updated content" > README.md
git add README.md
git commit --quiet -m "Update README.md with improved documentation"
bundle_repo "qc-update-copilot" "$SCRIPT_DIR/../fixtures"

# Scenario: Multiple issues - bad branch + bad commit
log "Creating: qc-multiple-issues (bad branch name + Update commit)"
init_repo "$OUTPUT_DIR/qc-multiple-issues"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b testuser-patch-1 --quiet
echo "# Changed" > README.md
git add README.md
git commit --quiet -m "Update README.md"
bundle_repo "qc-multiple-issues" "$SCRIPT_DIR/../fixtures"

# Scenario: Conventional commit format
log "Creating: qc-conventional-commit (feat: style commit)"
init_repo "$OUTPUT_DIR/qc-conventional-commit"
commit_file "README.md" "# Test repo" "Initial commit"
git checkout -b add-feature --quiet
commit_file "feature.txt" "feature" "feat: add new feature"
bundle_repo "qc-conventional-commit" "$SCRIPT_DIR/../fixtures"

log "Done. Repos created in $OUTPUT_DIR"
log "Bundles created in $SCRIPT_DIR/../fixtures"
