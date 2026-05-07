#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Tests for kubernetes-metadata.bash library

load helpers

setup() {
  source "$LIB_DIR/kubernetes-metadata.bash"
}

# =============================================================================
# generate_manifest_header
# =============================================================================

@test "generate_manifest_header: 3 args - no namespace (cluster-scoped)" {
  result=$(generate_manifest_header "v1" "Namespace" "production")
  [[ "$result" == *"apiVersion: v1"* ]]
  [[ "$result" == *"kind: Namespace"* ]]
  [[ "$result" == *"name: production"* ]]
  [[ "$result" != *"namespace:"* ]]
}

@test "generate_manifest_header: 4 args - with namespace" {
  result=$(generate_manifest_header "v1" "ConfigMap" "my-config" "default")
  [[ "$result" == *"apiVersion: v1"* ]]
  [[ "$result" == *"kind: ConfigMap"* ]]
  [[ "$result" == *"name: my-config"* ]]
  [[ "$result" == *"namespace: default"* ]]
}

@test "generate_manifest_header: handles token references in name" {
  result=$(generate_manifest_header "v1" "ConfigMap" '${ProjectName}-configmap' '${Environment}')
  [[ "$result" == *'name: ${ProjectName}-configmap'* ]]
  [[ "$result" == *'namespace: ${Environment}'* ]]
}

@test "generate_manifest_header: correct indentation" {
  result=$(generate_manifest_header "v1" "ConfigMap" "my-config" "default")
  # metadata: should have no leading spaces
  [[ "$result" == *$'\n'"metadata:"* ]]
  # name: should have 2 leading spaces
  [[ "$result" == *$'\n'"  name:"* ]]
  # namespace: should have 2 leading spaces
  [[ "$result" == *$'\n'"  namespace:"* ]]
}

@test "generate_manifest_header: fails with 0 args" {
  run generate_manifest_header
  [ "$status" -ne 0 ]
}

@test "generate_manifest_header: fails with 1 arg" {
  run generate_manifest_header "v1"
  [ "$status" -ne 0 ]
}

@test "generate_manifest_header: fails with 2 args" {
  run generate_manifest_header "v1" "ConfigMap"
  [ "$status" -ne 0 ]
}

@test "generate_manifest_header: fails with 5 args" {
  run generate_manifest_header "v1" "ConfigMap" "name" "ns" "extra"
  [ "$status" -ne 0 ]
}

@test "generate_manifest_header: apps/v1 Deployment" {
  result=$(generate_manifest_header "apps/v1" "Deployment" "my-app" "production")
  [[ "$result" == *"apiVersion: apps/v1"* ]]
  [[ "$result" == *"kind: Deployment"* ]]
}

# =============================================================================
# merge_key_value_pairs
# =============================================================================

@test "merge_key_value_pairs: empty base, empty override" {
  result=$(merge_key_value_pairs "" "")
  [ "$result" = "" ]
}

@test "merge_key_value_pairs: base only, empty override" {
  result=$(merge_key_value_pairs "app=foo,version=1" "")
  [[ "$result" == *"app=foo"* ]]
  [[ "$result" == *"version=1"* ]]
}

@test "merge_key_value_pairs: empty base, override only" {
  result=$(merge_key_value_pairs "" "team=platform")
  [ "$result" = "team=platform" ]
}

@test "merge_key_value_pairs: override replaces base" {
  result=$(merge_key_value_pairs "version=1" "version=2")
  [[ "$result" == *"version=2"* ]]
  [[ "$result" != *"version=1"* ]]
}

@test "merge_key_value_pairs: preserves non-overridden keys" {
  result=$(merge_key_value_pairs "app=foo,version=1" "version=2")
  [[ "$result" == *"app=foo"* ]]
  [[ "$result" == *"version=2"* ]]
}

@test "merge_key_value_pairs: adds new keys from override" {
  result=$(merge_key_value_pairs "app=foo" "team=platform")
  [[ "$result" == *"app=foo"* ]]
  [[ "$result" == *"team=platform"* ]]
}

