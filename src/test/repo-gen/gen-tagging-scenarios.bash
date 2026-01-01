#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# gen-tagging-scenarios.bash - Generate repos for testing tag generation
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.bash"

OUTPUT_DIR="${1:-$SCRIPT_DIR/output}"
mkdir -p "$OUTPUT_DIR"

# Scenario: No tags - should start at 1.0.0
log "Creating: tag-none (no existing tags)"
init_repo "$OUTPUT_DIR/tag-none"
commit_file "README.md" "# Test repo" "Initial commit"
commit_file "file.txt" "content" "Add file"
bundle_repo "tag-none" "$SCRIPT_DIR/../fixtures"

# Scenario: Has 1.0.0 - should increment to 1.0.1
log "Creating: tag-semver3 (has 1.0.0)"
init_repo "$OUTPUT_DIR/tag-semver3"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.0.0" "First release"
commit_file "file.txt" "content" "Add file after tag"
bundle_repo "tag-semver3" "$SCRIPT_DIR/../fixtures"

# Scenario: Has 7 (single-part) - should increment to 8
log "Creating: tag-semver1 (has 7)"
init_repo "$OUTPUT_DIR/tag-semver1"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "7" "Single-part version"
commit_file "file.txt" "content" "Add file after tag"
bundle_repo "tag-semver1" "$SCRIPT_DIR/../fixtures"

# Scenario: Has 41 (two-digit single-part) - should increment to 42
log "Creating: tag-semver1-twodigit (has 41)"
init_repo "$OUTPUT_DIR/tag-semver1-twodigit"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "41" "Two-digit single-part version"
commit_file "file.txt" "content" "Add file after tag"
bundle_repo "tag-semver1-twodigit" "$SCRIPT_DIR/../fixtures"

# Scenario: Has 1234567890 (10-digit single-part) - should increment to 1234567891
log "Creating: tag-semver1-tendigit (has 1234567890)"
init_repo "$OUTPUT_DIR/tag-semver1-tendigit"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1234567890" "Ten-digit single-part version"
commit_file "file.txt" "content" "Add file after tag"
bundle_repo "tag-semver1-tendigit" "$SCRIPT_DIR/../fixtures"

# Scenario: Has 1.2 (two-part) - should increment to 1.3
log "Creating: tag-semver2 (has 1.2)"
init_repo "$OUTPUT_DIR/tag-semver2"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.2" "Two-part version"
commit_file "file.txt" "content" "Add file after tag"
bundle_repo "tag-semver2" "$SCRIPT_DIR/../fixtures"

# Scenario: Has 1.2.3.4 (four-part) - should increment to 1.2.3.5
log "Creating: tag-semver4 (has 1.2.3.4)"
init_repo "$OUTPUT_DIR/tag-semver4"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.2.3.4" "Four-part version"
commit_file "file.txt" "content" "Add file after tag"
bundle_repo "tag-semver4" "$SCRIPT_DIR/../fixtures"

# Scenario: Has 1.2.3.4.5.6.7.8.9.0 (ten-part) - should increment to 1.2.3.4.5.6.7.8.9.1
log "Creating: tag-semver10 (has 1.2.3.4.5.6.7.8.9.0)"
init_repo "$OUTPUT_DIR/tag-semver10"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.2.3.4.5.6.7.8.9.0" "Ten-part version"
commit_file "file.txt" "content" "Add file after tag"
bundle_repo "tag-semver10" "$SCRIPT_DIR/../fixtures"

# Scenario: Has v-prefixed tag - should be ignored (only X.Y.Z format matched)
log "Creating: tag-vprefixed (has v1.0.0)"
init_repo "$OUTPUT_DIR/tag-vprefixed"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "v1.0.0" "V-prefixed release"
commit_file "file.txt" "content" "Add file after tag"
bundle_repo "tag-vprefixed" "$SCRIPT_DIR/../fixtures"

# Scenario: Multiple tags - should find latest
log "Creating: tag-multiple (has 1.0.0, 1.0.1, 1.0.2)"
init_repo "$OUTPUT_DIR/tag-multiple"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.0.0" "First"
commit_file "a.txt" "a" "Commit A"
create_tag "1.0.1" "Second"
commit_file "b.txt" "b" "Commit B"
create_tag "1.0.2" "Third"
commit_file "c.txt" "c" "Commit C after latest tag"
bundle_repo "tag-multiple" "$SCRIPT_DIR/../fixtures"

