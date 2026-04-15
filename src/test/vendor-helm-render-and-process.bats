#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/vendor-helm-render-and-process
# Covers: multi-doc split (Stage 3), moveFiles (Stage 4), sed replace (Stage 5),
# yq transform (Stage 6), YAML validation (Stage 8), and non-template dir copy.

load helpers

SCRIPT="$SCRIPTS_DIR/vendor-helm-render-and-process"

setup() {
  TEST_DIR=$(create_test_dir "vendor-helm-render")
  REPO_DIR="${TEST_DIR}/repo"
  mkdir -p "${REPO_DIR}"
  cd "${REPO_DIR}"

  # Version file required by script
  mkdir -p src/config
  echo "1.0.0" > src/config/VendorHelmRenderedVersion

  # Values file required by script (stage 2)
  mkdir -p src/vendor-helm-rendered
  cat > src/vendor-helm-rendered/values-1.0.0.yaml << 'EOF'
replicaCount: 1
EOF

  export OUTPUT_SUB_PATH="kaptain-out"
  export PROJECT_NAME="test-chart"
  export BUILD_PLATFORM="test"
  export GITHUB_OUTPUT="${TEST_DIR}/github-output"
  touch "${GITHUB_OUTPUT}"

  # Mock helm to produce rendered chart output
  mkdir -p "${MOCK_BIN_DIR}"
  cat > "${MOCK_BIN_DIR}/helm" << 'MOCKHELM'
#!/usr/bin/env bash
# Mock helm - for "pull" or "fetch", create a chart dir; for "template", render yamls
case "$1" in
  repo)
    exit 0
    ;;
  pull|fetch)
    # Find --destination arg
    dest=""
    for ((i=1; i<=$#; i++)); do
      arg="${!i}"
      if [[ "$arg" == "--destination" ]]; then
        next=$((i+1))
        dest="${!next}"
      fi
    done
    # Create a fake chart
    chart_dir="${dest}/test-chart"
    mkdir -p "${chart_dir}/templates"
    cat > "${chart_dir}/Chart.yaml" << 'CHART'
apiVersion: v2
name: test-chart
version: 1.0.0
CHART
    cat > "${chart_dir}/values.yaml" << 'VALUES'
replicaCount: 1
VALUES
    # Create sample rendered templates
    cat > "${chart_dir}/templates/deployment.yaml" << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-chart
  labels:
    app: test-chart
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-chart
  template:
    metadata:
      labels:
        app: test-chart
    spec:
      containers:
        - name: main
          image: nginx:1.25
DEPLOY
    cat > "${chart_dir}/templates/service.yaml" << 'SVC'
apiVersion: v1
kind: Service
metadata:
  name: test-chart
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: test-chart
SVC
    cat > "${chart_dir}/templates/clusterrole.yaml" << 'CR'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-chart-role
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "create", "update"]
CR
    cat > "${chart_dir}/templates/clusterrolebinding.yaml" << 'CRB'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: test-chart-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: test-chart-role
subjects:
  - kind: ServiceAccount
    name: test-chart
    namespace: default
CRB
    # Multi-doc template: two resources in one file separated by ---
    cat > "${chart_dir}/templates/multi-rbac.yaml" << 'MULTI'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-chart-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: test-chart-role-ns
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
MULTI
    # Non-template directory (e.g. crds/) - helm template does NOT render these
    mkdir -p "${chart_dir}/crds"
    cat > "${chart_dir}/crds/gateway-crd.yaml" << 'CRD'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: gateways.gateway.networking.k8s.io
spec:
  group: gateway.networking.k8s.io
  names:
    kind: Gateway
    plural: gateways
CRD
    exit 0
    ;;
  template)
    # Find --output-dir arg
    out_dir=""
    for ((i=1; i<=$#; i++)); do
      arg="${!i}"
      if [[ "$arg" == "--output-dir" ]]; then
        next=$((i+1))
        out_dir="${!next}"
      fi
    done
    # Find chart path (positional arg after release name)
    chart_path="$3"
    # Copy templates into output-dir preserving chart name structure
    chart_name=$(basename "${chart_path}")
    mkdir -p "${out_dir}/${chart_name}/templates"
    cp "${chart_path}"/templates/*.yaml "${out_dir}/${chart_name}/templates/"
    exit 0
    ;;
esac
exit 0
MOCKHELM
  chmod +x "${MOCK_BIN_DIR}/helm"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  if ! command -v yq &>/dev/null; then
    skip "yq not available"
  fi
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
}

# Minimal moveFiles JSON mapping the mock chart's templates to flat names
MOVE_FILES_JSON='[
  {"source":"templates/deployment.yaml","destination":"deployment.yaml"},
  {"source":"templates/service.yaml","destination":"service.yaml"},
  {"source":"templates/clusterrole.yaml","destination":"clusterrole.yaml"},
  {"source":"templates/clusterrolebinding.yaml","destination":"clusterrolebinding.yaml"}
]'

run_script() {
  run bash -c "cd '${REPO_DIR}' && '${SCRIPT}'"
}

# =============================================================================
# Stage 6: yq Transform - the seq 0 -1 / null expression bug
# =============================================================================

@test "yq perFile-only transform does not nuke untargeted manifests" {
  # This is THE bug: when yqTransform has perFile but no global section,
  # the global loop runs once with a null expression, nuking every manifest.
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"clusterrole.yaml","expressions":[".metadata.name = \"prefix:\" + .metadata.name"]}]}'

  run_script

  # The deployment and service should still have their full content
  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  [[ -f "${dep_file}" ]]
  local dep_content
  dep_content=$(cat "${dep_file}")
  [[ "${dep_content}" == *"kind: Deployment"* ]]
  [[ "${dep_content}" == *"spec:"* ]]
  [[ "${dep_content}" == *"containers:"* ]]

  local svc_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/service.yaml"
  [[ -f "${svc_file}" ]]
  local svc_content
  svc_content=$(cat "${svc_file}")
  [[ "${svc_content}" == *"kind: Service"* ]]
  [[ "${svc_content}" == *"ports:"* ]]
}

@test "yq perFile-only transform applies expression to targeted file" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"clusterrole.yaml","expressions":[".metadata.name = \"prefix:\" + .metadata.name"]}]}'

  run_script

  local cr_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrole.yaml"
  [[ -f "${cr_file}" ]]
  local cr_content
  cr_content=$(cat "${cr_file}")
  # The name should have been prefixed
  [[ "${cr_content}" == *"prefix:test-chart-role"* ]]
  # But the rest of the document should still be intact
  [[ "${cr_content}" == *"kind: ClusterRole"* ]]
  [[ "${cr_content}" == *"rules:"* ]]
}

@test "yq perFile transform with multiple expressions on same file" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"clusterrolebinding.yaml","expressions":[".metadata.name = \"prefix:\" + .metadata.name",".roleRef.name = \"prefix:\" + .roleRef.name"]}]}'

  run_script

  local crb_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrolebinding.yaml"
  [[ -f "${crb_file}" ]]
  local crb_content
  crb_content=$(cat "${crb_file}")
  [[ "${crb_content}" == *"prefix:test-chart-rolebinding"* ]]
  [[ "${crb_content}" == *"prefix:test-chart-role"* ]]
  [[ "${crb_content}" == *"kind: ClusterRoleBinding"* ]]
  [[ "${crb_content}" == *"subjects:"* ]]
}

@test "yq global transform applies to all manifests without nuking" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"global":[".metadata.labels.\"custom-label\" = \"added\""]}'

  run_script

  # All manifests should have the label and still retain full content
  for f in deployment.yaml service.yaml clusterrole.yaml clusterrolebinding.yaml; do
    local file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/${f}"
    [[ -f "${file}" ]]
    local content
    content=$(cat "${file}")
    [[ "${content}" == *"custom-label"* ]]
    [[ "${content}" == *"kind:"* ]]
    [[ "${content}" == *"metadata:"* ]]
  done
}

@test "yq global and perFile transforms together" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"global":[".metadata.labels.\"global-label\" = \"yes\""],"perFile":[{"file":"clusterrole.yaml","expressions":[".metadata.name = \"env:\" + .metadata.name"]}]}'

  run_script

  # Global label on all files
  for f in deployment.yaml service.yaml clusterrole.yaml clusterrolebinding.yaml; do
    local file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/${f}"
    local content
    content=$(cat "${file}")
    [[ "${content}" == *"global-label"* ]]
  done

  # perFile only on clusterrole
  local cr_content
  cr_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrole.yaml")
  [[ "${cr_content}" == *"env:test-chart-role"* ]]

  # Other files should NOT have the prefix
  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" != *"env:test-chart"* ]]
}

@test "no yq transforms preserves all manifest content" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  # No VENDOR_HELM_RENDERED_YQ_TRANSFORM set

  run_script

  # All manifests should pass through intact
  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  [[ -f "${dep_file}" ]]
  local dep_content
  dep_content=$(cat "${dep_file}")
  [[ "${dep_content}" == *"kind: Deployment"* ]]
  [[ "${dep_content}" == *"containers:"* ]]
  [[ "${dep_content}" == *"nginx:1.25"* ]]
}

@test "empty yq transform object does not nuke manifests" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{}'

  run_script

  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  [[ -f "${dep_file}" ]]
  local dep_content
  dep_content=$(cat "${dep_file}")
  [[ "${dep_content}" == *"kind: Deployment"* ]]
  [[ "${dep_content}" == *"spec:"* ]]
}

@test "yq perFile warns on non-existent target file" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"nonexistent.yaml","expressions":[".metadata.name = \"foo\""]}]}'

  run_script
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"WARNING: yq perFile target 'nonexistent.yaml' not found"* ]]
}

# =============================================================================
# Stage 5: sed replace - same seq pattern, similar risk
# =============================================================================

@test "sed perFile-only replace does not corrupt untargeted manifests" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"perFile":[{"file":"service.yaml","patterns":["s/ClusterIP/NodePort/"]}]}'

  run_script

  # service should be modified
  local svc_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/service.yaml"
  local svc_content
  svc_content=$(cat "${svc_file}")
  [[ "${svc_content}" == *"NodePort"* ]]

  # deployment should be untouched
  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  local dep_content
  dep_content=$(cat "${dep_file}")
  [[ "${dep_content}" == *"kind: Deployment"* ]]
  [[ "${dep_content}" == *"containers:"* ]]
}

@test "sed global-only replace applies to all manifests" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"global":["s/test-chart/replaced-name/g"]}'

  run_script
  [[ "$status" -eq 0 ]]

  for f in deployment.yaml service.yaml clusterrole.yaml clusterrolebinding.yaml; do
    local content
    content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/${f}")
    [[ "${content}" == *"replaced-name"* ]]
    [[ "${content}" != *"test-chart"* ]]
  done
}

@test "sed global and perFile together" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"global":["s/test-chart/global-replaced/g"],"perFile":[{"file":"service.yaml","patterns":["s/ClusterIP/NodePort/"]}]}'

  run_script
  [[ "$status" -eq 0 ]]

  # global applied everywhere
  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"global-replaced"* ]]

  # perFile applied only to service
  local svc_content
  svc_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/service.yaml")
  [[ "${svc_content}" == *"NodePort"* ]]
  [[ "${svc_content}" == *"global-replaced"* ]]
}

@test "yq empty perFile array with global does not break" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"global":[".metadata.labels.\"test\" = \"yes\""],"perFile":[]}'

  run_script
  [[ "$status" -eq 0 ]]

  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"test: \"yes\""* ]] || [[ "${dep_content}" == *"test: 'yes'"* ]] || [[ "${dep_content}" == *"test: yes"* ]]
  [[ "${dep_content}" == *"kind: Deployment"* ]]
}

@test "yq empty global array with perFile does not nuke" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"global":[],"perFile":[{"file":"clusterrole.yaml","expressions":[".metadata.name = \"env:\" + .metadata.name"]}]}'

  run_script
  [[ "$status" -eq 0 ]]

  # perFile target modified
  local cr_content
  cr_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrole.yaml")
  [[ "${cr_content}" == *"env:test-chart-role"* ]]
  [[ "${cr_content}" == *"rules:"* ]]

  # untargeted files intact
  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"kind: Deployment"* ]]
  [[ "${dep_content}" == *"containers:"* ]]
}

@test "sed empty perFile array with global does not break" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"global":["s/test-chart/sed-global/g"],"perFile":[]}'

  run_script
  [[ "$status" -eq 0 ]]

  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"sed-global"* ]]
}

@test "sed empty global array with perFile does not break" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"global":[],"perFile":[{"file":"service.yaml","patterns":["s/ClusterIP/NodePort/"]}]}'

  run_script
  [[ "$status" -eq 0 ]]

  local svc_content
  svc_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/service.yaml")
  [[ "${svc_content}" == *"NodePort"* ]]

  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"kind: Deployment"* ]]
}

# =============================================================================
# Stage 3: Multi-doc split
# =============================================================================

@test "multi-doc yaml is split into individual files" {
  # moveFiles references the split output: multi-rbac-0.yaml and multi-rbac-1.yaml
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[
    {"source":"templates/deployment.yaml","destination":"deployment.yaml"},
    {"source":"templates/multi-rbac-0.yaml","destination":"serviceaccount.yaml"},
    {"source":"templates/multi-rbac-1.yaml","destination":"role.yaml"}
  ]'

  run_script
  [[ "$status" -eq 0 ]]

  # Each split file should contain exactly one resource
  local sa_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/serviceaccount.yaml"
  [[ -f "${sa_file}" ]]
  local sa_content
  sa_content=$(cat "${sa_file}")
  [[ "${sa_content}" == *"kind: ServiceAccount"* ]]
  [[ "${sa_content}" == *"test-chart-sa"* ]]
  # Should NOT contain the Role from the second doc
  [[ "${sa_content}" != *"kind: Role"* ]]

  local role_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/role.yaml"
  [[ -f "${role_file}" ]]
  local role_content
  role_content=$(cat "${role_file}")
  [[ "${role_content}" == *"kind: Role"* ]]
  [[ "${role_content}" == *"configmaps"* ]]
  # Should NOT contain the ServiceAccount from the first doc
  [[ "${role_content}" != *"kind: ServiceAccount"* ]]
}

# =============================================================================
# Stage 4: moveFiles
# =============================================================================

@test "moveFiles discards files not in the mapping" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  # Only map deployment - everything else should be discarded
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/deployment.yaml","destination":"deployment.yaml"}]'

  run_script
  [[ "$status" -eq 0 ]]

  # deployment should exist
  [[ -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/deployment.yaml" ]]
  # service, clusterrole etc should NOT exist in D-moved-files
  [[ ! -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/service.yaml" ]]
  [[ ! -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/clusterrole.yaml" ]]
}

@test "moveFiles fails when a source file does not exist" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[
    {"source":"templates/deployment.yaml","destination":"deployment.yaml"},
    {"source":"templates/nonexistent.yaml","destination":"missing.yaml"}
  ]'

  run_script
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"moveFiles source not found"* ]]
  [[ "$output" == *"nonexistent.yaml"* ]]
}

@test "moveFiles renames files to destination paths" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/service.yaml","destination":"renamed-service.yaml"}]'

  run_script
  [[ "$status" -eq 0 ]]

  [[ -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/renamed-service.yaml" ]]
  [[ ! -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/service.yaml" ]]
  local content
  content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/renamed-service.yaml")
  [[ "${content}" == *"kind: Service"* ]]
}

# =============================================================================
# Stage 8: YAML validation
# =============================================================================

@test "fails on invalid YAML produced by sed replacement" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/deployment.yaml","destination":"deployment.yaml"}]'
  # Inject broken YAML: unbalanced quote via sed
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"perFile":[{"file":"deployment.yaml","patterns":["s/name: test-chart/name: \"broken: [unbalanced/"]}]}'

  run_script
  [[ "$status" -ne 0 ]]
}

# =============================================================================
# Non-template directory copy (e.g. crds/)
# =============================================================================

@test "non-template chart directories are copied into rendered output" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  # Include both a template file and a CRD from crds/
  export VENDOR_HELM_RENDERED_MOVE_FILES='[
    {"source":"templates/deployment.yaml","destination":"deployment.yaml"},
    {"source":"crds/gateway-crd.yaml","destination":"gateway-crd.yaml"}
  ]'

  run_script
  [[ "$status" -eq 0 ]]

  # CRD should have flowed through the pipeline
  local crd_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/gateway-crd.yaml"
  [[ -f "${crd_file}" ]]
  local crd_content
  crd_content=$(cat "${crd_file}")
  [[ "${crd_content}" == *"kind: CustomResourceDefinition"* ]]
  [[ "${crd_content}" == *"gateways.gateway.networking.k8s.io"* ]]
}

@test "non-template dirs do not overwrite rendered template dirs" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"

  run_script
  [[ "$status" -eq 0 ]]

  # templates/ dir content should be from helm template, not raw chart copy
  # The script logs "already in rendered output, skipping" for templates/
  [[ "$output" == *"templates/ already in rendered output"* ]] || \
    [[ "$output" != *"Copying non-template dir: templates/"* ]]
}
