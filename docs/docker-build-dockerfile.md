# docker-build-dockerfile

Docker Build Dockerfile

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `dockerfile-path` | string | `src/docker` | Directory containing Dockerfile (also used as build context) |
| `squash` | boolean | `true` | Enable --squash (requires experimental mode) |
| `no-cache` | boolean | `true` | Disable layer caching for reproducible builds |
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
| `pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `post-docker-tests-script-sub-path` | string | `""` | Path to post-docker test script relative to .github/ (e.g., bin/post-docker.bash) |
| `additional-docker-logins` | string | `""` | YAML config for additional registry logins (registry URL as key) |

## Secrets

| Secret | Description |
|--------|-------------|
| `target-username` | Username for target registry (defaults to github.actor for GHCR) |
| `target-password` | Password/token for target registry (defaults to GITHUB_TOKEN for GHCR) |
| `additional-docker-logins-secrets` | JSON object of secrets for additional-docker-logins (e.g., {"DOCKER_USER": "x", "DOCKER_PASS": "y"}) |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The generated version |
| `docker-tag` | Tag for Docker images |
| `docker-image-name` | Docker image name |
| `is-release` | Whether this is a release build |
| `target-image-full-uri` | Full target image reference |
| `image-pushed` | Whether image was pushed |
