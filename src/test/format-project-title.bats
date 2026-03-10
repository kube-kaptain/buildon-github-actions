#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)

load helpers

# === Basic title casing ===

@test "title cases regular words" {
  run "$UTIL_DIR/format-project-title" "hello-world"
  [ "$status" -eq 0 ]
  [ "$output" = "Hello World" ]
}

@test "single word is title cased" {
  run "$UTIL_DIR/format-project-title" "kaptain"
  [ "$status" -eq 0 ]
  [ "$output" = "Kaptain" ]
}

# === Cloud provider acronyms ===

@test "aws is uppercased" {
  run "$UTIL_DIR/format-project-title" "aws-tools"
  [ "$status" -eq 0 ]
  [ "$output" = "AWS Tools" ]
}

@test "gcp is uppercased" {
  run "$UTIL_DIR/format-project-title" "gcp-tools"
  [ "$status" -eq 0 ]
  [ "$output" = "GCP Tools" ]
}

@test "eks is uppercased" {
  run "$UTIL_DIR/format-project-title" "aws-eks-cluster-management"
  [ "$status" -eq 0 ]
  [ "$output" = "AWS EKS Cluster Management" ]
}

@test "aks is uppercased" {
  run "$UTIL_DIR/format-project-title" "aks-cluster-setup"
  [ "$status" -eq 0 ]
  [ "$output" = "AKS Cluster Setup" ]
}

@test "gke is uppercased" {
  run "$UTIL_DIR/format-project-title" "gcp-gke-autopilot"
  [ "$status" -eq 0 ]
  [ "$output" = "GCP GKE Autopilot" ]
}

@test "ec2 is uppercased" {
  run "$UTIL_DIR/format-project-title" "aws-ec2-instance-manager"
  [ "$status" -eq 0 ]
  [ "$output" = "AWS EC2 Instance Manager" ]
}

@test "ecr is uppercased" {
  run "$UTIL_DIR/format-project-title" "aws-ecr-cleanup"
  [ "$status" -eq 0 ]
  [ "$output" = "AWS ECR Cleanup" ]
}

@test "s3 is uppercased" {
  run "$UTIL_DIR/format-project-title" "aws-s3-backup"
  [ "$status" -eq 0 ]
  [ "$output" = "AWS S3 Backup" ]
}

@test "iam is uppercased" {
  run "$UTIL_DIR/format-project-title" "aws-iam-roles"
  [ "$status" -eq 0 ]
  [ "$output" = "AWS IAM Roles" ]
}

@test "vpc is uppercased" {
  run "$UTIL_DIR/format-project-title" "aws-vpc-setup"
  [ "$status" -eq 0 ]
  [ "$output" = "AWS VPC Setup" ]
}

# === Software acronyms ===

@test "api is uppercased" {
  run "$UTIL_DIR/format-project-title" "rest-api-server"
  [ "$status" -eq 0 ]
  [ "$output" = "Rest API Server" ]
}

@test "cli is uppercased" {
  run "$UTIL_DIR/format-project-title" "kaptain-cli"
  [ "$status" -eq 0 ]
  [ "$output" = "Kaptain CLI" ]
}

@test "sdk is uppercased" {
  run "$UTIL_DIR/format-project-title" "kaptain-sdk"
  [ "$status" -eq 0 ]
  [ "$output" = "Kaptain SDK" ]
}

@test "ci and cd are uppercased" {
  run "$UTIL_DIR/format-project-title" "ci-cd-pipeline"
  [ "$status" -eq 0 ]
  [ "$output" = "CI CD Pipeline" ]
}

@test "oci is uppercased" {
  run "$UTIL_DIR/format-project-title" "oci-image-builder"
  [ "$status" -eq 0 ]
  [ "$output" = "OCI Image Builder" ]
}

# === Protocol and format acronyms ===

@test "dns and ssl are uppercased" {
  run "$UTIL_DIR/format-project-title" "dns-ssl-manager"
  [ "$status" -eq 0 ]
  [ "$output" = "DNS SSL Manager" ]
}

@test "json and yaml are uppercased" {
  run "$UTIL_DIR/format-project-title" "json-yaml-converter"
  [ "$status" -eq 0 ]
  [ "$output" = "JSON YAML Converter" ]
}

@test "jwt is uppercased" {
  run "$UTIL_DIR/format-project-title" "jwt-auth-provider"
  [ "$status" -eq 0 ]
  [ "$output" = "JWT Auth Provider" ]
}

# === Special casing ===

@test "github has special casing" {
  run "$UTIL_DIR/format-project-title" "buildon-github-actions"
  [ "$status" -eq 0 ]
  [ "$output" = "Buildon GitHub Actions" ]
}

@test "devops has special casing" {
  run "$UTIL_DIR/format-project-title" "devops-toolkit"
  [ "$status" -eq 0 ]
  [ "$output" = "DevOps Toolkit" ]
}

@test "k8s has special casing" {
  run "$UTIL_DIR/format-project-title" "k8s-cluster-tools"
  [ "$status" -eq 0 ]
  [ "$output" = "K8s Cluster Tools" ]
}

@test "sre is uppercased" {
  run "$UTIL_DIR/format-project-title" "sre-platform-tools"
  [ "$status" -eq 0 ]
  [ "$output" = "SRE Platform Tools" ]
}

@test "lts is uppercased" {
  run "$UTIL_DIR/format-project-title" "image-environment-base-ubuntu-24-04-lts"
  [ "$status" -eq 0 ]
  [ "$output" = "Image Environment Base Ubuntu 24 04 LTS" ]
}

# === Mixed acronyms and regular words ===

@test "multiple acronyms in one title" {
  run "$UTIL_DIR/format-project-title" "aws-eks-iam-vpc-setup"
  [ "$status" -eq 0 ]
  [ "$output" = "AWS EKS IAM VPC Setup" ]
}

@test "git is naturally title cased" {
  run "$UTIL_DIR/format-project-title" "git-workflow-tools"
  [ "$status" -eq 0 ]
  [ "$output" = "Git Workflow Tools" ]
}

# === Error handling ===

@test "fails without arguments" {
  run "$UTIL_DIR/format-project-title"
  [ "$status" -ne 0 ]
}
