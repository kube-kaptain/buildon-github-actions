#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/kaptainpm-bool.bash - the shared boolean reader that guards
# against yq's // operator clobbering an explicit false.

bats_require_minimum_version 1.5.0

load helpers

setup() {
  WORK=$(create_test_dir "kaptainpm-bool")
  # shellcheck source=src/scripts/lib/kaptainpm-bool.bash
  source "$LIB_DIR/kaptainpm-bool.bash"
}

teardown() {
  dump_bats_result
}

write_pm() {
  cat > "${WORK}/KaptainPM.yaml"
}

@test "explicit false survives (the yq // pitfall)" {
  write_pm << 'EOF'
spec:
  main:
    docker:
      targetIncludeNamespace: false
EOF
  [ "$(kaptainpm_bool "${WORK}/KaptainPM.yaml" spec.main.docker.targetIncludeNamespace true)" = "false" ]
}

@test "explicit true survives" {
  write_pm << 'EOF'
spec:
  main:
    docker:
      targetIncludeNamespace: true
EOF
  [ "$(kaptainpm_bool "${WORK}/KaptainPM.yaml" spec.main.docker.targetIncludeNamespace false)" = "true" ]
}

@test "absent path yields the default" {
  write_pm << 'EOF'
spec:
  main: {}
EOF
  [ "$(kaptainpm_bool "${WORK}/KaptainPM.yaml" spec.main.docker.targetIncludeNamespace true)" = "true" ]
  [ "$(kaptainpm_bool "${WORK}/KaptainPM.yaml" spec.main.docker.targetAllowNoRegistry false)" = "false" ]
}

@test "non-boolean value yields the default (schema owns rejection)" {
  write_pm << 'EOF'
spec:
  main:
    docker:
      targetIncludeNamespace: banana
EOF
  [ "$(kaptainpm_bool "${WORK}/KaptainPM.yaml" spec.main.docker.targetIncludeNamespace true)" = "true" ]
}

@test "uppercase YAML booleans are read as lowercase true/false" {
  write_pm << 'EOF2'
spec:
  main:
    docker:
      targetIncludeNamespace: FALSE
      targetAllowNoRegistry: True
EOF2
  [ "$(kaptainpm_bool "${WORK}/KaptainPM.yaml" spec.main.docker.targetIncludeNamespace true)" = "false" ]
  [ "$(kaptainpm_bool "${WORK}/KaptainPM.yaml" spec.main.docker.targetAllowNoRegistry false)" = "true" ]
}

@test "a quoted 'True' is a string, not a boolean, and yields the default" {
  write_pm << 'EOF2'
spec:
  main:
    docker:
      targetIncludeNamespace: 'True'
EOF2
  [ "$(kaptainpm_bool "${WORK}/KaptainPM.yaml" spec.main.docker.targetIncludeNamespace false)" = "false" ]
}

@test "kaptainpm_value lowercases booleans and leaves other values as written" {
  write_pm << 'EOF2'
spec:
  main:
    flag: False
    text: 'True'
    port: 8080
    name: my-app
EOF2
  [ "$(kaptainpm_value "${WORK}/KaptainPM.yaml" spec.main.flag)" = "false" ]
  [ "$(kaptainpm_value "${WORK}/KaptainPM.yaml" spec.main.text)" = "True" ]
  [ "$(kaptainpm_value "${WORK}/KaptainPM.yaml" spec.main.port)" = "8080" ]
  [ "$(kaptainpm_value "${WORK}/KaptainPM.yaml" spec.main.name)" = "my-app" ]
  [ "$(kaptainpm_value "${WORK}/KaptainPM.yaml" spec.main.absent)" = "null" ]
}