@test "merge_key_value_pairs: handles multiple overrides" {
  result=$(merge_key_value_pairs "a=1,b=2,c=3" "b=22,c=33,d=4")
  [[ "$result" == *"a=1"* ]]
  [[ "$result" == *"b=22"* ]]
  [[ "$result" == *"c=33"* ]]
  [[ "$result" == *"d=4"* ]]
}

@test "merge_key_value_pairs: handles values with special characters" {
  result=$(merge_key_value_pairs 'url=http://example.com' "")
  [[ "$result" == *"url=http://example.com"* ]]
}

@test "merge_key_value_pairs: handles kubernetes label keys with slashes" {
  result=$(merge_key_value_pairs "app.kubernetes.io/name=foo" "app.kubernetes.io/version=1.0")
  [[ "$result" == *"app.kubernetes.io/name=foo"* ]]
  [[ "$result" == *"app.kubernetes.io/version=1.0"* ]]
}

@test "merge_key_value_pairs: fails on malformed pair without equals sign" {
  run merge_key_value_pairs "key: value" ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"must contain '='"* ]]
}

@test "merge_key_value_pairs: fails on malformed pair in override" {
  run merge_key_value_pairs "valid=pair" "invalid: pair"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must contain '='"* ]]
}

# =============================================================================
# generate_yaml_map
# =============================================================================

@test "generate_yaml_map: basic output with no indent" {
  result=$(generate_yaml_map 0 "labels" "app=foo")
  [[ "$result" == "labels:"* ]]
  [[ "$result" == *$'\n'"  app: foo"* ]]
}

@test "generate_yaml_map: 2-space indent" {
  result=$(generate_yaml_map 2 "labels" "app=foo")
  [[ "$result" == "  labels:"* ]]
  [[ "$result" == *$'\n'"    app: foo"* ]]
}

@test "generate_yaml_map: 4-space indent" {
  result=$(generate_yaml_map 4 "resources" "cpu=100m")
  [[ "$result" == "    resources:"* ]]
  [[ "$result" == *$'\n'"      cpu: 100m"* ]]
}

@test "generate_yaml_map: multiple entries" {
  result=$(generate_yaml_map 0 "labels" "app=foo,version=1,team=platform")
  [[ "$result" == *"app: foo"* ]]
  [[ "$result" == *"version: 1"* ]]
  [[ "$result" == *"team: platform"* ]]
}

@test "generate_yaml_map: handles token references" {
  result=$(generate_yaml_map 0 "labels" 'app=${ProjectName}')
  [[ "$result" == *'app: ${ProjectName}'* ]]
}

@test "generate_yaml_map: handles quoted values" {
  result=$(generate_yaml_map 0 "annotations" 'msg="Hello World"')
  [[ "$result" == *'msg: "Hello World"'* ]]
}

@test "generate_yaml_map: handles kubernetes.io keys" {
  result=$(generate_yaml_map 0 "labels" "app.kubernetes.io/name=foo,app.kubernetes.io/version=1.0")
  [[ "$result" == *"app.kubernetes.io/name: foo"* ]]
  [[ "$result" == *"app.kubernetes.io/version: 1.0"* ]]
}

@test "generate_yaml_map: empty pairs outputs nothing" {
  result=$(generate_yaml_map 0 "labels" "")
  [ -z "$result" ]
}

# =============================================================================
# generate_metadata_map
# =============================================================================

@test "generate_metadata_map: uses 2-space indent" {
  result=$(generate_metadata_map "labels" "app=foo")
  [[ "$result" == "  labels:"* ]]
  [[ "$result" == *$'\n'"    app: foo"* ]]
}

@test "generate_metadata_map: multiple labels" {
  result=$(generate_metadata_map "labels" "app=foo,version=1")
  [[ "$result" == *"app: foo"* ]]
  [[ "$result" == *"version: 1"* ]]
}

