# kubernetes-app-manifests-only

Kubernetes App - Manifests Only

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `manifests-sub-path` | string | `src/kubernetes` | Directory containing Kubernetes manifests (relative) |
| `substitution-token-style` | string | `shell` | Token delimiter syntax for variables (shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift) |
| `token-name-style` | string | `PascalCase` | Case style for token names (UPPER_SNAKE, lower_snake, kebab-case, camelCase, PascalCase, lower.dot, UPPER.DOT) |
| `token-name-validation` | string | `MATCH` | How to validate user token names (MATCH = must match token-name-style, ALL = accept any valid name) |
| `allow-builtin-token-override` | boolean | `false` | Allow user tokens to override built-in tokens (for template/reusable projects) |
| `config-sub-path` | string | `src/config` | Directory containing user-defined token files (relative) |
| `output-sub-path` | string | `target` | Build output directory (relative) |
| `config-value-trailing-newline` | string | `strip-for-single-line` | How to handle trailing newlines in config values (strip-for-single-line, preserve-all, always-strip-one-newline) |
| `manifests-repo-provider-type` | string | `docker` | Repo provider type for manifest storage (default: docker, currently the only supported provider) |
| `target-registry` | string | `ghcr.io` | Target container registry |
| `target-base-path` | string | `""` | Path between registry and image name (auto-set for GHCR) |
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
| `pre-package-prepare-script-sub-path` | string | `""` | Path to pre-package prepare script relative to .github/ (e.g., bin/pre-package-prepare.bash) |
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
| `manifests-zip-sub-path` | Directory containing manifests zip file (relative) |
| `manifests-zip-file-name` | Name of manifests zip file |
| `manifests-uri` | Reference to published manifests (format depends on repo provider) |
| `manifests-published` | Whether manifests were published |
