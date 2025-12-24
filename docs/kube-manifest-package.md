# kube-manifest-package

Kube Manifest Package

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `manifests-path` | string | `src/kubernetes` | Directory containing Kubernetes manifests |
| `publish-docker` | boolean | `true` | Publish manifests as Docker image |
| `publish-release` | boolean | `false` | Publish manifests as GitHub release asset |
| `target-registry` | string | `ghcr.io` | Target container registry |
| `target-base-path` | string | `""` | Path between registry and image name (auto-set for GHCR) |
| `confirm-image-doesnt-exist` | boolean | `true` | Fail if target image already exists in registry |
| `default-branch` | string | `main` | The default/release branch name |
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `max-version-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `block-slashes` | boolean | `false` | Block branch names containing slashes |
| `block-double-hyphens` | boolean | `true` | Block branch names containing double hyphens (typo detection) |
| `require-conventional-branches` | boolean | `false` | Require branch names start with feature/, fix/, etc. |
| `require-conventional-commits` | boolean | `false` | Require commits use conventional commit format (feat:, fix:, etc.) |
| `block-conventional-commits` | boolean | `false` | Block commits that use conventional commit format |
| `pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `post-package-tests-script-sub-path` | string | `""` | Path to post-package test script relative to .github/ (e.g., bin/post-package.bash) |

## Secrets

| Secret | Description |
|--------|-------------|
| `target-username` | Username for target registry (defaults to github.actor for GHCR) |
| `target-password` | Password/token for target registry (defaults to GITHUB_TOKEN for GHCR) |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The generated version |
| `docker-tag` | Tag for Docker images |
| `docker-image-name` | Docker image name |
| `is-release` | Whether this is a release build |
| `manifest-zip-path` | Path to manifest zip file |
| `manifest-zip-name` | Name of manifest zip file |
| `manifest-image-full-uri` | Full manifest image reference |
| `manifest-image-pushed` | Whether manifest image was pushed |
| `release-url` | URL to GitHub release |
| `asset-uploaded` | Whether asset was uploaded to release |
