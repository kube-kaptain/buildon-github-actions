# Build On GitHub Actions

Reusable GitHub Actions for CI/CD pipelines with quality enforcement and automatic versioning.

## Features

- **Quality enforcement** - Block GitHub UI branch names, default commit messages, merge commits, unrebased branches
- **Automatic versioning** - Semantic version tags based on git history, supports any number of version parts
- **Patch branch support** - Configure additional release branches for hotfix workflows

## Quick Start

Reference the reusable workflow from your repo:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: kube-kaptain/buildon-github-actions/.github/workflows/basic-quality-and-versioning.yaml@v1
    permissions:
      contents: write
```

See [`examples/`](examples/) for more usage patterns.

## Examples

<!-- EXAMPLES-START -->
| Example | Description |
|---------|-------------|
| [`aws-eks-cluster-management.yaml`](examples/aws-eks-cluster-management.yaml) | Builds an EKS cluster management image with kubectl and AWS CLI baked in |
| [`basic-quality-and-versioning.yaml`](examples/basic-quality-and-versioning.yaml) | Quality checks plus automatic version tagging |
| [`basic-quality-checks.yaml`](examples/basic-quality-checks.yaml) | Enforces branch naming, commit message, and branch structure standards on PRs |
| [`docker-build-dockerfile.yaml`](examples/docker-build-dockerfile.yaml) | Builds a Docker image from src/docker/Dockerfile with layer squashing |
| [`docker-build-retag.yaml`](examples/docker-build-retag.yaml) | Pulls an upstream image, retags with your name and version, pushes to your |
| [`kubernetes-app-docker-dockerfile.yaml`](examples/kubernetes-app-docker-dockerfile.yaml) | Full Kubernetes application pipeline |
| [`kubernetes-app-docker-retag.yaml`](examples/kubernetes-app-docker-retag.yaml) | Kubernetes application pipeline using an upstream image |
| [`kubernetes-app-manifests-only.yaml`](examples/kubernetes-app-manifests-only.yaml) | Packages Kubernetes manifests without building a Docker image |
| [`spec-check-filter-release.yaml`](examples/spec-check-filter-release.yaml) | Validates and packages spec/schema files as OCI artifacts |

### Guides

| Guide | README | build.yaml | KaptainPM.yaml |
|-------|--------|------------|----------------|
| `build-hooks` | [README](examples/guides/build-hooks/README.md) | [build.yaml](examples/guides/build-hooks/build.yaml) | [KaptainPM.yaml](examples/guides/build-hooks/KaptainPM.yaml) |
| `custom-registry-logins` | [README](examples/guides/custom-registry-logins/README.md) | [build.yaml](examples/guides/custom-registry-logins/build.yaml) | [KaptainPM.yaml](examples/guides/custom-registry-logins/KaptainPM.yaml) |
| `custom-target-registry` | [README](examples/guides/custom-target-registry/README.md) | [build.yaml](examples/guides/custom-target-registry/build.yaml) | [KaptainPM.yaml](examples/guides/custom-target-registry/KaptainPM.yaml) |
| `ghcr-pat-auth` | [README](examples/guides/ghcr-pat-auth/README.md) | [build.yaml](examples/guides/ghcr-pat-auth/build.yaml) | [KaptainPM.yaml](examples/guides/ghcr-pat-auth/KaptainPM.yaml) |
| `github-release-options` | [README](examples/guides/github-release-options/README.md) | [build.yaml](examples/guides/github-release-options/build.yaml) | [KaptainPM.yaml](examples/guides/github-release-options/KaptainPM.yaml) |
| `kubernetes-generators` | [README](examples/guides/kubernetes-generators/README.md) | [build.yaml](examples/guides/kubernetes-generators/build.yaml) | [KaptainPM.yaml](examples/guides/kubernetes-generators/KaptainPM.yaml) |
| `manifests-only-external-image` | [README](examples/guides/manifests-only-external-image/README.md) | [build.yaml](examples/guides/manifests-only-external-image/build.yaml) | [KaptainPM.yaml](examples/guides/manifests-only-external-image/KaptainPM.yaml) |
| `multi-registry-push` | [README](examples/guides/multi-registry-push/README.md) | [build.yaml](examples/guides/multi-registry-push/build.yaml) | [KaptainPM.yaml](examples/guides/multi-registry-push/KaptainPM.yaml) |
| `release-branches` | [README](examples/guides/release-branches/README.md) | [build.yaml](examples/guides/release-branches/build.yaml) | [KaptainPM.yaml](examples/guides/release-branches/KaptainPM.yaml) |
| `retag-upstream-image` | [README](examples/guides/retag-upstream-image/README.md) | [build.yaml](examples/guides/retag-upstream-image/build.yaml) | [KaptainPM.yaml](examples/guides/retag-upstream-image/KaptainPM.yaml) |
| `token-substitution` | [README](examples/guides/token-substitution/README.md) | [build.yaml](examples/guides/token-substitution/build.yaml) | [KaptainPM.yaml](examples/guides/token-substitution/KaptainPM.yaml) |
| `version-compound-sources` | [README](examples/guides/version-compound-sources/README.md) | [build.yaml](examples/guides/version-compound-sources/build.yaml) | [KaptainPM.yaml](examples/guides/version-compound-sources/KaptainPM.yaml) |
| `version-from-custom-pattern` | [README](examples/guides/version-from-custom-pattern/README.md) | [build.yaml](examples/guides/version-from-custom-pattern/build.yaml) | [KaptainPM.yaml](examples/guides/version-from-custom-pattern/KaptainPM.yaml) |
| `version-from-file` | [README](examples/guides/version-from-file/README.md) | [build.yaml](examples/guides/version-from-file/build.yaml) | [KaptainPM.yaml](examples/guides/version-from-file/KaptainPM.yaml) |
| `version-prefix-parts` | [README](examples/guides/version-prefix-parts/README.md) | [build.yaml](examples/guides/version-prefix-parts/build.yaml) | [KaptainPM.yaml](examples/guides/version-prefix-parts/KaptainPM.yaml) |
<!-- EXAMPLES-END -->

## Components

### Workflows

<!-- WORKFLOWS-START -->
| Workflow | Description |
|----------|-------------|
| `basic-quality-checks.yaml` | Enforces basic quality - blocks bad branch names, bad commit messages, and bad branch structure |
| `basic-quality-and-versioning.yaml` | Quality checks and naming/versioning combined - the standard foundation for most projects |
| `docker-build-dockerfile.yaml` | Everything from quality and versions above, but also builds a docker image from a Dockerfile |
| `aws-eks-cluster-management.yaml` | Everything from docker Dockerfile build plus EKS cluster config generation and three-phase validation |
| `docker-build-retag.yaml` | Everything from quality and version above, but also pulls, retags, and republishes a docker image |
| `kubernetes-app-manifests-only.yaml` | Everything from quality and version above, plus packages Kubernetes manifests with token substitution |
| `kubernetes-bundle-resources.yaml` | Packages pre-existing kubernetes manifests from src/kubernetes/ with token substitution, no generators |
| `kubernetes-bundle-vendor-helm-rendered.yaml` | Renders a vendor helm chart into individual manifests, processes and validates them, then packages with token substitution |
| `kubernetes-app-docker-dockerfile.yaml` | Everything from both docker Dockerfile and Kubernetes manifest packaging - a full kube app build |
| `kubernetes-bundle-docker-retag.yaml` | Packages pre-existing kubernetes manifests from src/kubernetes/ with token substitution and retags an upstream docker image - for apps using upstream images with hand-maintained manifests |
| `layer-and-layerset-build.yaml` | Layer/layerset validation and OCI packaging - quality checks, versioning, layer packaging, Docker build, validation, and release publishing |
| `kubernetes-app-docker-retag.yaml` | Everything from both docker retag and Kubernetes manifest packaging - for apps using upstream images |
| `spec-check-filter-release.yaml` | Everything from quality and version above, but also validates and packages a JSON Schema or an API Spec |
<!-- WORKFLOWS-END -->

### Actions

<!-- ACTIONS-START -->
| Action | Description |
|--------|-------------|
| `aws-eks-cluster-management-post-build-validate` | Validate substituted cluster yaml and image integrity after docker build |
| `aws-eks-cluster-management-pre-build-validate` | Validate cluster yaml token placement before docker build |
| `aws-eks-cluster-management-prepare` | Generate EKS cluster config and Dockerfile for cluster management image |
| `basic-quality-checks` | Basic quality checks for commits and branches |
| `change-source-note-write` | Writes merge candidate metadata as a git note for release tracking |
| `docker-build-dockerfile` | Builds a Docker image from a Dockerfile with token substitution (build only, push handled by docker-push-all) |
| `docker-build-retag` | Pulls and retags Docker images (no push) |
| `docker-multi-tag` | Discovers and tags all matching images for additional registries |
| `docker-platform-setup` | Validates docker platform and installs QEMU on Linux CI |
| `docker-push-all` | Pushes all Docker images registered during build/tag steps |
| `docker-registry-logins` | Authenticate to container registries (GHCR by default, configure others as needed) |
| `generate-kubernetes-configmap` | Generates a Kubernetes ConfigMap manifest from files in a directory |
| `generate-kubernetes-poddisruptionbudget` | Generates a Kubernetes PodDisruptionBudget manifest for controlling voluntary disruptions |
| `generate-kubernetes-secret-template` | Generates a Kubernetes Secret template manifest from files in a directory |
| `generate-kubernetes-service` | Generates a Kubernetes Service manifest with tokenized values |
| `generate-kubernetes-serviceaccount` | Generates a Kubernetes ServiceAccount manifest for pod identity and RBAC binding |
| `generate-kubernetes-workload` | Routes to appropriate workload generator (Deployment, StatefulSet, etc.) |
| `git-push-tag` | Pushes an existing git tag to origin |
| `github-check-run` | Create or update GitHub Check Runs for granular PR status reporting |
| `github-release-prepare` | Prepares files for GitHub release with optional substitution and version suffix |
| `github-release` | Create GitHub release with assets from prepared directory |
| `hook-post-build` | Runs user's hook script after all build steps complete |
| `hook-post-docker-tests` | Runs user's hook script after Docker image is built for integration tests, security scans, or validation |
| `hook-post-package-tests` | Runs user's hook script after manifest packaging for validation, additional tests, or verification |
| `hook-post-versions-and-naming` | Runs user's hook script after version calculation to perform actions that depend on the calculated version |
| `hook-pre-build` | Runs user's hook script before build starts, after tooling validation |
| `hook-pre-docker-prepare` | Runs user's hook script before Docker build preparation to modify Dockerfile, copy files, or perform setup |
| `hook-pre-package-prepare` | Runs user's hook script before manifest packaging to generate ConfigMaps, modify manifests, or add files |
| `hook-pre-tagging-tests` | Runs user's hook script before tagging/versioning for custom validation or preparation |
| `kubernetes-manifests-contract-generate` | Generates a manifests contract file describing token scheme, required config, and compatibility |
| `kubernetes-manifests-package-only-token-override` | Overrides docker image tokens for manifests-only workflow |
| `kubernetes-manifests-package-prepare` | Prepares manifests and tokens for packaging |
| `kubernetes-manifests-package` | Packages Kubernetes manifests into a zip with variable substitution |
| `kubernetes-manifests-repo-provider-package` | Packages manifests for repo provider (builds docker image). Does NOT publish. |
| `kubernetes-manifests-repo-provider-publish` | Publishes manifests via pluggable repo provider. Requires package step to run first. |
| `layer-package-prepare` | Prepares layer or layerset for OCI packaging - validates source, injects metadata, generates Dockerfile |
| `layer-validate` | Validates substituted layer or layerset after docker build |
| `release-change-data-generate` | Generates structured release change data YAML from commit history |
| `release-change-data-oci-package` | Packages release change data as OCI image for consolidated push |
| `resolve-target-registry-and-namespace` | Resolves target registry (defaults to ghcr.io) and computes namespace (auto-detects org/user for GHCR) |
| `validate-tooling` | Validates required tools are available before build |
| `vendor-helm-render-and-process` | Fetches a vendor helm chart, renders it, and processes output into individual kubernetes manifests |
| `vendor-helm-render-validate` | Copies validated vendor helm-rendered manifests to src/kubernetes/ and checks for git diffs |
| `versions-and-naming` | Generates version numbers, tags, and naming for releases |
<!-- ACTIONS-END -->

## Configuration

### All Inputs

All inputs to the system come from KaptainPM.yaml and layers, except secrets.

### Secrets

<!-- SECRETS-START -->
| Secret | Description |
|--------|-------------|
| `docker-registry-logins-secrets` | JSON object of secrets for docker-registry-logins (e.g., {"DOCKER_USER": "x", "DOCKER_PASS": "y"}) |
<!-- SECRETS-END -->

### Workflow Documentation

<!-- WORKFLOW-DOCS-START -->
| Workflow | Description | Documentation |
|----------|-------------|---------------|
| `aws-eks-cluster-management.yaml` | EKS Cluster Management | [docs/aws-eks-cluster-management.md](docs/aws-eks-cluster-management.md) |
| `basic-quality-and-versioning.yaml` | Basic Quality and Versioning | [docs/basic-quality-and-versioning.md](docs/basic-quality-and-versioning.md) |
| `basic-quality-checks.yaml` | Basic Quality Checks | [docs/basic-quality-checks.md](docs/basic-quality-checks.md) |
| `docker-build-dockerfile.yaml` | Docker Build Dockerfile | [docs/docker-build-dockerfile.md](docs/docker-build-dockerfile.md) |
| `docker-build-retag.yaml` | Docker Build Retag | [docs/docker-build-retag.md](docs/docker-build-retag.md) |
| `kubernetes-app-docker-dockerfile.yaml` | Kubernetes App - Docker Dockerfile | [docs/kubernetes-app-docker-dockerfile.md](docs/kubernetes-app-docker-dockerfile.md) |
| `kubernetes-app-docker-retag.yaml` | Kubernetes App - Docker Retag | [docs/kubernetes-app-docker-retag.md](docs/kubernetes-app-docker-retag.md) |
| `kubernetes-app-manifests-only.yaml` | Kubernetes App - Manifests Only | [docs/kubernetes-app-manifests-only.md](docs/kubernetes-app-manifests-only.md) |
| `kubernetes-bundle-docker-retag.yaml` | Kubernetes Bundle - Docker Retag | [docs/kubernetes-bundle-docker-retag.md](docs/kubernetes-bundle-docker-retag.md) |
| `kubernetes-bundle-resources.yaml` | Kubernetes Bundle - Resources | [docs/kubernetes-bundle-resources.md](docs/kubernetes-bundle-resources.md) |
| `kubernetes-bundle-vendor-helm-rendered.yaml` | Kubernetes Bundle - Vendor Helm Rendered | [docs/kubernetes-bundle-vendor-helm-rendered.md](docs/kubernetes-bundle-vendor-helm-rendered.md) |
| `layer-and-layerset-build.yaml` | Layer and Layerset Build | [docs/layer-and-layerset-build.md](docs/layer-and-layerset-build.md) |
| `spec-check-filter-release.yaml` | Spec Check Filter Release | [docs/spec-check-filter-release.md](docs/spec-check-filter-release.md) |
<!-- WORKFLOW-DOCS-END -->

## Versioning

Tags are generated based on the closest annotated tag in git history:

- **No tags**: Starts at `1.0.0`
- **Single-part**: (`42`): Increments to `43`
- **Two-part** (`1.2`): Increments to `1.3`
- **Three-part** (`1.2.3`): Increments to `1.2.4`
- **Four-part** (`1.2.3.4`): Increments to `1.2.3.5` (requires `max-version-parts: 4`)

Non-release branches get `-PRERELEASE` suffix on Docker tags.

### Tag Selection

The algorithm finds the right tag to increment:

1. **Find closest tag**: Walk commit history from HEAD, find the nearest annotated tag by commit distance
2. **Break ties by date**: If multiple tags are equidistant (e.g., after a merge), use the newest by creation date
3. **Scan entire repo**: Look up the highest version in that series across all branches (handles isolated/orphan branches)
4. **Increment**: Bump the last component of the highest version found

This means:
- A backfilled tag on an older commit won't hijack your series
- After merging branches with different tags, the newest tag wins
- Hotfix branches can't accidentally collide with main's newer versions

### Alternative: Dockerfile ENV Version

For version-locked images (kubectl, helm, terraform), use `dockerfile-env-version` strategy:

```yaml
uses: kube-kaptain/buildon-github-actions/.github/workflows/docker-build-dockerfile.yaml@v1
with:
  tag-version-calculation-strategy: dockerfile-env-version
  dockerfile-sub-path: src/docker      # default
  env-variable-name: KUBECTL_VERSION   # default
