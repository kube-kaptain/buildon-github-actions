#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# environments.bash - Defaults for env (`run-*`) and run-platform
# (`run-platform-*`) build flows. See EnvFlow.md and RpFlow.md.
#
# ENV_* are env/RP-scope spec fields projected by load-final-kaptainpm-yaml.
# Unprefixed names are toggles for the workload stage and finalise.
#
# shellcheck disable=SC2034  # Variables used by sourcing scripts

# --- env/RP-scope spec field defaults (see spec.main.environment) ---

ENV_ALLOW_LOCAL_MANIFESTS_OVERRIDE="${ENV_ALLOW_LOCAL_MANIFESTS_OVERRIDE:-false}"
ENV_ENVIRONMENT_DEPLOY_SOURCE_BASE_PATH="${ENV_ENVIRONMENT_DEPLOY_SOURCE_BASE_PATH:-src/environment}"
ENV_GENERATE_IDEAL_ENVIRONMENT_DEPLOY_MANIFESTS="${ENV_GENERATE_IDEAL_ENVIRONMENT_DEPLOY_MANIFESTS:-true}"
# Matches the schema default. seed-and-compare emits the marker manifest
# whether defaulted or explicit.
ENV_IMAGE_DEPLOY_MANIFESTS_APPLY_MODE="${ENV_IMAGE_DEPLOY_MANIFESTS_APPLY_MODE:-seed-and-compare}"
ENV_DEPLOY_MODE="${ENV_DEPLOY_MODE:-deployment}"
# ENABLED | DISABLED (generate-mode only).
ENV_IMAGE_PULL_SECRETS="${ENV_IMAGE_PULL_SECRETS:-ENABLED}"
ENV_AUTO_GENERATE_IMAGE_PULL_SECRETS="${ENV_AUTO_GENERATE_IMAGE_PULL_SECRETS:-true}"
ENV_CHECKSUM_SECRETS_TIMING="${ENV_CHECKSUM_SECRETS_TIMING:-build}"

# No ENV_CLEAN_UP default here: kubernetes-run-aggregate applies the safe
# defaults when building the policy document, so the shipped document and
# the build cannot disagree.
ENV_IMAGE_AUTO_UPDATE_PROVIDER="${ENV_IMAGE_AUTO_UPDATE_PROVIDER:-keelson}"

# Policy 'force' is keel-only (schema and generation both check).
# Poll schedule is a single-unit duration, rendered per provider.
# Field-manager strategy is keelson-only.
ENV_IMAGE_AUTO_UPDATE_POLICY="${ENV_IMAGE_AUTO_UPDATE_POLICY:-patch}"
ENV_IMAGE_AUTO_UPDATE_TRIGGER="${ENV_IMAGE_AUTO_UPDATE_TRIGGER:-poll}"
ENV_IMAGE_AUTO_UPDATE_POLL_SCHEDULE="${ENV_IMAGE_AUTO_UPDATE_POLL_SCHEDULE:-1m}"
ENV_IMAGE_AUTO_UPDATE_FIELD_MANAGER_STRATEGY="${ENV_IMAGE_AUTO_UPDATE_FIELD_MANAGER_STRATEGY:-mimic}"

# Also the deploy permission model: 'self' gets cluster-admin RBAC and
# applies its own cluster-scoped resources; 'parent' gets namespace-admin
# RBAC and hands cluster-scoped resources to the run-platform via the
# on-behalf dir. Env-only; RP is always 'self'.
ENV_CLUSTER_SCOPED_DELEGATION="${ENV_CLUSTER_SCOPED_DELEGATION:-self}"

# Env image Dockerfile FROM, composed as
# '<registry>/[<namespace>/]image/image-environment-deploy-<family>:<version>'.
# INCLUDE_NAMESPACE=false drops the namespace segment. An explicit flag is
# used instead of an empty namespace because empty values do not survive
# GH env plumbing.
ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_REGISTRY="${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_REGISTRY:-ghcr.io}"
ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_INCLUDE_NAMESPACE="${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_INCLUDE_NAMESPACE:-true}"
ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_NAMESPACE="${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_NAMESPACE:-kube-kaptain}"
ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_FAMILY="${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_FAMILY:-trixie-slim}"
ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_VERSION="${ENV_ENVIRONMENT_DEPLOY_BASE_IMAGE_VERSION:-1.0.14.1.36.1}"

# --- workload finalise: signoff ---

MANIFESTS_SIGNOFFS_SUB_PATH="${MANIFESTS_SIGNOFFS_SUB_PATH:-src/signoffs}"
MANIFESTS_SIGNOFFS_KINDS_FILE="${MANIFESTS_SIGNOFFS_KINDS_FILE:-default-1.1.txt}"
MANIFESTS_TRUSTED_CONTRIBUTORS_ONLY="${MANIFESTS_TRUSTED_CONTRIBUTORS_ONLY:-false}"

# --- workload finalise: secrets ---

# Env-only: checksum_secrets runs on *.template.yaml Secrets when this
# directory exists. Both are spec.global projections.
SECRETS_SUB_PATH="${SECRETS_SUB_PATH:-src/secrets}"
CONFIG_SUB_PATH="${CONFIG_SUB_PATH:-src/config}"

# Config/secret value files no token references. true fails (local builds
# warn); false warns. Child defaults are exempt as permitted fallbacks.
ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS="${ENV_FAIL_ON_UNREFERENCED_CONFIG_OR_SECRETS:-true}"

# --- workload finalise: resource checksum ---

# Applies to resource names ending '-checksum'. Base32 suffix length:
# warn <4 or >12, fail >52.
RESOURCE_CHECKSUM_LENGTH="${RESOURCE_CHECKSUM_LENGTH:-5}"

# Versioned file names in fixed src/data/ sub dirs. The selected file
# replaces the list (no merge).
MANIFESTS_CHECKSUM_ORDER_FILE="${MANIFESTS_CHECKSUM_ORDER_FILE:-default-1.1.txt}"
# Drives the clusterScopedDelegation=parent carve-out.
MANIFESTS_CLUSTER_SCOPED_KINDS_FILE="${MANIFESTS_CLUSTER_SCOPED_KINDS_FILE:-default-1.1.txt}"
