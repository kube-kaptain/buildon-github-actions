# docker-build-retag

Docker Build Retag

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `source-registry` | string | *required* | Upstream registry (e.g., docker.io) |
| `source-image-name` | string | *required* | Upstream image name (e.g., library/nginx) |
| `source-tag` | string | *required* | Upstream image tag (e.g., 1.25) |
| `target-registry` | string | `ghcr.io` | Target container registry |
| `target-base-path` | string | `""` | Path between registry and image name (auto-set for GHCR) |
| `confirm-image-doesnt-exist` | boolean | `true` | Fail if target image already exists in registry |
| `default-branch` | string | `main` | The default/release branch name |
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `block-slashes` | boolean | `false` | Block branch names containing slashes |
| `block-double-hyphens` | boolean | `true` | Block branch names containing double hyphens (typo detection) |
| `require-conventional-branches` | boolean | `false` | Require branch names start with feature/, fix/, etc. |
| `require-conventional-commits` | boolean | `false` | Require commits use conventional commit format (feat:, fix:, etc.) |
| `block-conventional-commits` | boolean | `false` | Block commits that use conventional commit format |
| `max-version-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `docker-registry-logins` | string | `""` | YAML config for Docker registry logins (registry URL as key) |

## Secrets

| Secret | Description |
|--------|-------------|
| `docker-registry-logins-secrets` | JSON object of secrets for docker-registry-logins (e.g., {"DOCKER_USER": "x", "DOCKER_PASS": "y"}) |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The generated version |
| `docker-tag` | Tag for Docker images |
| `docker-image-name` | Docker image name |
| `is-release` | Whether this is a release build |
| `source-image-full-uri` | Full source image reference |
| `target-image-full-uri` | Full target image reference |
| `image-pushed` | Whether image was pushed |
