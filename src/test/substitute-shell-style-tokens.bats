#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Kaptain contributors (Fred Cooke)
#
# Tests for substitute-shell-style-tokens (dumb multi-token script)

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

@test "substitutes single variable" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}'
  export VARIABLES="PROJECT_NAME=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "substitutes multiple variables" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}
version: ${VERSION}'
  export VARIABLES="PROJECT_NAME=my-app,VERSION=1.2.3"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  grep -q "name: my-app" "$OUTPUT_DIR/test.yaml"
  grep -q "version: 1.2.3" "$OUTPUT_DIR/test.yaml"
}

@test "substitutes kebab-case variable names" {
  create_input_file "test.yaml" 'name: ${project-name}'
  export VARIABLES="project-name=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "substitutes lower_snake variable names" {
  create_input_file "test.yaml" 'name: ${project_name}'
  export VARIABLES="project_name=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "substitutes camelCase variable names" {
  create_input_file "test.yaml" 'name: ${projectName}'
  export VARIABLES="projectName=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "substitutes PascalCase variable names" {
  create_input_file "test.yaml" 'name: ${ProjectName}'
  export VARIABLES="ProjectName=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "name: my-app" ]
}

@test "leaves unknown variables untouched" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}
registry: ${DOCKER_REGISTRY}'
  export VARIABLES="PROJECT_NAME=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  grep -q "name: my-app" "$OUTPUT_DIR/test.yaml"
  grep -q 'registry: ${DOCKER_REGISTRY}' "$OUTPUT_DIR/test.yaml"
}

@test "handles values with slashes" {
  create_input_file "test.yaml" 'image: ${DOCKER_IMAGE_NAME}'
  export VARIABLES="DOCKER_IMAGE_NAME=org/my-image"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = "image: org/my-image" ]
}

@test "processes directory recursively" {
  create_input_file "deployment.yaml" 'name: ${PROJECT_NAME}'
  create_input_file "subdir/service.yaml" 'name: ${PROJECT_NAME}-svc'
  export VARIABLES="PROJECT_NAME=my-app"
  export INPUT_PATH="$INPUT_DIR"
  export OUTPUT_PATH="$OUTPUT_DIR"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  grep -q "name: my-app" "$OUTPUT_DIR/deployment.yaml"
  grep -q "name: my-app-svc" "$OUTPUT_DIR/subdir/service.yaml"
}

@test "outputs substitution counts" {
  create_input_file "test.yaml" 'a: ${PROJECT_NAME}
b: ${PROJECT_NAME}'
  export VARIABLES="PROJECT_NAME=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]
  assert_output_contains "test.yaml:2"
}

@test "fails when VARIABLES not set" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}'
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"
  unset VARIABLES

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -ne 0 ]
  assert_output_contains "VARIABLES"
}

@test "fails when INPUT_PATH not found" {
  export VARIABLES="PROJECT_NAME=my-app"
  export INPUT_PATH="/nonexistent/path"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -ne 0 ]
  assert_output_contains "not found"
}

@test "fails when INPUT_PATH equals OUTPUT_PATH" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}'
  export VARIABLES="PROJECT_NAME=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$INPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -ne 0 ]
  assert_output_contains "must differ"
}

@test "does not substitute partial matches" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME_EXTRA}'
  export VARIABLES="PROJECT_NAME=my-app"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  # Should NOT be substituted - different variable name
  result=$(cat "$OUTPUT_DIR/test.yaml")
  [ "$result" = 'name: ${PROJECT_NAME_EXTRA}' ]
}

@test "substitutes multiple occurrences in same file" {
  create_input_file "test.yaml" 'name: ${version}
tag: ${version}
label: ${version}'
  export VARIABLES="version=1.2.3"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  grep -q "name: 1.2.3" "$OUTPUT_DIR/test.yaml"
  grep -q "tag: 1.2.3" "$OUTPUT_DIR/test.yaml"
  grep -q "label: 1.2.3" "$OUTPUT_DIR/test.yaml"
}

@test "fails when VARIABLES has invalid format" {
  create_input_file "test.yaml" 'name: ${PROJECT_NAME}'
  export VARIABLES=",,"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -ne 0 ]
}

@test "handles mixed case variables in same file" {
  create_input_file "test.yaml" 'upper: ${PROJECT_NAME}
kebab: ${project-name}'
  export VARIABLES="PROJECT_NAME=app1,project-name=app2"
  export INPUT_PATH="$INPUT_DIR/test.yaml"
  export OUTPUT_PATH="$OUTPUT_DIR/test.yaml"

  run "$PLUGINS_DIR/token-substitution-providers/substitute-shell-style-tokens"
  [ "$status" -eq 0 ]

  grep -q "upper: app1" "$OUTPUT_DIR/test.yaml"
  grep -q "kebab: app2" "$OUTPUT_DIR/test.yaml"
}
