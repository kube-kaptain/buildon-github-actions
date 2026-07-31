#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for main/vendor-helm-render-and-process
# Covers: multi-doc split (Stage 3), moveFiles (Stage 4), sed replace (Stage 5),
# yq transform (Stage 6), YAML validation (Stage 8), and non-template dir copy.

bats_require_minimum_version 1.5.0

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
    # Simulate a name-collision failure on `helm repo add` when asked to.
    if [[ "$2" == "add" && "${MOCK_HELM_REPO_ADD_FAILS:-false}" == "true" ]]; then
      echo "Error: repository name (${3}) already exists, please specify a different name" >&2
      exit 1
    fi
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
    helm.sh/chart: test-chart-1.0.0
  annotations:
    helm.sh/hook: post-install
    helm.sh/hook-weight: "5"
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
    # Cluster-scoped resource whose name templates .Release.Namespace, the
    # common chart idiom for avoiding cross-namespace ClusterRole collisions.
    # Helm renders it from --namespace, which Kaptain sets to its sentinel, so
    # the name carries the placeholder until the stage 7 sentinel sweep swaps
    # it for the environment token.
    cat > "${chart_dir}/templates/clusterrole-namespaced.yaml" << 'CRNS'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kaptain-namespace-placeholder-test-chart-reader
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
CRNS
    # Helm renders fullnameOverride into names and anywhere the chart
    # interpolates the fullname; the stage 7 sweep turns it into the
    # project-name token.
    cat > "${chart_dir}/templates/configmap-fullname.yaml" << 'CMF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kaptain-fullname-placeholder-config
data:
  owner: kaptain-fullname-placeholder
CMF
    # A chart that truncates the sentinel leaves a fragment no substitution can
    # match - it must fail the build rather than ship a mangled name.
    cat > "${chart_dir}/templates/configmap-truncated.yaml" << 'CMT'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kaptain-fullname-plac
data:
  note: truncated by an over-eager chart helper
CMT
    # Upstream-style workloads: app.kubernetes.io/name is the CHART name, which
    # diverges from metadata.name once fullnameOverride is applied. Exercises
    # the label-closure normalisation (pod template, selector, affinity,
    # topology spread) and selector association from other resources.
    cat > "${chart_dir}/templates/deployment-worker.yaml" << 'WORKER'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-chart-worker
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: upstream-chart
      app.kubernetes.io/instance: test-chart
  template:
    metadata:
      labels:
        app.kubernetes.io/name: upstream-chart
        app.kubernetes.io/instance: test-chart
        app.kubernetes.io/component: worker
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: upstream-chart
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - topologyKey: kubernetes.io/hostname
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: upstream-chart
      containers:
        - name: main
          image: nginx:1.25
WORKER
    cat > "${chart_dir}/templates/deployment-twin.yaml" << 'TWIN'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-chart-twin
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: upstream-chart
      app.kubernetes.io/instance: test-chart
  template:
    metadata:
      labels:
        app.kubernetes.io/name: upstream-chart
        app.kubernetes.io/instance: test-chart
        app.kubernetes.io/component: twin
    spec:
      containers:
        - name: main
          image: nginx:1.25
TWIN
    # Selects the worker only (component narrows it) - single match, rewritten.
    cat > "${chart_dir}/templates/service-worker.yaml" << 'SVCW'
apiVersion: v1
kind: Service
metadata:
  name: test-chart-worker
spec:
  ports:
    - port: 80
  selector:
    app.kubernetes.io/name: upstream-chart
    app.kubernetes.io/component: worker
SVCW
    # Spans worker AND twin - ambiguous, must be skipped with a warning.
    cat > "${chart_dir}/templates/service-spanning.yaml" << 'SVCS'
apiVersion: v1
kind: Service
metadata:
  name: test-chart-all
spec:
  ports:
    - port: 80
  selector:
    app.kubernetes.io/name: upstream-chart
    app.kubernetes.io/instance: test-chart
SVCS
    # Spans worker AND twin. A LabelSelector CAN express that, so it must be
    # converted to a matchExpressions In list rather than warned about.
    cat > "${chart_dir}/templates/networkpolicy-spanning.yaml" << 'NP'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-chart-all
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: upstream-chart
      app.kubernetes.io/instance: test-chart
  policyTypes:
    - Egress
NP
    # Selector written against the workload's NAME rather than the chart's
    # label. Matches no pods today (they still say upstream-chart) but will
    # match once normalisation relabels them - so it must not be warned about.
    cat > "${chart_dir}/templates/service-by-name.yaml" << 'SVCN'
apiVersion: v1
kind: Service
metadata:
  name: test-chart-by-name
spec:
  ports:
    - port: 80
  selector:
    app.kubernetes.io/name: test-chart-worker
