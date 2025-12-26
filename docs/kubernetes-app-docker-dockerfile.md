# kubernetes-app-docker-dockerfile

Kubernetes App - Docker Dockerfile

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `dockerfile-path` | string | `src/docker` | Directory containing Dockerfile (also used as build context) |
| `squash` | boolean | `true` | Enable --squash (requires experimental mode) |
| `no-cache` | boolean | `true` | Disable layer caching for reproducible builds |
| `manifests-path` | string | `src/kubernetes` | Directory containing Kubernetes manifests |
| `substitution-token-style` | string | `shell` | Token delimiter syntax for variables (shell) |
| `substitution-output-style` | string | `UPPER_SNAKE` | Case style for variable names in manifests (UPPER_SNAKE, lower_snake, kebab-case, camelCase, PascalCase) |
| `manifest-transport` | string | *required* | Transport type for manifest storage (docker, github-release). Required - consumer must choose. |
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
| `post-docker-tests-script-sub-path` | string | `""` | Path to post-docker test script relative to .github/ (e.g., bin/post-docker.bash) |
| `post-package-tests-script-sub-path` | string | `""` | Path to post-package test script relative to .github/ (e.g., bin/post-package.bash) |
| `docker-registry-logins` | string | `""` | YAML config for additional registry logins (registry URL as key) |

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
| `docker-image-full-uri` | Full docker image reference |
| `docker-image-pushed` | Whether docker image was pushed |
| `manifest-zip-path` | Path to manifest zip file |
| `manifest-zip-name` | Name of manifest zip file |
| `manifest-uri` | Reference to published manifests (format depends on transport) |
| `manifest-published` | Whether manifests were published |
