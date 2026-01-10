# kubernetes-app-docker-dockerfile

Kubernetes App - Docker Dockerfile

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `output-sub-path` | string | `target` | Build output directory (relative) |
| `docker-registry-logins` | string | `""` | YAML config for Docker registry logins (registry URL as key) |
| `dockerfile-sub-path` | string | `src/docker` | Directory containing Dockerfile, relative to repo root. |
| `dockerfile-squash` | boolean | `true` | Enable --squash (requires experimental mode) |
| `dockerfile-no-cache` | boolean | `true` | Disable layer caching for reproducible builds |
| `docker-target-registry` | string | `ghcr.io` | Target container registry |
| `docker-target-base-path` | string | `""` | Path between registry and image name (auto-set for GHCR) |
| `docker-push-targets` | string | `""` | JSON array of additional push targets [{registry, base-path?}] |
| `manifests-sub-path` | string | `src/kubernetes` | Directory containing Kubernetes manifests (relative) |
| `manifests-repo-provider-type` | string | `docker` | Repo provider type for manifest storage (default: docker, currently the only supported provider) |
| `manifests-packaging-base-image` | string | `""` | Base image for manifest packaging (default: scratch) |
| `kubernetes-global-additional-labels` | string | `""` | Additional labels for all Kubernetes manifests (comma-separated key=value) |
| `kubernetes-global-additional-annotations` | string | `""` | Additional annotations for all Kubernetes manifests (comma-separated key=value) |
| `kubernetes-configmap-sub-path` | string | `src/configmap` | Directory containing ConfigMap data files (relative) |
| `kubernetes-configmap-name-checksum-injection` | boolean | `true` | Enable checksum injection suffix in ConfigMap name (true: ProjectName-configmap-checksum, false: ProjectName) |
| `kubernetes-configmap-additional-labels` | string | `""` | Additional labels specific to ConfigMap (comma-separated key=value) |
| `kubernetes-configmap-additional-annotations` | string | `""` | Additional annotations specific to ConfigMap (comma-separated key=value) |
| `token-delimiter-style` | string | `shell` | Token delimiter syntax for variables (shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift) |
| `token-name-style` | string | `PascalCase` | Case style for token names (UPPER_SNAKE, lower_snake, lower-kebab, UPPER-KEBAB, camelCase, PascalCase, lower.dot, UPPER.DOT) |
| `token-name-validation` | string | `MATCH` | How to validate user token names (MATCH = must match token-name-style, ALL = accept any valid name) |
| `allow-builtin-token-override` | boolean | `false` | Allow user tokens to override built-in tokens (for template/reusable projects) |
| `config-sub-path` | string | `src/config` | Directory containing user-defined token files (relative) |
| `config-value-trailing-newline` | string | `strip-for-single-line` | How to handle trailing newlines in config values (strip-for-single-line, preserve-all, always-strip-one-newline) |
| `release-branch` | string | `main` | The release branch name |
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `tag-version-max-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `tag-version-calculation-strategy` | string | `git-auto-closest-highest` | Strategy for calculating version (git-auto-closest-highest, file-pattern-match) |
| `tag-version-pattern-type` | string | `dockerfile-env-kubectl` | Pattern type for file-pattern-match strategy (dockerfile-env-kubectl, retag-workflow-source-tag, custom) |
| `tag-version-prefix-parts` | string | `""` | Number of parts from source version to use as prefix (default 2, output = prefix + 1 parts) |
| `tag-version-source-sub-path` | string | `""` | Override path to source directory (takes precedence over dockerfile-sub-path) |
| `tag-version-source-file-name` | string | `""` | Override source file name (defaults based on pattern type) |
| `tag-version-source-custom-pattern` | string | `""` | Regex with capture group for version extraction (required for custom pattern type) |
| `block-slashes` | boolean | `false` | DEPRECATED: Use block-slash-containing-branches instead |
| `qc-block-slash-containing-branches` | boolean | `false` | Block branch names containing slashes |
| `qc-block-double-hyphen-containing-branches` | boolean | `true` | Block branch names containing double hyphens (typo detection) |
| `qc-require-conventional-branches` | boolean | `false` | Require branch names start with feature/, fix/, etc. |
| `qc-require-conventional-commits` | boolean | `false` | Require commits use conventional commit format (feat:, fix:, etc.) |
| `qc-block-conventional-commits` | boolean | `false` | Block commits that use conventional commit format |
| `hook-pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `hook-pre-docker-prepare-script-sub-path` | string | `""` | Path to pre-docker prepare script relative to .github/ (e.g., bin/pre-docker-prepare.bash) |
| `hook-post-docker-tests-script-sub-path` | string | `""` | Path to post-docker test script relative to .github/ (e.g., bin/post-docker.bash) |
| `hook-pre-package-prepare-script-sub-path` | string | `""` | Path to pre-package prepare script relative to .github/ (e.g., bin/pre-package-prepare.bash) |
| `hook-post-package-tests-script-sub-path` | string | `""` | Path to post-package test script relative to .github/ (e.g., bin/post-package.bash) |
| `github-release-enabled` | boolean | `true` | Create a GitHub release on version tags |
| `github-release-substituted-files` | string | `""` | Files with token substitution and version suffix (space-separated) |
| `github-release-verbatim-files` | string | `""` | Files copied as-is with version suffix only (space-separated) |
| `github-release-notes` | string | `""` | Release notes (leave empty for auto-generated) |
| `github-release-add-version-to-filenames` | boolean | `true` | Add version suffix to release filenames (e.g., file.yaml -> file-1.2.3.yaml) |

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
| `git-tag` | Tag for git |
| `project-name` | The repository/project name |
| `is-release` | Whether this is a release build |
| `target-image-full-uri` | Full target image reference (action output name) |
| `docker-image-full-uri` | Full docker image reference (alias for target-image-full-uri) |
| `docker-image-pushed` | Whether docker image was pushed |
| `manifests-zip-sub-path` | Directory containing manifests zip file (relative) |
| `manifests-zip-file-name` | Name of manifests zip file |
| `manifests-uri` | Reference to published manifests (format depends on repo provider) |
| `manifests-published` | Whether manifests were published |
