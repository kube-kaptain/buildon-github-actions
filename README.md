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
| [`additional-release-branches.yaml`](examples/additional-release-branches.yaml) | Support hotfix workflows by building on branches other than the default and still getting releases published |
| [`basic-quality-and-versioning.yaml`](examples/basic-quality-and-versioning.yaml) | Standard build setup |
| [`docker-build-dockerfile-no-squash.yaml`](examples/docker-build-dockerfile-no-squash.yaml) | Build a Docker image without --squash, preserving layer history |
| [`docker-build-dockerfile.yaml`](examples/docker-build-dockerfile.yaml) | Build a Docker image from a Dockerfile with --squash (default) to flatten |
| [`docker-build-retag-base-path.yaml`](examples/docker-build-retag-base-path.yaml) | Many registries use base paths in addition to the normal image name for projects or teams |
| [`docker-build-retag-custom-registry.yaml`](examples/docker-build-retag-custom-registry.yaml) | Push to a registry other than GHCR (Nexus, ECR, GCR, Harbor, etc) |
| [`docker-build-retag.yaml`](examples/docker-build-retag.yaml) | Pull an upstream image, retag with your name and new version, push to your registry |
| [`docker-registry-logins-explicit.yaml`](examples/docker-registry-logins-explicit.yaml) | More typing, but shows exactly what the workflow receives |
| [`docker-registry-logins-ghcr-pat.yaml`](examples/docker-registry-logins-ghcr-pat.yaml) |   - Push to packages in a different repo or org (GITHUB_TOKEN is scoped to current repo) |
| [`docker-registry-logins-inherit.yaml`](examples/docker-registry-logins-inherit.yaml) | Secret values are looked up by the names specified in the config |
| [`optional-test-scripts.yaml`](examples/optional-test-scripts.yaml) | Shows how to add custom test scripts to workflows that support them |
| [`quality-only.yaml`](examples/quality-only.yaml) | Enforce quality standards on PRs without automatic tagging |
| [`version-from-custom-pattern.yaml`](examples/version-from-custom-pattern.yaml) | Extract version from any file using a custom regex pattern |
| [`version-from-dockerfile.yaml`](examples/version-from-dockerfile.yaml) | Extract version from an ENV variable in your Dockerfile rather than using git tags |
| [`version-from-retag-source-tag.yaml`](examples/version-from-retag-source-tag.yaml) | Extract version from the source-tag input in a retag workflow file |
| [`versions-and-naming.yaml`](examples/versions-and-naming.yaml) | Automatic version tagging without PR quality checks |
<!-- EXAMPLES-END -->

## Components

### Workflows

<!-- WORKFLOWS-START -->
| Workflow | Description |
|----------|-------------|
| `basic-quality-and-versioning.yaml` | Basic Quality and Versioning |
| `basic-quality-checks.yaml` | Basic Quality Checks |
| `docker-build-dockerfile.yaml` | Docker Build Dockerfile |
| `docker-build-retag.yaml` | Docker Build Retag |
| `kubernetes-app-docker-dockerfile.yaml` | Kubernetes App - Docker Dockerfile |
| `kubernetes-app-docker-retag.yaml` | Kubernetes App - Docker Retag |
| `kubernetes-app-manifests-only.yaml` | Kubernetes App - Manifests Only |
| `versions-and-naming.yaml` | Versions & Naming |
<!-- WORKFLOWS-END -->

### Actions

<!-- ACTIONS-START -->
| Action | Description |
|--------|-------------|
| `basic-quality-checks` | Basic quality checks for commits and branches |
| `docker-build-dockerfile` | Builds a Docker image from a Dockerfile with token substitution (build only, use docker-push to push) |
| `docker-build-retag` | Pulls and retags Docker images (no push) |
| `docker-push` | Pushes a Docker image to registry |
| `docker-registry-logins` | Authenticate to container registries (GHCR by default, configure others as needed) |
| `github-check-run` | Create or update GitHub Check Runs for granular PR status reporting |
| `kubernetes-manifests-package` | Packages Kubernetes manifests into a zip with variable substitution |
| `kubernetes-manifests-repo-provider-package` | Packages manifests for repo provider (builds docker image). Does NOT publish. |
| `kubernetes-manifests-repo-provider-publish` | Publishes manifests via pluggable repo provider. Requires package step to run first. |
| `resolve-target-registry-and-base-path` | Resolves target registry (defaults to ghcr.io) and computes base path (auto-detects org for GHCR) |
| `run-hook-script` | Runs a user-provided hook script from the .github/ directory |
| `versions-and-naming` | Generates version numbers, tags, and naming for releases |
<!-- ACTIONS-END -->