@test "generate_metadata_map: annotations" {
  result=$(generate_metadata_map "annotations" "kaptain.org/version=1.0")
  [[ "$result" == "  annotations:"* ]]
  [[ "$result" == *"kaptain.org/version: 1.0"* ]]
}

@test "generate_metadata_map: empty pairs outputs nothing" {
  result=$(generate_metadata_map "labels" "")
  [ -z "$result" ]
}

# =============================================================================
# build_name_middle_fragment
# =============================================================================

@test "build_name_middle_fragment: path and suffix" {
  result=$(build_name_middle_fragment "backend/redis" "cache")
  [ "$result" = "-backend-redis-cache" ]
}

@test "build_name_middle_fragment: path only" {
  result=$(build_name_middle_fragment "backend/redis" "")
  [ "$result" = "-backend-redis" ]
}

@test "build_name_middle_fragment: suffix only" {
  result=$(build_name_middle_fragment "" "worker")
  [ "$result" = "-worker" ]
}

@test "build_name_middle_fragment: empty path and suffix" {
  result=$(build_name_middle_fragment "" "")
  [ "$result" = "" ]
}

@test "build_name_middle_fragment: deep path" {
  result=$(build_name_middle_fragment "services/backend/api/v2" "main")
  [ "$result" = "-services-backend-api-v2-main" ]
}

@test "build_name_middle_fragment: fails with wrong arg count" {
  run build_name_middle_fragment "only-one"
  [ "$status" -ne 0 ]
}

# =============================================================================
# build_resource_name
# =============================================================================

@test "build_resource_name: all parts including final suffix" {
  result=$(build_resource_name '${ProjectName}' "backend/redis" "cache" "configmap-checksum")
  [ "$result" = '${ProjectName}-backend-redis-cache-configmap-checksum' ]
}

@test "build_resource_name: path and suffix without final" {
  result=$(build_resource_name '${ProjectName}' "backend/redis" "cache" "")
  [ "$result" = '${ProjectName}-backend-redis-cache' ]
}

@test "build_resource_name: path and suffix, 3 args" {
  result=$(build_resource_name '${ProjectName}' "backend/redis" "cache")
  [ "$result" = '${ProjectName}-backend-redis-cache' ]
}

@test "build_resource_name: suffix and final only" {
  result=$(build_resource_name '${ProjectName}' "" "worker" "secret-checksum")
  [ "$result" = '${ProjectName}-worker-secret-checksum' ]
}

@test "build_resource_name: final suffix only" {
  result=$(build_resource_name '${ProjectName}' "" "" "headless")
  [ "$result" = '${ProjectName}-headless' ]
}

@test "build_resource_name: project name only" {
  result=$(build_resource_name '${ProjectName}' "" "" "")
  [ "$result" = '${ProjectName}' ]
}

@test "build_resource_name: project name only, 3 args" {
  result=$(build_resource_name '${ProjectName}' "" "")
  [ "$result" = '${ProjectName}' ]
}

@test "build_resource_name: path only with final" {
  result=$(build_resource_name '${ProjectName}' "services/api" "" "configmap-checksum")
  [ "$result" = '${ProjectName}-services-api-configmap-checksum' ]
}

@test "build_resource_name: fails with 2 args" {
  run build_resource_name '${ProjectName}' "path"
  [ "$status" -ne 0 ]
}

@test "build_resource_name: fails with 5 args" {
  run build_resource_name '${ProjectName}' "path" "suffix" "final" "extra"
  [ "$status" -ne 0 ]
}

# =============================================================================
# build_output_filename
# =============================================================================

@test "build_output_filename: with suffix" {
  result=$(build_output_filename "target/manifests/combined" "deployment" "cache")
  [ "$result" = "target/manifests/combined/deployment-cache.yaml" ]
}

@test "build_output_filename: without suffix" {
  result=$(build_output_filename "target/manifests/combined" "deployment" "")
  [ "$result" = "target/manifests/combined/deployment.yaml" ]
}

