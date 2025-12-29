#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for substitute-shell-style-token (new file-based API)

load helpers

setup() {
  export TOKENS_DIR=$(mktemp -d)
  export TARGET_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TOKENS_DIR"
  rm -rf "$TARGET_DIR"
}

# Create a token file
create_token() {
  local name="$1"
  local value="$2"
  mkdir -p "$(dirname "$TOKENS_DIR/$name")"
  printf '%s' "$value" > "$TOKENS_DIR/$name"
}

# Create a target file
create_target() {
  local filename="$1"
  local content="$2"
  mkdir -p "$(dirname "$TARGET_DIR/$filename")"
  printf '%s' "$content" > "$TARGET_DIR/$filename"
}

@test "substitutes exact variable name" {
  create_token "ProjectName" "my-app"
  create_target "test.yaml" 'name: ${ProjectName}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "ProjectName" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "substitutes kebab-case token name" {
  create_token "project-name" "my-app"
  create_target "test.yaml" 'name: ${project-name}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "project-name" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "leaves other variables untouched" {
  create_token "ProjectName" "my-app"
  create_target "test.yaml" 'name: ${ProjectName}
version: ${Version}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "ProjectName" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  grep -q "name: my-app" "$TARGET_DIR/test.yaml"
  grep -q 'version: ${Version}' "$TARGET_DIR/test.yaml"
}

@test "handles values with slashes" {
  create_token "DockerImageName" "org/my-image"
  create_target "test.yaml" 'image: ${DockerImageName}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "DockerImageName" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "image: org/my-image" ]
}

@test "handles values with commas" {
  create_token "Tags" "tag1,tag2,tag3"
  create_target "test.yaml" 'tags: ${Tags}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "Tags" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "tags: tag1,tag2,tag3" ]
}

@test "processes directory recursively" {
  create_token "ProjectName" "my-app"
  create_target "deployment.yaml" 'name: ${ProjectName}'
  create_target "subdir/service.yaml" 'name: ${ProjectName}-svc'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "ProjectName" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  grep -q "name: my-app" "$TARGET_DIR/deployment.yaml"
  grep -q "name: my-app-svc" "$TARGET_DIR/subdir/service.yaml"
}

@test "fails when token file not found" {
  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "nonexistent" "$TARGET_DIR"
  [ "$status" -ne 0 ]
  assert_output_contains "not found"
}

@test "fails when target directory not found" {
  create_token "ProjectName" "my-app"

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "ProjectName" "/nonexistent/path"
  [ "$status" -ne 0 ]
  assert_output_contains "not found"
}

@test "does not substitute partial matches" {
  create_token "ProjectName" "my-app"
  create_target "test.yaml" 'name: ${ProjectNameExtra}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "ProjectName" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = 'name: ${ProjectNameExtra}' ]
}

@test "substitutes multiple occurrences in same file" {
  create_token "Version" "1.2.3"
  create_target "test.yaml" 'name: ${Version}
tag: ${Version}
label: ${Version}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "Version" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  grep -q "name: 1.2.3" "$TARGET_DIR/test.yaml"
  grep -q "tag: 1.2.3" "$TARGET_DIR/test.yaml"
  grep -q "label: 1.2.3" "$TARGET_DIR/test.yaml"
}

@test "handles nested token path" {
  mkdir -p "$TOKENS_DIR/category"
  printf '%s' "nested-value" > "$TOKENS_DIR/category/sub-var"
  create_target "test.yaml" 'value: ${category/sub-var}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "category/sub-var" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "value: nested-value" ]
}

@test "self-referential token does not cause infinite loop" {
  create_token "ProjectName" '${ProjectName}'
  create_target "test.yaml" 'name: ${ProjectName}'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "ProjectName" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = 'name: ${ProjectName}' ]
}

@test "empty token file substitutes empty string" {
  printf '' > "$TOKENS_DIR/EmptyVar"
  create_target "test.yaml" 'prefix-${EmptyVar}-suffix'

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "EmptyVar" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "prefix--suffix" ]
}

@test "preserves file without trailing newline" {
  create_token "Var" "value"
  printf 'no newline: ${Var}' > "$TARGET_DIR/test.txt"

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "Var" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  # File should not have trailing newline
  result=$(cat "$TARGET_DIR/test.txt")
  [ "$result" = "no newline: value" ]

  # Verify no trailing newline was added
  # "no newline: value" = 17 characters
  local size=$(wc -c < "$TARGET_DIR/test.txt" | tr -d ' ')
  [ "$size" -eq 17 ]
}

@test "preserves file with trailing newline" {
  create_token "Var" "value"
  printf 'with newline: ${Var}\n' > "$TARGET_DIR/test.txt"

  cd "$TOKENS_DIR"
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "Var" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  # File should have trailing newline preserved
  local content
  content=$(cat "$TARGET_DIR/test.txt" && echo x)
  content="${content%x}"
  [ "$content" = $'with newline: value\n' ]
}

@test "strips trailing newline from single-line token by default" {
  printf 'my-value\n' > "$TOKENS_DIR/SingleLine"
  create_target "test.yaml" 'key: ${SingleLine}'

  cd "$TOKENS_DIR"
  CONFIG_VALUE_TRAILING_NEWLINE="strip-for-single-line" \
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "SingleLine" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "key: my-value" ]
}

@test "preserves trailing newlines in multi-line token" {
  printf 'line1\nline2\n' > "$TOKENS_DIR/MultiLine"
  create_target "test.yaml" 'data: |
  ${MultiLine}done'

  cd "$TOKENS_DIR"
  CONFIG_VALUE_TRAILING_NEWLINE="strip-for-single-line" \
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "MultiLine" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  # Multi-line content should preserve trailing newline
  grep -q 'line2' "$TARGET_DIR/test.yaml"
}

@test "preserve-all mode keeps trailing newline on single-line" {
  printf 'my-value\n' > "$TOKENS_DIR/SingleLine"
  create_target "test.yaml" 'key: ${SingleLine}suffix'

  cd "$TOKENS_DIR"
  CONFIG_VALUE_TRAILING_NEWLINE="preserve-all" \
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "SingleLine" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  # The newline should push suffix to next line
  # Content should be: "key: my-value\nsuffix"
  local content
  content=$(cat "$TARGET_DIR/test.yaml")
  [[ "$content" == *$'\n'* ]]  # Contains newline
  [[ "$content" == "key: my-value"$'\n'"suffix" ]]
}

@test "always-strip-one-newline mode on single newline" {
  printf 'my-value\n' > "$TOKENS_DIR/SingleLine"
  create_target "test.yaml" 'key: ${SingleLine}'

  cd "$TOKENS_DIR"
  CONFIG_VALUE_TRAILING_NEWLINE="always-strip-one-newline" \
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "SingleLine" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  result=$(cat "$TARGET_DIR/test.yaml")
  [ "$result" = "key: my-value" ]
}

@test "always-strip-one-newline mode on double newline" {
  printf 'my-value\n\n' > "$TOKENS_DIR/DoubleNewline"
  create_target "test.yaml" 'key: ${DoubleNewline}suffix'

  cd "$TOKENS_DIR"
  CONFIG_VALUE_TRAILING_NEWLINE="always-strip-one-newline" \
  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-token" "DoubleNewline" "$TARGET_DIR"
  [ "$status" -eq 0 ]

  # Should strip one newline, leaving one
  # Content should be: "key: my-value\nsuffix"
  local content
  content=$(cat "$TARGET_DIR/test.yaml")
  [[ "$content" == *$'\n'* ]]  # Contains newline
  [[ "$content" == "key: my-value"$'\n'"suffix" ]]
}
