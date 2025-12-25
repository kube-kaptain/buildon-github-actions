#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for substitute-shell-style-var (dumb find-replace script)

load helpers

setup() {
  export INPUT_DIR=$(mktemp -d)
  export OUTPUT_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$INPUT_DIR"
  rm -rf "$OUTPUT_DIR"
}

# Create a test file
create_input_file() {
  local filename="$1"
  local content="$2"
  mkdir -p "$(dirname "$INPUT_DIR/$filename")"
  echo "$content" > "$INPUT_DIR/$filename"
}

@test "substitutes exact variable name" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}'
  export VAR_NAME="PROJECT_NAME"
  export VAR_VALUE="my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "substitutes kebab-case variable name" {
  create_input_file "test.yaml" 'name: ${project-name}'
  export VAR_NAME="project-name"
  export VAR_VALUE="my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "leaves other variables untouched" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}
version: ${VERSION}'
  export VAR_NAME="PROJECT_NAME"
  export VAR_VALUE="my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -eq 0 ]

  grep -q "name: my-app" "$OUTPUT_DIR/test.yaml"
  grep -q 'version: ${VERSION}' "$OUTPUT_DIR/test.yaml"
}

@test "handles values with slashes" {
  create_input_file "test.yaml" 'image: ${DOCKER_IMAGE_NAME}'
  export VAR_NAME="DOCKER_IMAGE_NAME"
  export VAR_VALUE="org/my-image"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "image: org/my-image" ]
}

@test "processes directory recursively" {
  create_input_file "deployment.yaml" 'name: ${PROJECT_NAME}'
  create_input_file "subdir/service.yaml" 'name: ${PROJECT_NAME}-svc'
  export VAR_NAME="PROJECT_NAME"
  export VAR_VALUE="my-app"
  export INPUT_PATH="$INPUT_DIR"
  export OUTPUT_PATH="$OUTPUT_DIR"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -eq 0 ]

  grep -q "name: my-app" "$OUTPUT_DIR/deployment.yaml"
  grep -q "name: my-app-svc" "$OUTPUT_DIR/subdir/service.yaml"
}

@test "outputs substitution count" {
  create_input_file "test.yaml" 'a: ${PROJECT_NAME}
b: ${PROJECT_NAME}'
  export VAR_NAME="PROJECT_NAME"
  export VAR_VALUE="my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "fails when VAR_NAME not set" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}'
  export VAR_VALUE="my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"
  unset VAR_NAME

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -ne 0 ]
  assert_output_contains "VAR_NAME"
}

@test "fails when VAR_VALUE not set" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}'
  export VAR_NAME="PROJECT_NAME"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"
  unset VAR_VALUE

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -ne 0 ]
  assert_output_contains "VAR_VALUE"
}

@test "fails when INPUT_PATH not found" {
  export VAR_NAME="PROJECT_NAME"
  export VAR_VALUE="my-app"
  export INPUT_PATH="/nonexistent/path"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -ne 0 ]
  assert_output_contains "not found"
}

@test "fails when INPUT_PATH equals OUTPUT_PATH" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}'
  export VAR_NAME="PROJECT_NAME"
  export VAR_VALUE="my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$INPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -ne 0 ]
  assert_output_contains "must differ"
}

@test "does not substitute partial matches" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME_EXTRA}'
  export VAR_NAME="PROJECT_NAME"
  export VAR_VALUE="my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -eq 0 ]

  # Should NOT be substituted - different variable name
  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = 'name: ${PROJECT_NAME_EXTRA}' ]
}

@test "substitutes multiple occurrences in same file" {
  create_input_file "test.yaml" 'name: ${version}
tag: ${version}
label: ${version}'
  export VAR_NAME="version"
  export VAR_VALUE="1.2.3"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$SCRIPTS_DIR/substitute-shell-style-var"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]

  grep -q "name: 1.2.3" "$OUTPUT_DIR/test.yaml"
  grep -q "tag: 1.2.3" "$OUTPUT_DIR/test.yaml"
  grep -q "label: 1.2.3" "$OUTPUT_DIR/test.yaml"
}