@test "build_output_filename: service headless" {
  result=$(build_output_filename "target/manifests/combined" "service" "headless")
  [ "$result" = "target/manifests/combined/service-headless.yaml" ]
}

@test "build_output_filename: statefulset with suffix" {
  result=$(build_output_filename "target/manifests/combined/backend/redis" "statefulset" "db")
  [ "$result" = "target/manifests/combined/backend/redis/statefulset-db.yaml" ]
}

@test "build_output_filename: uppercase kind is lowercased" {
  result=$(build_output_filename "target/manifests/combined" "Deployment" "worker")
  [ "$result" = "target/manifests/combined/deployment-worker.yaml" ]
}

@test "build_output_filename: mixed case StatefulSet" {
  result=$(build_output_filename "target/manifests/combined" "StatefulSet" "")
  [ "$result" = "target/manifests/combined/statefulset.yaml" ]
}

@test "build_output_filename: fails with 2 args" {
  run build_output_filename "dir" "type"
  [ "$status" -ne 0 ]
}

@test "build_output_filename: custom extension with suffix" {
  result=$(build_output_filename "target/manifests/combined" "Secret" "db" "template.yaml")
  [ "$result" = "target/manifests/combined/secret-db.template.yaml" ]
}

@test "build_output_filename: custom extension without suffix" {
  result=$(build_output_filename "target/manifests/combined" "Secret" "" "template.yaml")
  [ "$result" = "target/manifests/combined/secret.template.yaml" ]
}

@test "build_output_filename: fails with 5 args" {
  run build_output_filename "dir" "type" "suffix" "ext" "extra"
  [ "$status" -ne 0 ]
}

# =============================================================================
# generate_metadata - labels
# =============================================================================

# Helper: populate caller-scope vars expected by generate_metadata
metadata_caller_scope() {
  project_name_token='${ProjectName}'
  app_name='${ProjectName}'
  version_token='${Version}'
  environment_token='${Environment}'
  product_token='${ProductName}'
  build_timestamp='2026-04-29T00:00:00Z'
  script_name='generate-kubernetes-thing'
  GLOBAL_LABELS=''
  SPECIFIC_LABELS=''
  GLOBAL_ANNOTATIONS=''
  SPECIFIC_ANNOTATIONS=''
}

@test "generate_metadata labels: emits full superset when REPOSITORY_OWNER set" {
  metadata_caller_scope
  export REPOSITORY_OWNER="kube-kaptain"

  result=$(generate_metadata 2 labels)

  [[ "$result" == *'app: ${ProjectName}'* ]]
  [[ "$result" == *'app.kubernetes.io/name: ${ProjectName}'* ]]
  [[ "$result" == *'app.kubernetes.io/version: "${Version}"'* ]]
  [[ "$result" == *'app.kubernetes.io/managed-by: Kaptain'* ]]
  [[ "$result" == *'kaptain.org/version: "${Version}"'* ]]
  [[ "$result" == *'kaptain.org/project-name: ${ProjectName}'* ]]
  [[ "$result" == *'kaptain.org/environment: ${Environment}'* ]]
  [[ "$result" == *'kaptain.org/product: ${ProductName}'* ]]
  [[ "$result" == *'kaptain.org/owner: kube-kaptain'* ]]
}

@test "generate_metadata labels: kaptain.org/environment emitted unconditionally (deploy-time token)" {
  metadata_caller_scope
  unset REPOSITORY_OWNER

  result=$(generate_metadata 2 labels)

  [[ "$result" == *'kaptain.org/environment: ${Environment}'* ]]
}

@test "generate_metadata labels: kaptain.org/product emitted unconditionally (deploy-time token)" {
  metadata_caller_scope
  unset REPOSITORY_OWNER

  result=$(generate_metadata 2 labels)

  [[ "$result" == *'kaptain.org/product: ${ProductName}'* ]]
}