SVCN
    # CronJob: pod template lives under jobTemplate, and its selector is
    # controller-generated so it must never be written.
    cat > "${chart_dir}/templates/cronjob-worker.yaml" << 'CJ'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: test-chart-cron
spec:
  schedule: "0 * * * *"
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app.kubernetes.io/name: upstream-chart
        spec:
          restartPolicy: OnFailure
          containers:
            - name: main
              image: nginx:1.25
CJ
    # A workload named by fullnameOverride, whose chart labels diverge. Proves
    # the closure normalisation (which runs pre-sweep, so it sees the sentinel)
    # and the sentinel sweep compose into a token-consistent result.
    cat > "${chart_dir}/templates/deployment-sentinel.yaml" << 'DEPSENT'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kaptain-fullname-placeholder
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: upstream-chart
  template:
    metadata:
      labels:
        app.kubernetes.io/name: upstream-chart
    spec:
      containers:
        - name: main
          image: nginx:1.25
DEPSENT
    # A self-consistent chart carrying only the modern label, as produced by a
    # project that sets fullnameOverride in its own values and opts out of ours.
    cat > "${chart_dir}/templates/deployment-modern-only.yaml" << 'DEPMOD'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-chart-modern
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: test-chart-modern
  template:
    metadata:
      labels:
        app.kubernetes.io/name: test-chart-modern
        app.kubernetes.io/instance: test-chart
    spec:
      containers:
        - name: main
          image: nginx:1.25
DEPMOD
    # Both app-style labels present but disagreeing - must be rejected.
    cat > "${chart_dir}/templates/deployment-disagree.yaml" << 'DEPDIS'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-chart-disagree
spec:
  selector:
    matchLabels:
      app: test-chart-disagree
  template:
    metadata:
      labels:
        app: test-chart-disagree
        app.kubernetes.io/name: something-else
    spec:
      containers:
        - name: main
          image: nginx:1.25
DEPDIS
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
  [[ -f "${dep_file}" ]] || return 1
  local dep_content
  dep_content=$(cat "${dep_file}")
  [[ "${dep_content}" == *"kind: Deployment"* ]] || return 1
  [[ "${dep_content}" == *"spec:"* ]] || return 1
  [[ "${dep_content}" == *"containers:"* ]] || return 1

  local svc_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/service.yaml"
  [[ -f "${svc_file}" ]] || return 1
  local svc_content
  svc_content=$(cat "${svc_file}")
  [[ "${svc_content}" == *"kind: Service"* ]] || return 1
  [[ "${svc_content}" == *"ports:"* ]] || return 1
}

@test "yq perFile-only transform applies expression to targeted file" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"clusterrole.yaml","expressions":[".metadata.name = \"prefix:\" + .metadata.name"]}]}'

  run_script

  local cr_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrole.yaml"
  [[ -f "${cr_file}" ]] || return 1
  local cr_content
  cr_content=$(cat "${cr_file}")
  # The name should have been prefixed
  [[ "${cr_content}" == *"prefix:test-chart-role"* ]] || return 1
  # But the rest of the document should still be intact
  [[ "${cr_content}" == *"kind: ClusterRole"* ]] || return 1
  [[ "${cr_content}" == *"rules:"* ]] || return 1
}

@test "yq perFile transform with multiple expressions on same file" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"clusterrolebinding.yaml","expressions":[".metadata.name = \"prefix:\" + .metadata.name",".roleRef.name = \"prefix:\" + .roleRef.name"]}]}'

  run_script

  local crb_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrolebinding.yaml"
  [[ -f "${crb_file}" ]] || return 1
  local crb_content
  crb_content=$(cat "${crb_file}")
  [[ "${crb_content}" == *"prefix:test-chart-rolebinding"* ]] || return 1
  [[ "${crb_content}" == *"prefix:test-chart-role"* ]] || return 1
  [[ "${crb_content}" == *"kind: ClusterRoleBinding"* ]] || return 1
  [[ "${crb_content}" == *"subjects:"* ]] || return 1
}

@test "yq global transform applies to all manifests without nuking" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"global":[".metadata.labels.\"custom-label\" = \"added\""]}'

  run_script

  # All manifests should have the label and still retain full content
  for f in deployment.yaml service.yaml clusterrole.yaml clusterrolebinding.yaml; do
    local file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/${f}"
    [[ -f "${file}" ]] || return 1
    local content
    content=$(cat "${file}")
    [[ "${content}" == *"custom-label"* ]] || return 1
    [[ "${content}" == *"kind:"* ]] || return 1
    [[ "${content}" == *"metadata:"* ]] || return 1
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
    [[ "${content}" == *"global-label"* ]] || return 1
  done

  # perFile only on clusterrole
  local cr_content
  cr_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrole.yaml")
  [[ "${cr_content}" == *"env:test-chart-role"* ]] || return 1

  # Other files should NOT have the prefix
  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" != *"env:test-chart"* ]] || return 1
}

