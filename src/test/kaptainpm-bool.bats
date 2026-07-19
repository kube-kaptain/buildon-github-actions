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