@test "generate_metadata labels: omits kaptain.org/owner when REPOSITORY_OWNER unset" {
  metadata_caller_scope
  unset REPOSITORY_OWNER

  result=$(generate_metadata 2 labels)

  [[ "$result" != *'kaptain.org/owner'* ]]
  [[ "$result" == *'kaptain.org/version: "${Version}"'* ]]
  [[ "$result" == *'kaptain.org/project-name: ${ProjectName}'* ]]
}

@test "generate_metadata labels: omits kaptain.org/owner when REPOSITORY_OWNER empty" {
  metadata_caller_scope
  export REPOSITORY_OWNER=""

  result=$(generate_metadata 2 labels)

  [[ "$result" != *'kaptain.org/owner'* ]]
}

# =============================================================================
# generate_metadata - annotations
# =============================================================================

@test "generate_metadata annotations: emits full superset when all env vars set" {
  metadata_caller_scope
  export REPOSITORY_OWNER="kube-kaptain"
  export BUILD_PLATFORM="github-actions"
  export SOURCE_REPO="kube-kaptain/test-project"
  export IMAGE_URI="ghcr.io/kube-kaptain/test-project:1.0.0"

  result=$(generate_metadata 2 annotations)

  [[ "$result" != *'kaptain.org/project-name'* ]]
  [[ "$result" != *'kaptain.org/version'* ]]
  [[ "$result" == *'kaptain.org/build-timestamp: "2026-04-29T00:00:00Z"'* ]]
  [[ "$result" == *'kaptain.org/generated-by: "Generated by Kaptain generate-kubernetes-thing"'* ]]
  [[ "$result" == *'kaptain.org/built-by: github-actions'* ]]
  [[ "$result" == *'kaptain.org/source-repository: kube-kaptain/test-project'* ]]
  [[ "$result" == *'kaptain.org/image-uri: ghcr.io/kube-kaptain/test-project:1.0.0'* ]]
}

@test "generate_metadata annotations: omits env-conditional keys when env vars unset" {
  metadata_caller_scope
  unset BUILD_PLATFORM SOURCE_REPO IMAGE_URI

  result=$(generate_metadata 2 annotations)

  [[ "$result" != *'kaptain.org/built-by'* ]]
  [[ "$result" != *'kaptain.org/source-repository'* ]]
  [[ "$result" != *'kaptain.org/image-uri'* ]]

  # project-name and version live on labels only, not annotations
  [[ "$result" != *'kaptain.org/project-name'* ]]
  [[ "$result" != *'kaptain.org/version'* ]]

  # Required keys must still emit
  [[ "$result" == *'kaptain.org/build-timestamp: "2026-04-29T00:00:00Z"'* ]]
  [[ "$result" == *'kaptain.org/generated-by: "Generated by Kaptain generate-kubernetes-thing"'* ]]
}

@test "generate_metadata annotations: each env-conditional key flips independently" {
  metadata_caller_scope
  unset SOURCE_REPO IMAGE_URI
  export BUILD_PLATFORM="github-actions"

  result=$(generate_metadata 2 annotations)

  [[ "$result" == *'kaptain.org/built-by: github-actions'* ]]
  [[ "$result" != *'kaptain.org/source-repository'* ]]
  [[ "$result" != *'kaptain.org/image-uri'* ]]
}

@test "generate_metadata annotations: includes default-container when arg passed" {
  metadata_caller_scope

  result=$(generate_metadata 2 annotations my-container)

  [[ "$result" == *'kubectl.kubernetes.io/default-container: my-container'* ]]
}

@test "generate_metadata annotations: omits default-container when arg not passed" {
  metadata_caller_scope

  result=$(generate_metadata 2 annotations)

  [[ "$result" != *'kubectl.kubernetes.io/default-container'* ]]
}

@test "generate_metadata: fails with 0 args" {
  metadata_caller_scope
  run generate_metadata
  [ "$status" -ne 0 ]
}

@test "generate_metadata: fails with invalid type" {
  metadata_caller_scope
  run generate_metadata 2 invalid-type
  [ "$status" -ne 0 ]
}


teardown() {
  dump_bats_result
}