@test "no yq transforms preserves all manifest content" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  # No VENDOR_HELM_RENDERED_YQ_TRANSFORM set

  run_script

  # All manifests should pass through intact
  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  [[ -f "${dep_file}" ]] || return 1
  local dep_content
  dep_content=$(cat "${dep_file}")
  [[ "${dep_content}" == *"kind: Deployment"* ]] || return 1
  [[ "${dep_content}" == *"containers:"* ]] || return 1
  [[ "${dep_content}" == *"nginx:1.25"* ]] || return 1
}

@test "empty yq transform object does not nuke manifests" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{}'

  run_script

  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  [[ -f "${dep_file}" ]] || return 1
  local dep_content
  dep_content=$(cat "${dep_file}")
  [[ "${dep_content}" == *"kind: Deployment"* ]] || return 1
  [[ "${dep_content}" == *"spec:"* ]] || return 1
}

@test "yq perFile warns on non-existent target file" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"nonexistent.yaml","expressions":[".metadata.name = \"foo\""]}]}'

  run_script
  [[ "$status" -eq 0 ]] || return 1
  [[ "$output" == *"WARNING: yq perFile target 'nonexistent.yaml' not found"* ]] || return 1
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
  [[ "${svc_content}" == *"NodePort"* ]] || return 1

  # deployment should be untouched
  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  local dep_content
  dep_content=$(cat "${dep_file}")
  [[ "${dep_content}" == *"kind: Deployment"* ]] || return 1
  [[ "${dep_content}" == *"containers:"* ]] || return 1
}

@test "sed global-only replace applies to all manifests" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"global":["s/test-chart/replaced-name/g"]}'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  for f in deployment.yaml service.yaml clusterrole.yaml clusterrolebinding.yaml; do
    local file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/${f}"
    local content non_anno
    content=$(cat "${file}")
    non_anno=$(yq eval 'del(.metadata.annotations)' "${file}")
    [[ "${content}" == *"replaced-name"* ]] || return 1
    [[ "${non_anno}" != *"test-chart"* ]] || return 1
  done
}

@test "sed global and perFile together" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"global":["s/test-chart/global-replaced/g"],"perFile":[{"file":"service.yaml","patterns":["s/ClusterIP/NodePort/"]}]}'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  # global applied everywhere
  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"global-replaced"* ]] || return 1

  # perFile applied only to service
  local svc_content
  svc_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/service.yaml")
  [[ "${svc_content}" == *"NodePort"* ]] || return 1
  [[ "${svc_content}" == *"global-replaced"* ]] || return 1
}

@test "yq empty perFile array with global does not break" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"global":[".metadata.labels.\"test\" = \"yes\""],"perFile":[]}'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"test: \"yes\""* ]] || [[ "${dep_content}" == *"test: 'yes'"* ]] || [[ "${dep_content}" == *"test: yes"* ]] || return 1
  [[ "${dep_content}" == *"kind: Deployment"* ]] || return 1
}

@test "yq empty global array with perFile does not nuke" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"global":[],"perFile":[{"file":"clusterrole.yaml","expressions":[".metadata.name = \"env:\" + .metadata.name"]}]}'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  # perFile target modified
  local cr_content
  cr_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrole.yaml")
  [[ "${cr_content}" == *"env:test-chart-role"* ]] || return 1
  [[ "${cr_content}" == *"rules:"* ]] || return 1

  # untargeted files intact
  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"kind: Deployment"* ]] || return 1
  [[ "${dep_content}" == *"containers:"* ]] || return 1
}

@test "sed empty perFile array with global does not break" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"global":["s/test-chart/sed-global/g"],"perFile":[]}'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"sed-global"* ]] || return 1
}

@test "sed empty global array with perFile does not break" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export VENDOR_HELM_RENDERED_SED_REPLACE='{"global":[],"perFile":[{"file":"service.yaml","patterns":["s/ClusterIP/NodePort/"]}]}'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local svc_content
  svc_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/service.yaml")
  [[ "${svc_content}" == *"NodePort"* ]] || return 1

  local dep_content
  dep_content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml")
  [[ "${dep_content}" == *"kind: Deployment"* ]] || return 1
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
  [[ "$status" -eq 0 ]] || return 1

  # Each split file should contain exactly one resource
  local sa_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/serviceaccount.yaml"
  [[ -f "${sa_file}" ]] || return 1
  local sa_content
  sa_content=$(cat "${sa_file}")
  [[ "${sa_content}" == *"kind: ServiceAccount"* ]] || return 1
  [[ "${sa_content}" == *"test-chart-sa"* ]] || return 1
  # Should NOT contain the Role from the second doc
  [[ "${sa_content}" != *"kind: Role"* ]] || return 1

  local role_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/role.yaml"
  [[ -f "${role_file}" ]] || return 1
  local role_content
  role_content=$(cat "${role_file}")
  [[ "${role_content}" == *"kind: Role"* ]] || return 1
  [[ "${role_content}" == *"configmaps"* ]] || return 1
  # Should NOT contain the ServiceAccount from the first doc
  [[ "${role_content}" != *"kind: ServiceAccount"* ]] || return 1
}