## Configuration

### All Inputs

<!-- INPUTS-START -->
| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `allow-builtin-token-override` | boolean | `false` | Allow user tokens to override built-in tokens (for template/reusable projects) |
| `block-conventional-commits` | boolean | `false` | Block commits that use conventional commit format |
| `block-double-hyphen-containing-branches` | boolean | `true` | Block branch names containing double hyphens (typo detection) |
| `block-slash-containing-branches` | boolean | `false` | Block branch names containing slashes |
| `block-slashes` | boolean | `false` | DEPRECATED: Use block-slash-containing-branches instead |
| `config-sub-path` | string | `src/config` | Directory containing user-defined token files (relative) |
| `config-value-trailing-newline` | string | `strip-for-single-line` | How to handle trailing newlines in config values (strip-for-single-line, preserve-all, always-strip-one-newline) |
| `default-branch` | string | `main` | The default/release branch name |
| `docker-registry-logins` | string | `""` | YAML config for Docker registry logins (registry URL as key) |
| `docker-source-base-path` | string | `""` | Path between registry and image name (e.g., library) |
| `docker-source-image-name` | string | *required* | Upstream image name (e.g., nginx) |
| `docker-source-registry` | string | *required* | Upstream registry (e.g., docker.io) |
| `docker-source-tag` | string | *required* | Upstream image tag (e.g., 1.25) |
| `docker-target-base-path` | string | `""` | Path between registry and image name (auto-set for GHCR) |
| `docker-target-registry` | string | `ghcr.io` | Target container registry |
| `dockerfile-sub-path` | string | `src/docker` | Directory containing Dockerfile, relative to repo root. |
| `manifests-packaging-base-image` | string | `""` | Base image for manifest packaging (default: ghcr.io/kube-kaptain/image/image-pause:3.10.2) |
| `manifests-repo-provider-type` | string | `docker` | Repo provider type for manifest storage (default: docker, currently the only supported provider) |
| `manifests-sub-path` | string | `src/kubernetes` | Directory containing Kubernetes manifests (relative) |
| `max-version-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `no-cache` | boolean | `true` | Disable layer caching for reproducible builds |
| `output-sub-path` | string | `target` | Build output directory (relative) |
| `post-docker-tests-script-sub-path` | string | `""` | Path to post-docker test script relative to .github/ (e.g., bin/post-docker.bash) |
| `post-package-tests-script-sub-path` | string | `""` | Path to post-package test script relative to .github/ (e.g., bin/post-package.bash) |
| `pre-docker-prepare-script-sub-path` | string | `""` | Path to pre-docker prepare script relative to .github/ (e.g., bin/pre-docker-prepare.bash) |
| `pre-package-prepare-script-sub-path` | string | `""` | Path to pre-package prepare script relative to .github/ (e.g., bin/pre-package-prepare.bash) |
| `pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `require-conventional-branches` | boolean | `false` | Require branch names start with feature/, fix/, etc. |
| `require-conventional-commits` | boolean | `false` | Require commits use conventional commit format (feat:, fix:, etc.) |
| `squash` | boolean | `true` | Enable --squash (requires experimental mode) |
| `substitution-token-style` | string | `shell` | Token delimiter syntax for variables (shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift) |
| `tag-version-calculation-strategy` | string | `git-auto-closest-highest` | Strategy for calculating version (git-auto-closest-highest, file-pattern-match) |
| `tag-version-pattern-type` | string | `dockerfile-env-kubectl` | Pattern type for file-pattern-match strategy (dockerfile-env-kubectl, retag-workflow-source-tag, custom) |
| `tag-version-source-custom-pattern` | string | `""` | Regex with capture group for version extraction (required for custom pattern type) |
| `tag-version-source-file-name` | string | `""` | Override source file name (defaults based on pattern type) |
| `tag-version-source-sub-path` | string | `""` | Override path to source directory (takes precedence over dockerfile-sub-path) |
| `token-name-style` | string | `PascalCase` | Case style for token names (UPPER_SNAKE, lower_snake, kebab-case, camelCase, PascalCase, lower.dot, UPPER.DOT) |
| `token-name-validation` | string | `MATCH` | How to validate user token names (MATCH = must match token-name-style, ALL = accept any valid name) |
<!-- INPUTS-END -->

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
| `basic-quality-and-versioning.yaml` | Basic Quality and Versioning | [docs/basic-quality-and-versioning.md](docs/basic-quality-and-versioning.md) |
| `basic-quality-checks.yaml` | Basic Quality Checks | [docs/basic-quality-checks.md](docs/basic-quality-checks.md) |
| `docker-build-dockerfile.yaml` | Docker Build Dockerfile | [docs/docker-build-dockerfile.md](docs/docker-build-dockerfile.md) |
| `docker-build-retag.yaml` | Docker Build Retag | [docs/docker-build-retag.md](docs/docker-build-retag.md) |
| `kubernetes-app-docker-dockerfile.yaml` | Kubernetes App - Docker Dockerfile | [docs/kubernetes-app-docker-dockerfile.md](docs/kubernetes-app-docker-dockerfile.md) |
| `kubernetes-app-docker-retag.yaml` | Kubernetes App - Docker Retag | [docs/kubernetes-app-docker-retag.md](docs/kubernetes-app-docker-retag.md) |
| `kubernetes-app-manifests-only.yaml` | Kubernetes App - Manifests Only | [docs/kubernetes-app-manifests-only.md](docs/kubernetes-app-manifests-only.md) |
| `versions-and-naming.yaml` | Versions & Naming | [docs/versions-and-naming.md](docs/versions-and-naming.md) |
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