# Scenario: Feature branch off main
log "Creating: tag-feature-branch (feature branch with commits)"
init_repo "$OUTPUT_DIR/tag-feature-branch"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.0.0" "Release on main"
git checkout -b feature-test --quiet
commit_file "feature.txt" "feature" "Add feature"
bundle_repo "tag-feature-branch" "$SCRIPT_DIR/../fixtures"

# Scenario: Higher tags exist on isolated branch (Tag.md example)
# main has 2.0 seed, but another branch has 2.30-2.32
# Expected: 2.33 (not 2.1)
log "Creating: tag-higher-on-other-branch (isolated branch has higher tags in series)"
init_repo "$OUTPUT_DIR/tag-higher-on-other-branch"
commit_file "README.md" "# Test repo" "Initial commit"
# Create orphan branch with higher tags in 2.X series
git checkout --orphan legacy-branch --quiet
git rm -rf . --quiet 2>/dev/null || true
commit_file "legacy.txt" "legacy" "Legacy branch start"
create_tag "2.30" "Legacy release 1"
commit_file "a.txt" "a" "Commit A"
create_tag "2.31" "Legacy release 2"
commit_file "b.txt" "b" "Commit B"
create_tag "2.32" "Legacy release 3"
# Back to main with lower seed
git checkout main --quiet
create_tag "2.0" "Seed on main"
commit_file "new.txt" "new" "New work on main"
bundle_repo "tag-higher-on-other-branch" "$SCRIPT_DIR/../fixtures"

# Scenario: Patch branch (main-1.2.4.X pattern from Tag.md)
# main has 1.0.0 through 1.2.4, patch branch has 1.2.4.0-1.2.4.3
# On patch branch, expected: 1.2.4.4
log "Creating: tag-patch-branch (patch branch with 4-part versions)"
init_repo "$OUTPUT_DIR/tag-patch-branch"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.0.0" "Initial release"
commit_file "a.txt" "a" "Minor work"
create_tag "1.2.4" "Last 3-part version"
# Create patch branch
git checkout -b main-1.2.4.X --quiet
commit_file "patch1.txt" "patch1" "Patch work 1"
create_tag "1.2.4.0" "First patch"
commit_file "patch2.txt" "patch2" "Patch work 2"
create_tag "1.2.4.1" "Second patch"
commit_file "patch3.txt" "patch3" "Patch work 3"
create_tag "1.2.4.2" "Third patch"
commit_file "patch4.txt" "patch4" "Patch work 4"
create_tag "1.2.4.3" "Fourth patch"
commit_file "patch5.txt" "patch5" "New patch work"
bundle_repo "tag-patch-branch" "$SCRIPT_DIR/../fixtures"

# Scenario: Main has moved ahead but patch branch should stay in its series
# main has 1.3.0, but patch branch still has 1.2.4.X
log "Creating: tag-patch-ignores-main (patch branch ignores main's newer tags)"
init_repo "$OUTPUT_DIR/tag-patch-ignores-main"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.2.4" "Before patch split"
# Create patch branch first
git checkout -b main-1.2.4.X --quiet
commit_file "patch.txt" "patch" "Patch work"
create_tag "1.2.4.0" "First patch release"
# Go back to main and advance
git checkout main --quiet
commit_file "new.txt" "new" "New feature"
create_tag "1.3.0" "Minor bump on main"
commit_file "more.txt" "more" "More work on main"
# Back to patch branch
git checkout main-1.2.4.X --quiet
commit_file "patch2.txt" "patch2" "More patch work"
bundle_repo "tag-patch-ignores-main" "$SCRIPT_DIR/../fixtures"