# =============================================================================
# Stage 4: moveFiles
# =============================================================================

@test "moveFiles discards files not in the mapping" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  # Only map deployment - everything else should be discarded
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/deployment.yaml","destination":"deployment.yaml"}]'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  # deployment should exist
  [[ -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/deployment.yaml" ]] || return 1
  # service, clusterrole etc should NOT exist in D-moved-files
  [[ ! -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/service.yaml" ]] || return 1
  [[ ! -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/clusterrole.yaml" ]] || return 1
}

@test "moveFiles fails when a source file does not exist" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[
    {"source":"templates/deployment.yaml","destination":"deployment.yaml"},
    {"source":"templates/nonexistent.yaml","destination":"missing.yaml"}
  ]'

  run_script
  [[ "$status" -ne 0 ]] || return 1
  [[ "$output" == *"moveFiles source not found"* ]] || return 1
  [[ "$output" == *"nonexistent.yaml"* ]] || return 1
}

@test "moveFiles renames files to destination paths" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/service.yaml","destination":"renamed-service.yaml"}]'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  [[ -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/renamed-service.yaml" ]] || return 1
  [[ ! -f "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/service.yaml" ]] || return 1
  local content
  content=$(cat "${REPO_DIR}/kaptain-out/helm-processing/D-moved-files/renamed-service.yaml")
  [[ "${content}" == *"kind: Service"* ]] || return 1
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
  [[ "$status" -ne 0 ]] || return 1
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
  [[ "$status" -eq 0 ]] || return 1

  # CRD should have flowed through the pipeline
  local crd_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/gateway-crd.yaml"
  [[ -f "${crd_file}" ]] || return 1
  local crd_content
  crd_content=$(cat "${crd_file}")
  [[ "${crd_content}" == *"kind: CustomResourceDefinition"* ]] || return 1
  [[ "${crd_content}" == *"gateways.gateway.networking.k8s.io"* ]] || return 1
}

@test "non-template dirs do not overwrite rendered template dirs" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  # templates/ dir content should be from helm template, not raw chart copy
  # The script logs "already in rendered output, skipping" for templates/
  [[ "$output" == *"templates/ already in rendered output"* ]] || \
    [[ "$output" != *"Copying non-template dir: templates/"* ]] || return 1
}

# =============================================================================
# kaptain.org/* metadata emission
# =============================================================================

@test "emits full kaptain.org metadata superset on annotated manifest" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export REPOSITORY_OWNER="kube-kaptain"
  export REPOSITORY_NAME="test-project"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  [[ -f "${dep_file}" ]] || return 1
  local content
  content=$(cat "${dep_file}")

  # Labels from the design's Site 3 superset
  [[ "${content}" == *'kaptain.org/environment: ${Environment}'* ]] || return 1
  [[ "${content}" == *'kaptain.org/product: ${ProductName}'* ]] || return 1
  [[ "${content}" == *'app.kubernetes.io/managed-by: Kaptain'* ]] || return 1
  [[ "${content}" == *'app.kubernetes.io/version: "${Version}"'* ]] || return 1
  [[ "${content}" == *'kaptain.org/version: "${Version}"'* ]] || return 1
  [[ "${content}" == *'kaptain.org/project-name: ${ProjectName}'* ]] || return 1
  [[ "${content}" == *'kaptain.org/owner: kube-kaptain'* ]] || return 1

  # Annotations from the design's Site 3 superset
  # build-timestamp and built-by are stamped later by vendor-helm-inject-build-details
  # so the vendor render output stays stable across local and CI runs.
  [[ "${content}" != *'kaptain.org/build-timestamp'* ]] || return 1
  [[ "${content}" != *'kaptain.org/built-by'* ]] || return 1
  [[ "${content}" == *'kaptain.org/generated-by: Generated by Kaptain vendor-helm-render-and-process'* ]] || return 1
  [[ "${content}" == *'kaptain.org/source-repository: kube-kaptain/test-project'* ]] || return 1

  # project-name and version live on labels only, not annotations
  local annotations
  annotations=$(yq eval '.metadata.annotations | keys | .[]' "${dep_file}")
  [[ "${annotations}" != *'kaptain.org/project-name'* ]] || return 1
  [[ "${annotations}" != *'kaptain.org/version'* ]] || return 1

  # app and app.kubernetes.io/name identify the application (the project token),
  # not the resource's own .metadata.name
  [[ $(yq eval '.metadata.labels.app' "${dep_file}") == '${ProjectName}' ]] || return 1
  [[ $(yq eval '.metadata.labels."app.kubernetes.io/name"' "${dep_file}") == '${ProjectName}' ]] || return 1

  # Vendor must NOT emit kaptain.org/image-uri (no IMAGE_URI in vendor pipeline)
  [[ "${content}" != *'kaptain.org/image-uri'* ]] || return 1
}

