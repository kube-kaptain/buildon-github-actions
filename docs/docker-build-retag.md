# docker-build-retag

Docker Build Retag

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `docker-source-registry` | string | *required* | Upstream registry (e.g., docker.io) |
| `docker-source-base-path` | string | `""` | Path between registry and image name (e.g., library) |
| `docker-source-image-name` | string | *required* | Upstream image name (e.g., nginx) |
| `docker-source-tag` | string | *required* | Upstream image tag (e.g., 1.25) |
| `docker-target-registry` | string | `ghcr.io` | Target container registry |
| `docker-target-base-path` | string | `""` | Path between registry and image name (auto-set for GHCR) |
| `default-branch` | string | `main` | The default/release branch name |
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `block-slashes` | boolean | `false` | DEPRECATED: Use block-slash-containing-branches instead |
| `block-slash-containing-branches` | boolean | `false` | Block branch names containing slashes |
| `block-double-hyphen-containing-branches` | boolean | `true` | Block branch names containing double hyphens (typo detection) |
| `require-conventional-branches` | boolean | `false` | Require branch names start with feature/, fix/, etc. |
| `require-conventional-commits` | boolean | `false` | Require commits use conventional commit format (feat:, fix:, etc.) |
| `block-conventional-commits` | boolean | `false` | Block commits that use conventional commit format |
| `max-version-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `tag-version-calculation-strategy` | string | `git-auto-closest-highest` | Strategy for calculating version (git-auto-closest-highest, file-pattern-match) |
| `tag-version-pattern-type` | string | `dockerfile-env-kubectl` | Pattern type for file-pattern-match strategy (dockerfile-env-kubectl, retag-workflow-source-tag, custom) |
| `tag-version-prefix-parts` | string | `""` | Number of parts from source version to use as prefix (default 2, output = prefix + 1 parts) |
| `dockerfile-sub-path` | string | `src/docker` | Directory containing Dockerfile, relative to repo root. |
| `tag-version-source-sub-path` | string | `""` | Override path to source directory (takes precedence over dockerfile-sub-path) |
| `tag-version-source-file-name` | string | `""` | Override source file name (defaults based on pattern type) |
| `tag-version-source-custom-pattern` | string | `""` | Regex with capture group for version extraction (required for custom pattern type) |
| `pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `docker-registry-logins` | string | `""` | YAML config for Docker registry logins (registry URL as key) |

## Secrets

| Secret | Description |
|--------|-------------|
| `docker-registry-logins-secrets` | JSON object of secrets for docker-registry-logins (e.g., {"DOCKER_USER": "x", "DOCKER_PASS": "y"}) |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The generated version |
| `version-major` | Major version number |
| `version-minor` | Minor version number |
| `version-patch` | Patch version number |
| `version-2-part` | Version padded/truncated to 2 parts |
| `version-3-part` | Version padded/truncated to 3 parts |
| `version-4-part` | Version padded/truncated to 4 parts |
| `docker-tag` | Tag for Docker images |
| `docker-image-name` | Docker image name |
| `project-name` | The repository/project name |
| `is-release` | Whether this is a release build |
| `docker-source-image-full-uri` | Full source image reference |
| `docker-target-image-full-uri` | Full target image reference |
| `docker-image-full-uri` | Full docker image reference (alias for docker-target-image-full-uri) |
| `docker-image-pushed` | Whether docker image was pushed |
