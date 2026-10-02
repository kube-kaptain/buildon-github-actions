#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for lib/resource-checksum.bash: the secret input set (which secret-template
# tokens need an encrypted value and feed the hash) and checksum_tree.

bats_require_minimum_version 1.5.0

load helpers

setup() {
  TEST_DIR=$(create_test_dir "resource-checksum")
  source "${LIB_DIR}/token-format.bash"
  source "${LIB_DIR}/token-markers.bash"
  source "${LIB_DIR}/secret-encryption-types.bash"
  source "${LIB_DIR}/resource-checksum.bash"
  export TOKEN_DELIMITER_STYLE="shell"
  export TOKEN_NAME_STYLE="PascalCase"
  # The preflight's files, so no container runtime is needed.
  write_secret_encryption_files "${TEST_DIR}" age
  export RESOURCE_CHECKSUM_AUDIT_DIR="${TEST_DIR}/audit"
  mkdir -p "${TEST_DIR}/tree" "${TEST_DIR}/secrets"
  cd "${TEST_DIR}"
}

teardown() {
  dump_bats_result
}

write_template() {
  cat > "${TEST_DIR}/tree/thing.template.yaml"
}

@test "secret input set: every token needs an encrypted value" {
  write_template << 'EOF'
stringData:
  password: ${DbPassword}
EOF
  printf 'ciphertext' > secrets/DbPassword.age
  checksum_secret_input_set "${TEST_DIR}/tree" "${TEST_DIR}/tree/thing.template.yaml" secrets 5
  [ "${SECRET_TOKEN_COUNT}" -eq 1 ]
  [ -n "${SECRET_HASH}" ]
}

@test "secret input set: a missing encrypted value fails" {
  write_template << 'EOF'
stringData:
  password: ${DbPassword}
EOF
  run checksum_secret_input_set "${TEST_DIR}/tree" "${TEST_DIR}/tree/thing.template.yaml" secrets 5
  [ "$status" -ne 0 ]
  assert_output_contains "references token 'DbPassword'"
}

@test "secret input set: a token an IgnoreUnresolved marker covers needs no value" {
  write_template << 'EOF'
stringData:
  script: echo ${HOME} # IgnoreUnresolved
  password: ${DbPassword}
EOF
  printf 'ciphertext' > secrets/DbPassword.age
  checksum_secret_input_set "${TEST_DIR}/tree" "${TEST_DIR}/tree/thing.template.yaml" secrets 5
  [ "${SECRET_TOKEN_COUNT}" -eq 1 ]
}

# =============================================================================
# checksum_tree: one-pass bounded rename with verification
# =============================================================================

ORDER_FILE="${PROJECT_ROOT}/src/data/resource-order/default-1.1.txt"

# write_doc <file> <kind> <name> [extra yaml lines]
write_doc() {
  local file="$1" kind="$2" name="$3"
  shift 3
  mkdir -p "$(dirname "${TEST_DIR}/tree/${file}")"
  {
    echo "kind: ${kind}"
    echo "metadata:"
    echo "  name: ${name}"
    local line
    for line in "$@"; do
      echo "${line}"
    done
  } > "${TEST_DIR}/tree/${file}"
}

# Name of the single document of <kind> in <file>.
doc_name() {
  KIND="$2" yq ea 'select(.kind == env(KIND)) | .metadata.name' "${TEST_DIR}/tree/$1"
}

@test "checksum_tree: a dotted name is renamed along with its references" {
  write_doc cm.yaml ConfigMap my.app-configmap-checksum "data:" "  k: v"
  write_doc deploy.yaml Deployment my.app "spec:" "  volumes:" "    - configMap:" "        name: my.app-configmap-checksum"
  run checksum_tree "${TEST_DIR}/tree" "" "${ORDER_FILE}"
  [ "$status" -eq 0 ]
  local new
  new=$(doc_name cm.yaml ConfigMap)
  [[ "${new}" == my.app-* && "${new}" != my.app-configmap-checksum ]] || return 1
  grep -qx "        name: ${new}" "${TEST_DIR}/tree/deploy.yaml"
  ! grep -rq 'my.app-configmap-checksum' "${TEST_DIR}/tree"
}

@test "checksum_tree: a shorter name never rewrites the tail of a longer one, in either order" {
  local first second
  for prefix in "omg-" "omg."; do
    rm -rf "${TEST_DIR:?}/tree"
    mkdir -p "${TEST_DIR}/tree"
    write_doc a-short.yaml Role wtf-bbq-role-checksum "rules: []"
    write_doc b-long.yaml Role "${prefix}wtf-bbq-role-checksum" "rules: []"
    write_doc c-binding.yaml RoleBinding binds "roleRef:" "  name: ${prefix}wtf-bbq-role-checksum" "extra:" "  - wtf-bbq-role-checksum"
    run checksum_tree "${TEST_DIR}/tree" "" "${ORDER_FILE}"
    [ "$status" -eq 0 ]
    first="$(doc_name a-short.yaml Role) $(doc_name b-long.yaml Role)"
    [[ "$(doc_name b-long.yaml Role)" == "${prefix}wtf-bbq-"* ]] || return 1
    grep -qx "  name: $(doc_name b-long.yaml Role)" "${TEST_DIR}/tree/c-binding.yaml"
    grep -qx "  - $(doc_name a-short.yaml Role)" "${TEST_DIR}/tree/c-binding.yaml"

    # Same resources, long one processed first.
    rm -rf "${TEST_DIR:?}/tree"
    mkdir -p "${TEST_DIR}/tree"
    write_doc b-short.yaml Role wtf-bbq-role-checksum "rules: []"
    write_doc a-long.yaml Role "${prefix}wtf-bbq-role-checksum" "rules: []"
    write_doc c-binding.yaml RoleBinding binds "roleRef:" "  name: ${prefix}wtf-bbq-role-checksum" "extra:" "  - wtf-bbq-role-checksum"
    run checksum_tree "${TEST_DIR}/tree" "" "${ORDER_FILE}"
    [ "$status" -eq 0 ]
    second="$(doc_name b-short.yaml Role) $(doc_name a-long.yaml Role)"
    [ "${first}" = "${second}" ]
  done
}