@test "drops annotation copies of label-only keys (environment, product, managed-by, app version)" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export REPOSITORY_OWNER="kube-kaptain"
  export REPOSITORY_NAME="test-project"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  local annotations
  annotations=$(yq eval '.metadata.annotations | keys | .[]' "${dep_file}")

  [[ "${annotations}" != *'kaptain.org/environment'* ]] || return 1
  [[ "${annotations}" != *'kaptain.org/product'* ]] || return 1
  [[ "${annotations}" != *'app.kubernetes.io/managed-by'* ]] || return 1
  [[ "${annotations}" != *'app.kubernetes.io/version'* ]] || return 1
}

@test "omits env-conditional metadata keys when repo env vars unset" {
  # BUILD_PLATFORM is intentionally left set: defaults/platform.bash hard-requires it.
  # Repo-context vars (REPOSITORY_OWNER/NAME, SOURCE_REPO) are the genuinely optional ones.
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  unset REPOSITORY_OWNER REPOSITORY_NAME SOURCE_REPO

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  local content
  content=$(cat "${dep_file}")

  [[ "${content}" != *'kaptain.org/owner'* ]] || return 1
  [[ "${content}" != *'kaptain.org/source-repository'* ]] || return 1

  # Required keys must still emit
  [[ "${content}" == *'kaptain.org/version'* ]] || return 1
  [[ "${content}" == *'kaptain.org/project-name'* ]] || return 1
  [[ "${content}" != *'kaptain.org/build-timestamp'* ]] || return 1
  [[ "${content}" != *'kaptain.org/built-by'* ]] || return 1
  [[ "${content}" == *'kaptain.org/generated-by:'* ]] || return 1
}

@test "strips helm.sh/* from labels and annotations" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  local label_keys annotation_keys
  label_keys=$(yq eval '.metadata.labels | keys | .[]' "${dep_file}")
  annotation_keys=$(yq eval '.metadata.annotations | keys | .[]' "${dep_file}")

  [[ "${label_keys}" != *'helm.sh/'* ]] || return 1
  [[ "${annotation_keys}" != *'helm.sh/'* ]] || return 1
}

@test "copies helm.sh/chart label value into kaptain.org/helm-upstream-chart annotation" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local dep_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml"
  local upstream
  upstream=$(yq eval '.metadata.annotations."kaptain.org/helm-upstream-chart"' "${dep_file}")

  [[ "${upstream}" == "test-chart-1.0.0" ]] || return 1
}

@test "stamps kaptain.org/helm-upstream-chart from Chart.yaml even when source has no helm.sh/chart label" {
  # The mock service.yaml fixture has no helm.sh/chart label, but the annotation
  # is sourced from Chart.yaml so every manifest gets it regardless.
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local svc_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/service.yaml"
  local upstream
  upstream=$(yq eval '.metadata.annotations."kaptain.org/helm-upstream-chart"' "${svc_file}")

  [[ "${upstream}" == "test-chart-1.0.0" ]] || return 1
}

# =============================================================================
# Stage 1: HTTP repo fetch - per-project repo alias
# =============================================================================

@test "http repo path adds the repo under the project name and fetches from it" {
  export VENDOR_HELM_RENDERED_REPO_URL="https://example.com/charts"
  export VENDOR_HELM_RENDERED_CHART_NAME="test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"

  run_script
  [ "$status" -eq 0 ]
  # Repo alias is the project name (test-chart), not a shared literal.
  [[ "$output" == *"Adding repo: https://example.com/charts as test-chart"* ]] || return 1
  [[ "$output" == *"Fetching chart: test-chart/test-chart"* ]] || return 1
  [[ "$output" != *"vendor-chart"* ]] || return 1
  [[ -f "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/deployment.yaml" ]] || return 1
}

@test "http repo add collision fails with actionable removal advice" {
  export VENDOR_HELM_RENDERED_REPO_URL="https://example.com/charts"
  export VENDOR_HELM_RENDERED_CHART_NAME="test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"
  export MOCK_HELM_REPO_ADD_FAILS="true"

  run_script
  [ "$status" -ne 0 ]
  # Echoes helm's own message and names the project-scoped alias in the advice.
  [[ "$output" == *"helm repo add failed for 'test-chart'"* ]] || return 1
  [[ "$output" == *"already exists"* ]] || return 1
  [[ "$output" == *"helm repo remove test-chart"* ]] || return 1
}

teardown() {
  dump_bats_result
}

