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

| Example | Description |
|---------|-------------|
| [`basic-quality-and-versioning.yaml`](examples/basic-quality-and-versioning.yaml) | Standard setup: PR quality checks + push versioning |
| [`quality-only.yaml`](examples/quality-only.yaml) | Quality enforcement without tagging |
| [`versions-and-naming.yaml`](examples/versions-and-naming.yaml) | Version tagging without quality checks |
| [`patch-branches.yaml`](examples/patch-branches.yaml) | Hotfix workflow with 4-part versions |
| [`docker-build-retag.yaml`](examples/docker-build-retag.yaml) | Vendor upstream images to your GHCR |
| [`docker-build-retag-base-path.yaml`](examples/docker-build-retag-base-path.yaml) | Custom base path for image organization |
| [`docker-build-retag-custom-registry.yaml`](examples/docker-build-retag-custom-registry.yaml) | Retag to Artifactory, ECR, or other registries |
| [`docker-build-dockerfile.yaml`](examples/docker-build-dockerfile.yaml) | Build from Dockerfile with --squash (default) |
| [`docker-build-dockerfile-no-squash.yaml`](examples/docker-build-dockerfile-no-squash.yaml) | Build from Dockerfile without --squash |

## Components

### Workflows

| Workflow | Description |
|----------|-------------|
| `basic-quality-and-versioning.yaml` | Combined: quality checks + versioning |
| `basic-quality-checks.yaml` | Quality checks only |
| `versions-and-naming.yaml` | Versioning only |
| `docker-build-retag.yaml` | Pull, retag, and push upstream images |
| `docker-build-dockerfile.yaml` | Build from Dockerfile with --squash |

### Actions

| Action | Description |
|--------|-------------|
| `basic-quality-checks` | Validates branch names, commit messages, rebase status |
| `versions-and-naming` | Generates version numbers, tags, and naming |
| `docker-build-retag` | Pulls, retags, and pushes Docker images |
| `docker-build-dockerfile` | Builds Docker images from Dockerfile with --squash |

## Configuration

| Input | Default | Description |
|-------|---------|-------------|
| `default-branch` | `main` | The release branch name |
| `patch-branches` | `""` | Comma-separated patterns for additional release branches |
| `block-slashes` | `false` | Block `/` in branch names |
| `max-version-parts` | `3` | Maximum version depth (set to 4 for patch branches) |

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

The quality action blocks:

- GitHub default branch names (`user-patch-1`)
- GitHub UI commit messages (`Update filename`, `Create filename`, `Delete filename`)
- Merge commits (require rebase workflow)
- Branches not rebased on target
- PRs targeting non-allowed branches

## Development

```bash
.github/bin/run-tests.bash
```

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