@test "checksum_tree: bounding rewrites the name wherever it stands alone and nowhere else" {
  write_doc cm.yaml ConfigMap app-configmap-checksum "data:" "  k: v"
  cat > "${TEST_DIR}/tree/refs.yaml" << 'EOF'
# full-line comment app-configmap-checksum
kind: Deployment
metadata:
  name: refs # trailing comment app-configmap-checksum
  annotations:
    quoted: "app-configmap-checksum"
    sentence: "mounted from app-configmap-checksum, see docs"
    path: /etc/app-configmap-checksum/file
    kind-slash-name: configmap/app-configmap-checksum
    adjacent: app-configmap-checksum,app-configmap-checksum
    underscore: FOO_app-configmap-checksum
    prefixed: xapp-configmap-checksum
    dotted-prefix: my.app-configmap-checksum
    dash-suffix: app-configmap-checksum-2
    dot-suffix: app-configmap-checksum.yaml
    block: |
      line with app-configmap-checksum inside
EOF
  run checksum_tree "${TEST_DIR}/tree" "" "${ORDER_FILE}"
  [ "$status" -eq 0 ]
  local new refs
  new=$(doc_name cm.yaml ConfigMap)
  refs="${TEST_DIR}/tree/refs.yaml"
  grep -qx "# full-line comment ${new}" "${refs}"
  grep -qx "  name: refs # trailing comment ${new}" "${refs}"
  grep -qx "    quoted: \"${new}\"" "${refs}"
  grep -qx "    sentence: \"mounted from ${new}, see docs\"" "${refs}"
  grep -qx "    path: /etc/${new}/file" "${refs}"
  grep -qx "    kind-slash-name: configmap/${new}" "${refs}"
  grep -qx "    adjacent: ${new},${new}" "${refs}"
  grep -qx "    underscore: FOO_${new}" "${refs}"
  grep -qx "      line with ${new} inside" "${refs}"
  grep -qx "    prefixed: xapp-configmap-checksum" "${refs}"
  grep -qx "    dotted-prefix: my.app-configmap-checksum" "${refs}"
  grep -qx "    dash-suffix: app-configmap-checksum-2" "${refs}"
  grep -qx "    dot-suffix: app-configmap-checksum.yaml" "${refs}"
}

@test "checksum_tree: the rename is one rewrite that includes the resource's own name line" {
  write_doc cm.yaml ConfigMap "app-configmap-checksum # own comment app-configmap-checksum" "data:" "  k: v"
  run checksum_tree "${TEST_DIR}/tree" "" "${ORDER_FILE}"
  [ "$status" -eq 0 ]
  local new
  new=$(doc_name cm.yaml ConfigMap)
  grep -qx "  name: ${new} # own comment ${new}" "${TEST_DIR}/tree/cm.yaml"
}

@test "checksum_tree: every invalid marked name is reported and nothing is renamed" {
  write_doc one.yaml ConfigMap My.App-configmap-checksum "data: {}"
  write_doc two.yaml ConfigMap -bad-configmap-checksum "data: {}"
  write_doc three.yaml ConfigMap good-configmap-checksum "data: {}"
  run checksum_tree "${TEST_DIR}/tree" "" "${ORDER_FILE}"
  [ "$status" -ne 0 ]
  assert_output_contains "one.yaml: 'My.App-configmap-checksum' is not a valid Kubernetes name"
  assert_output_contains "two.yaml: '-bad-configmap-checksum' is not a valid Kubernetes name"
  assert_output_contains "2 checksum-marked name(s) invalid"
  [ "$(doc_name three.yaml ConfigMap)" = "good-configmap-checksum" ]
}

@test "checksum_tree: two resources sharing a marked name fail the post-rename check" {
  write_doc ns-a/cm.yaml ConfigMap app-configmap-checksum "data:" "  k: a"
  write_doc ns-b/cm.yaml ConfigMap app-configmap-checksum "data:" "  k: b"
  run checksum_tree "${TEST_DIR}/tree" "" "${ORDER_FILE}"
  [ "$status" -ne 0 ]
  assert_output_contains "2 ConfigMap resource(s) named"
  assert_output_contains "expected exactly 1"
}

@test "checksum_tree: an IngressClass is renamed before the Ingress that names it is hashed" {
  write_doc class.yaml IngressClass edge-ingressclass-checksum "spec:" "  controller: example.com/c"
  write_doc ing.yaml Ingress web-ingress-checksum "spec:" "  ingressClassName: edge-ingressclass-checksum"
  run checksum_tree "${TEST_DIR}/tree" "" "${ORDER_FILE}"
  [ "$status" -eq 0 ]
  local class_line ing_line
  class_line=$(grep -n 'edge-ingressclass-checksum ->' <<< "${output}" | cut -d: -f1)
  ing_line=$(grep -n 'web-ingress-checksum ->' <<< "${output}" | cut -d: -f1)
  [ "${class_line}" -lt "${ing_line}" ]
  grep -qx "  ingressClassName: $(doc_name class.yaml IngressClass)" "${TEST_DIR}/tree/ing.yaml"
}