# =============================================================================
# Stage 7: app / app.kubernetes.io/name identify the application, not the resource
# =============================================================================

@test "cluster-scoped resources get the project name as app, not their own name" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${MOVE_FILES_JSON}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  # ClusterRole is named test-chart-role in the chart; the app labels must
  # identify the application (the project), not the resource's own name.
  local cr_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrole.yaml"
  [[ -f "${cr_file}" ]] || return 1
  [[ $(yq eval '.metadata.name' "${cr_file}") == "test-chart-role" ]] || return 1
  [[ $(yq eval '.metadata.labels.app' "${cr_file}") == '${ProjectName}' ]] || return 1
  [[ $(yq eval '.metadata.labels."app.kubernetes.io/name"' "${cr_file}") == '${ProjectName}' ]] || return 1
}

@test "app labels never carry the environment token, even when the name does" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  # Test-local moveFiles: pull in the cluster-scoped resource whose name
  # templates .Release.Namespace (the case that leaked the namespace into
  # the app labels).
  export VENDOR_HELM_RENDERED_MOVE_FILES='[
    {"source":"templates/deployment.yaml","destination":"deployment.yaml"},
    {"source":"templates/clusterrole-namespaced.yaml","destination":"clusterrole-namespaced.yaml"}
  ]'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local cr_file="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/clusterrole-namespaced.yaml"
  [[ -f "${cr_file}" ]] || return 1

  # The name legitimately carries the environment token (the chart asked for
  # it); this proves the fixture exercises the sentinel sweep path.
  [[ $(yq eval '.metadata.name' "${cr_file}") == '${Environment}-test-chart-reader' ]] || return 1

  # The app labels must identify the application only - no namespace.
  [[ $(yq eval '.metadata.labels.app' "${cr_file}") == '${ProjectName}' ]] || return 1
  [[ $(yq eval '.metadata.labels."app.kubernetes.io/name"' "${cr_file}") == '${ProjectName}' ]] || return 1

  # Belt and braces across every rendered manifest.
  local manifest app_label name_label
  while IFS= read -r manifest; do
    app_label=$(yq eval '.metadata.labels.app // ""' "${manifest}")
    name_label=$(yq eval '.metadata.labels."app.kubernetes.io/name" // ""' "${manifest}")
    [[ "${app_label}" != *'${Environment}'* ]] || return 1
    [[ "${name_label}" != *'${Environment}'* ]] || return 1
  done < <(find "${REPO_DIR}/kaptain-out/helm-processing/G-annotated" -name '*.yaml' -type f)
}

@test "fullname sentinel resolves to the project-name token" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/configmap-fullname.yaml","destination":"configmap-fullname.yaml"}]'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local f="${REPO_DIR}/kaptain-out/helm-processing/G-annotated/configmap-fullname.yaml"
  # Swapped in names and in any other field the chart interpolated it into
  [[ $(yq eval '.metadata.name' "$f") == '${ProjectName}-config' ]] || return 1
  [[ $(yq eval '.data.owner' "$f") == '${ProjectName}' ]] || return 1
  [[ "$output" == *"fullnameOverride set to kaptain-fullname-placeholder"* ]] || return 1
}

@test "a truncated sentinel fragment fails the build" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/configmap-truncated.yaml","destination":"configmap-truncated.yaml"}]'

  run_script
  [[ "$status" -ne 0 ]] || return 1
  [[ "$output" == *"Sentinel fragments survived the sweep"* ]] || return 1
  [[ "$output" == *"configmap-truncated.yaml"* ]] || return 1
}

# =============================================================================
# Workload label closure: pod template app labels must equal metadata.name
# =============================================================================

WORKLOAD_MOVE_FILES='[
  {"source":"templates/deployment-worker.yaml","destination":"deployment-worker.yaml"},
  {"source":"templates/deployment-twin.yaml","destination":"deployment-twin.yaml"},
  {"source":"templates/service-worker.yaml","destination":"service-worker.yaml"},
  {"source":"templates/networkpolicy-spanning.yaml","destination":"networkpolicy-spanning.yaml"},
  {"source":"templates/service-by-name.yaml","destination":"service-by-name.yaml"},
  {"source":"templates/cronjob-worker.yaml","destination":"cronjob-worker.yaml"}
]'

annotated() { echo "${REPO_DIR}/kaptain-out/helm-processing/G-annotated/$1"; }

@test "closure: pod template app labels are set to the workload metadata.name" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${WORKLOAD_MOVE_FILES}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local f
  f=$(annotated deployment-worker.yaml)
  [[ $(yq eval '.spec.template.metadata.labels.app' "$f") == "test-chart-worker" ]] || return 1
  [[ $(yq eval '.spec.template.metadata.labels."app.kubernetes.io/name"' "$f") == "test-chart-worker" ]] || return 1
  # Chart's other identity labels are left alone
  [[ $(yq eval '.spec.template.metadata.labels."app.kubernetes.io/instance"' "$f") == "test-chart" ]] || return 1
  [[ $(yq eval '.spec.template.metadata.labels."app.kubernetes.io/component"' "$f") == "worker" ]] || return 1
}