| Output | Example | Use case |
|--------|---------|----------|
| `version` | `1.2.3` | Primary version |
| `version-major` | `1` | Major component |
| `version-minor` | `2` | Minor component |
| `version-patch` | `3` | Patch component |
| `version-2-part` | `1.2` | Two-part format |
| `version-3-part` | `1.2.3` | Semver format |
| `version-4-part` | `1.2.3.0` | Four-part format |

**Build metadata:**

| Output | Example | Description |
|--------|---------|-------------|
| `docker-tag` | `1.2.3` or `1.2.3-PRERELEASE` | Ready-to-use image tag |
| `docker-image-name` | `some/some-repo` | Image name from repo prefix |
| `is-release` | `true` or `false` | Whether this is a release branch build |
| `project-name` | `some-repo` | Contains repo name, to be used for all artifact names |

## Quality Checks

### Always On (cannot be disabled)

| Check | Blocks | Why |
|-------|--------|-----|
| GitHub default branch names | `user-patch-1` patterns | Forces descriptive branch names |
| GitHub UI commit messages | `Update filename`, `Create filename`, `Delete filename` | Forces descriptive commit messages |
| Merge commits | Any commit with 2+ parents | Enforces rebase workflow |
| Branch up to date | Branch that are out of date and need to be rebased | Must be fast-forward to guarantee correct test results |
| Invalid PR target | PRs targeting non-allowed branches | Enforces release branch discipline |

### Default On (can be disabled)

| Check | Input | Default | Blocks |
|-------|-------|---------|--------|
| Double hyphens | `block-double-hyphens` | `true` | `--` in branch names (typo detection) |

### Default Off (opt-in)

| Check | Input | Default | Requires/Blocks |
|-------|-------|---------|-----------------|
| Slashes | `block-slashes` | `false` | Blocks `/` in branch names |
| Conventional branches | `require-conventional-branches` | `false` | Requires `feature/`, `feat/`, `bugfix/`, `fix/`, `hotfix/`, `release/`, `chore/` prefix |
| Conventional commits | `require-conventional-commits` | `false` | Requires `build:`, `chore:`, `ci:`, `docs:`, `feat:`, `fix:`, `perf:`, `refactor:`, `revert:`, `style:`, `test:` prefix |
| Block conventional | `block-conventional-commits` | `false` | Blocks conventional commit format |

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

| Component | License | Terms |
|-----------|---------|-------|
| Source code and scripts | MIT | Free to use, modify, distribute with attribution |
| Examples (`examples/`) | CC0-1.0 | Public domain, use freely without attribution |
| Documentation (`*.md`) | CC-BY-SA-4.0 | Attribute to Kaptain contributors, share modifications under same license |

Forks must preserve license headers and attribution. See [LICENSE.txt](LICENSE.txt) for full details.

## SPDX License Header

```
SPDX-License-Identifier: MIT
Copyright (c) 2025 Kaptain contributors (Fred Cooke)
```