# Scenario: Double-digit version numbers (real world - systems hit 1200+ releases)
# 1.4 vs 1.40 - numeric sort must handle correctly
log "Creating: tag-double-digits (1.4 vs 1.40 sorting)"
init_repo "$OUTPUT_DIR/tag-double-digits"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.4" "Early version"
commit_file "a.txt" "a" "Commit A"
create_tag "1.5" "Version 5"
commit_file "b.txt" "b" "Commit B"
create_tag "1.40" "Version 40"
commit_file "c.txt" "c" "Commit C"
create_tag "1.41" "Version 41"
commit_file "d.txt" "d" "New work after 1.41"
bundle_repo "tag-double-digits" "$SCRIPT_DIR/../fixtures"

# Scenario: Ignore non-numeric tags (rc, beta, etc)
log "Creating: tag-with-suffixes (has 1.2.3-rc1, 1.2.3-beta)"
init_repo "$OUTPUT_DIR/tag-with-suffixes"
commit_file "README.md" "# Test repo" "Initial commit"
create_tag "1.2.3" "Release"
commit_file "a.txt" "a" "Commit A"
create_tag "1.2.4-rc1" "Release candidate"
commit_file "b.txt" "b" "Commit B"
create_tag "1.2.4-beta" "Beta"
commit_file "c.txt" "c" "Commit C"
# Should get 1.2.4, ignoring the -rc1 and -beta tags
bundle_repo "tag-with-suffixes" "$SCRIPT_DIR/../fixtures"

# Scenario: Multiple annotated tags on same commit - should use newest by date
log "Creating: tag-same-commit-multiple (two tags on same commit, different dates)"
init_repo "$OUTPUT_DIR/tag-same-commit-multiple"
commit_file "README.md" "# Test repo" "Initial commit"
commit_file "a.txt" "a" "Some work"
# First tag (older) - higher version number
git tag -m "Old tag" "2.3.4" HEAD
sleep 2
# Second tag (newer) - lower version number but should be picked
git tag -m "New tag" "1.2.3" HEAD
commit_file "b.txt" "b" "More work after tags"
bundle_repo "tag-same-commit-multiple" "$SCRIPT_DIR/../fixtures"

# Scenario: Same distance after merge - newer tag should win even if lower version
log "Creating: tag-merge-same-distance (merged branches, same distance, different tag dates)"
init_repo "$OUTPUT_DIR/tag-merge-same-distance"
commit_file "README.md" "# Test repo" "Initial commit"
# Branch A with tag 2.3.4 (older tag, higher version)
git checkout -b branch-a --quiet
commit_file "a.txt" "a" "Work on A"
git tag -m "Tag on A - older" "2.3.4" HEAD
# Branch B with newer tag 1.2.3 (lower version but newer date)
git checkout main --quiet
git checkout -b branch-b --quiet
sleep 2
commit_file "b.txt" "b" "Work on B"
git tag -m "Tag on B - newer" "1.2.3" HEAD
# Merge both into main
git checkout main --quiet
git merge --no-ff --quiet -m "Merge A" branch-a
git merge --no-ff --quiet -m "Merge B" branch-b
bundle_repo "tag-merge-same-distance" "$SCRIPT_DIR/../fixtures"

# Scenario: Linear history with backfilled tag on older commit
# Older commit gets tagged later with higher version - should use closer tag
# A (tag 2.0.0, created 2nd) → B (tag 1.0.0, created 1st) → C (HEAD)
# Expected: 1.0.1 (B is closer, distance 1 vs distance 2)
log "Creating: tag-backfill-order (older commit tagged later with higher version)"
init_repo "$OUTPUT_DIR/tag-backfill-order"
commit_file "README.md" "# Test repo" "Initial commit"
# This is commit A - will be tagged SECOND with higher version
commit_file "a.txt" "a" "Commit A"
# This is commit B - will be tagged FIRST with lower version
commit_file "b.txt" "b" "Commit B"
# Tag B first (lower version, older timestamp, but closer to HEAD)
create_tag "1.0.0" "First release on B"
# Now go back and tag A (higher version, newer timestamp, but farther from HEAD)
sleep 1
git tag -m "Backfill tag on A" "2.0.0" HEAD~1
# Add commit C (HEAD)
commit_file "c.txt" "c" "Commit C"
bundle_repo "tag-backfill-order" "$SCRIPT_DIR/../fixtures"

log "Done. Repos created in $OUTPUT_DIR"
log "Bundles created in $SCRIPT_DIR/../fixtures"