@test "closure: workload selector is rewritten to match the pod template" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${WORKLOAD_MOVE_FILES}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local f
  f=$(annotated deployment-worker.yaml)
  [[ $(yq eval '.spec.selector.matchLabels."app.kubernetes.io/name"' "$f") == "test-chart-worker" ]] || return 1
  [[ $(yq eval '.spec.selector.matchLabels."app.kubernetes.io/instance"' "$f") == "test-chart" ]] || return 1
  # Keys the chart did not use must not be invented in a selector
  [[ $(yq eval '.spec.selector.matchLabels | has("app")' "$f") == "false" ]] || return 1
}

@test "closure: affinity and topology spread label selectors are rewritten" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${WORKLOAD_MOVE_FILES}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local f
  f=$(annotated deployment-worker.yaml)
  [[ $(yq eval '.spec.template.spec.topologySpreadConstraints[0].labelSelector.matchLabels."app.kubernetes.io/name"' "$f") == "test-chart-worker" ]] || return 1
  [[ $(yq eval '.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels."app.kubernetes.io/name"' "$f") == "test-chart-worker" ]] || return 1
}

@test "closure: a service selecting one workload has its selector rewritten" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${WORKLOAD_MOVE_FILES}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local f
  f=$(annotated service-worker.yaml)
  [[ $(yq eval '.spec.selector."app.kubernetes.io/name"' "$f") == "test-chart-worker" ]] || return 1
  [[ $(yq eval '.spec.selector."app.kubernetes.io/component"' "$f") == "worker" ]] || return 1
}

@test "closure: a spanning LabelSelector becomes a matchExpressions In list" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${WORKLOAD_MOVE_FILES}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local f
  f=$(annotated networkpolicy-spanning.yaml)
  # The shared app key moves into an In expression over both workloads...
  [[ $(yq eval '.spec.podSelector.matchExpressions[0].key' "$f") == "app.kubernetes.io/name" ]] || return 1
  [[ $(yq eval '.spec.podSelector.matchExpressions[0].operator' "$f") == "In" ]] || return 1
  [[ $(yq eval '.spec.podSelector.matchExpressions[0].values | sort | join(",")' "$f") == "test-chart-twin,test-chart-worker" ]] || return 1
  # ...while the other matchLabels keys stay where they were
  [[ $(yq eval '.spec.podSelector.matchLabels."app.kubernetes.io/instance"' "$f") == "test-chart" ]] || return 1
  [[ $(yq eval '.spec.podSelector.matchLabels | has("app.kubernetes.io/name")' "$f") == "false" ]] || return 1
}

@test "closure: CronJob is left entirely alone" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${WORKLOAD_MOVE_FILES}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  # Batch pods are owned directly, so no app label is needed to establish
  # ownership - the chart's own labels stay untouched.
  local f
  f=$(annotated cronjob-worker.yaml)
  [[ $(yq eval '.spec.jobTemplate.spec.template.metadata.labels."app.kubernetes.io/name"' "$f") == "upstream-chart" ]] || return 1
  [[ $(yq eval '.spec.jobTemplate.spec.template.metadata.labels | has("app")' "$f") == "false" ]] || return 1
  # Never write a selector for batch kinds - the controller owns it
  [[ $(yq eval '.spec.jobTemplate.spec | has("selector")' "$f") == "false" ]] || return 1
}

@test "closure: no rewrite when fullnameOverride is disabled, and validation fails" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${WORKLOAD_MOVE_FILES}"
  export VENDOR_HELM_RENDERED_USE_PROJECT_NAME_AS_FULLNAME_OVERRIDE="false"

  run_script
  # The chart's own labels do not satisfy the invariant, so the post-check fails
  [[ "$status" -ne 0 ]] || return 1
  [[ "$output" == *"test-chart-worker"* ]] || return 1
  [[ "$output" == *"app.kubernetes.io/name"* ]] || return 1
}

@test "closure: a selector naming a workload is honoured, not warned about" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES="${WORKLOAD_MOVE_FILES}"

  run_script
  [[ "$status" -eq 0 ]] || return 1

  # It matches no pod labels as written, but it names test-chart-worker, whose
  # pods now carry exactly that - so it resolves rather than warning.
  local f
  f=$(annotated service-by-name.yaml)
  [[ $(yq eval '.spec.selector."app.kubernetes.io/name"' "$f") == "test-chart-worker" ]] || return 1
  [[ "$output" == *"already names workload 'test-chart-worker'"* ]] || return 1
  [[ "$output" != *"test-chart-by-name"*"left unchanged"* ]] || return 1
}