```

This extracts the version from your Dockerfile's `ENV` line:

```dockerfile
FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.0
```

The algorithm:
1. Extract version from `ENV KUBECTL_VERSION=x.y.z`
2. Use `x.y` as the series prefix
3. Find highest existing `x.y.*` tag
4. Increment patch: `1.28.0` → `1.28.1` → `1.28.2`, etc

When you update `KUBECTL_VERSION=1.29.0`, versioning automatically switches to the `1.29.*` series.

### Docker Registry Logins

Configure logins to container registries (Docker Hub, ECR, GCR, ACR, Quay, etc.) when your builds need to pull from or push to private registries.

#### GHCR Behavior

- **If `ghcr.io` is NOT in config**: Auto-login with GITHUB_TOKEN (same-org access works automatically)
- **If `ghcr.io` IS in config**: Use only the supplied credentials (required for cross-org access with a PAT)

You only need to configure `ghcr.io` explicitly when accessing packages from other organizations.

#### Option A: secrets: inherit (Recommended)

Use [`examples/docker-registry-logins-inherit.yaml`](examples/docker-registry-logins-inherit.yaml)

Simple and secure - all repository secrets are available to the reusable workflow. The workflow looks up secret values by the names you specify in the config.

**Pros:**
- Minimal boilerplate
- No risk of JSON syntax errors
- Easy to add new registries

**Cons:**
- All secrets are technically accessible (though only named ones are used)

#### Option B: Explicit JSON

Use [`examples/docker-registry-logins-explicit.yaml`](examples/docker-registry-logins-explicit.yaml)

Verbose but explicit - you list exactly which secrets are passed to the workflow.

**Pros:**
- Shows exactly what secrets the workflow receives
- Useful for security audits

**Cons:**
- More typing
- JSON syntax errors are easy to make
- Must update secret list when adding registries

#### Supported Login Types

| Type | Use Case |
|------|----------|
| `username-password` | Docker Hub, Quay, private registries |
| `aws-ecr` | AWS ECR with IAM access keys |
| `aws-ecr-github-actions-oidc` | AWS ECR via GitHub Actions OIDC (no long-lived keys) |
| `gcp-gar` | Google Artifact Registry with service account key |
| `gcp-gar-github-actions-oidc` | Google Artifact Registry via GitHub Actions OIDC |
| `azure-acr` | Azure Container Registry with service principal |
| `azure-acr-github-actions-oidc` | Azure ACR via GitHub Actions OIDC |

### Outputs

**Version formats:**

| Output                    | Example   | Use case                              |
|---------------------------|-----------|---------------------------------------|
| `version`                 | `1.2.3`   | Primary version                       |
| `version-major`           | `1`       | Major component                       |
| `version-minor`           | `2`       | Minor component                       |
| `version-patch`           | `3`       | Patch component                       |
| `version-2-part`          | `1.2`     | Two-part format                       |
| `version-3-part`          | `1.2.3`   | Semver format                         |
| `version-4-part`          | `1.2.3.0` | Four-part format                      |
| `version-dns-safe`        | `1-2-3`   | Version with dots replaced by hyphens |
| `version-2-part-dns-safe` | `1-2`     | Two-part DNS-safe format              |
| `version-3-part-dns-safe` | `1-2-3`   | Three-part DNS-safe format            |
| `version-4-part-dns-safe` | `1-2-3-0` | Four-part DNS-safe format             |

**Build metadata:**

| Output              | Example                       | Description                                           |
|---------------------|-------------------------------|-------------------------------------------------------|
| `git-tag`           | `v1.2.3`                      | Git tag for the version                               |
| `docker-tag`        | `1.2.3` or `1.2.3-PRERELEASE` | Ready-to-use image tag                                |
| `docker-image-name` | `some/some-repo`              | Image name from repo prefix                           |
| `is-release`        | `true` or `false`             | Whether this is a release branch build                |
| `project-name`      | `some-repo`                   | Contains repo name, to be used for all artifact names |

## Quality Checks

### Always On (cannot be disabled)

| Check                       | Blocks                                                  | Why                                                    |
|-----------------------------|---------------------------------------------------------|--------------------------------------------------------|
| GitHub default branch names | `user-patch-1` patterns                                 | Forces descriptive branch names                        |
| GitHub UI commit messages   | `Update filename`, `Create filename`, `Delete filename` | Forces descriptive commit messages                     |
| Merge commits               | Any commit with 2+ parents                              | Enforces rebase workflow                               |
| Branch up to date           | Branch that are out of date and need to be rebased      | Must be fast-forward to guarantee correct test results |
| Invalid PR target           | PRs targeting non-allowed branches                      | Enforces release branch discipline                     |

### Default On (can be disabled)

| Check          | Input                  | Default | Blocks                                |
|----------------|------------------------|---------|---------------------------------------|
| Double hyphens | `block-double-hyphens` | `true`  | `--` in branch names (typo detection) |

### Default Off (opt-in)

| Check                 | Input                           | Default | Requires/Blocks                                                                                                         |
|-----------------------|---------------------------------|---------|-------------------------------------------------------------------------------------------------------------------------|
| Slashes               | `block-slashes`                 | `false` | Blocks `/` in branch names                                                                                              |
| Conventional branches | `require-conventional-branches` | `false` | Requires `feature/`, `feat/`, `bugfix/`, `fix/`, `hotfix/`, `release/`, `chore/` prefix                                 |
| Conventional commits  | `require-conventional-commits`  | `false` | Requires `build:`, `chore:`, `ci:`, `docs:`, `feat:`, `fix:`, `perf:`, `refactor:`, `revert:`, `style:`, `test:` prefix |
| Block conventional    | `block-conventional-commits`    | `false` | Blocks conventional commit format                                                                                       |

## Development

```bash
src/bin/assemble-workflows.bash  # Regenerate workflows and docs only - no tests
.github/bin/run-tests.bash       # Run shellcheck, executable checks, BATS tests, etc AND regenerate as above
```

The assemble script:
1. Lints workflow templates for input consistency
2. Generates `.github/workflows/*.yaml` from `src/workflow-templates/`
3. Generates `docs/*.md` for each workflow
4. Updates README tables between markers

Run after modifying templates. Commit the generated workflows, generated docs/ and updated README.md along with the associated source files you changed.

## Project Licensing

This project uses multiple licenses:

| Component               | License      | Terms                                                                     |
|-------------------------|--------------|---------------------------------------------------------------------------|
| Source code and scripts | MIT          | Free to use, modify, distribute with attribution                          |
| Examples (`examples/`)  | CC0-1.0      | Public domain, use freely without attribution                             |
| Documentation (`*.md`)  | CC-BY-SA-4.0 | Attribute to Kaptain contributors, share modifications under same license |

Forks must preserve license headers and attribution. See [LICENSE.txt](LICENSE.txt) for full details.

## SPDX License Header

```
SPDX-License-Identifier: MIT
Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
```