@test "closure: a spanning Service that cannot be expressed fails the build" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  # Ship the spanning Service, which selects the shared chart label across two
  # workloads. A Service selector cannot express a set, so once pod labels are
  # per-workload it routes nowhere - the post-check must catch that.
  export VENDOR_HELM_RENDERED_MOVE_FILES='[
    {"source":"templates/deployment-worker.yaml","destination":"deployment-worker.yaml"},
    {"source":"templates/deployment-twin.yaml","destination":"deployment-twin.yaml"},
    {"source":"templates/service-spanning.yaml","destination":"service-spanning.yaml"}
  ]'

  run_script
  [[ "$status" -ne 0 ]] || return 1
  [[ "$output" == *"cannot express a set"* ]] || return 1
  [[ "$output" == *"matches no workload in this chart"* ]] || return 1
}

@test "closure: a spanning Service repointed by yqTransform passes" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[
    {"source":"templates/deployment-worker.yaml","destination":"deployment-worker.yaml"},
    {"source":"templates/deployment-twin.yaml","destination":"deployment-twin.yaml"},
    {"source":"templates/service-spanning.yaml","destination":"service-spanning.yaml"}
  ]'
  # The documented escape hatch: repoint at a label we never touch.
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"service-spanning.yaml","expressions":["del(.spec.selector.\"app.kubernetes.io/name\")"]}]}'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  local f
  f=$(annotated service-spanning.yaml)
  [[ $(yq eval '.spec.selector."app.kubernetes.io/instance"' "$f") == "test-chart" ]] || return 1
  [[ $(yq eval '.spec.selector | has("app.kubernetes.io/name")' "$f") == "false" ]] || return 1
}

@test "closure and the fullname sentinel compose to a token-consistent workload" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/deployment-sentinel.yaml","destination":"deployment-sentinel.yaml"}]'

  run_script
  [[ "$status" -eq 0 ]] || return 1

  # Normalisation runs before the sweep, so it writes the sentinel-based name
  # into the labels; the sweep then resolves name and labels together.
  local f
  f=$(annotated deployment-sentinel.yaml)
  [[ $(yq eval '.metadata.name' "$f") == '${ProjectName}' ]] || return 1
  [[ $(yq eval '.spec.template.metadata.labels.app' "$f") == '${ProjectName}' ]] || return 1
  [[ $(yq eval '.spec.template.metadata.labels."app.kubernetes.io/name"' "$f") == '${ProjectName}' ]] || return 1
  [[ $(yq eval '.spec.selector.matchLabels."app.kubernetes.io/name"' "$f") == '${ProjectName}' ]] || return 1
}

@test "closure: one app-style label is enough when normalisation is disabled" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/deployment-modern-only.yaml","destination":"deployment-modern-only.yaml"}]'
  export VENDOR_HELM_RENDERED_USE_PROJECT_NAME_AS_FULLNAME_OVERRIDE="false"

  run_script
  # Carries only app.kubernetes.io/name, which equals metadata.name - fine.
  [[ "$status" -eq 0 ]] || return 1

  # Untouched: no normalisation ran, so no legacy label was bolted on
  local f
  f=$(annotated deployment-modern-only.yaml)
  [[ $(yq eval '.spec.template.metadata.labels | has("app")' "$f") == "false" ]] || return 1
}

@test "closure: disagreeing app labels are rejected" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/deployment-disagree.yaml","destination":"deployment-disagree.yaml"}]'
  export VENDOR_HELM_RENDERED_USE_PROJECT_NAME_AS_FULLNAME_OVERRIDE="false"

  run_script
  [[ "$status" -ne 0 ]] || return 1
  [[ "$output" == *"pod template labels disagree"* ]] || return 1
}

@test "closure: a workload with no app-style label at all is rejected" {
  export VENDOR_HELM_RENDERED_OCI_CHART="oci://example.com/test-chart"
  # deployment-sentinel carries only app.kubernetes.io/name: upstream-chart, so
  # strip it to leave the pod template with no app-style label whatsoever.
  export VENDOR_HELM_RENDERED_MOVE_FILES='[{"source":"templates/deployment-sentinel.yaml","destination":"deployment-sentinel.yaml"}]'
  export VENDOR_HELM_RENDERED_USE_PROJECT_NAME_AS_FULLNAME_OVERRIDE="false"
  export VENDOR_HELM_RENDERED_YQ_TRANSFORM='{"perFile":[{"file":"deployment-sentinel.yaml","expressions":["del(.spec.template.metadata.labels)","del(.spec.selector)"]}]}'

  run_script
  [[ "$status" -ne 0 ]] || return 1
  [[ "$output" == *"carries neither 'app' nor 'app.kubernetes.io/name'"* ]] || return 1
}
