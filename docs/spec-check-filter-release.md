# spec-check-filter-release

Spec Check Filter Release

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `output-sub-path` | string | `target` | Build output directory (relative) |
| `docker-registry-logins` | string | `""` | YAML config for Docker registry logins (registry URL as key) |
| `docker-target-registry` | string | `""` | Target container registry domain (defaults to ghcr.io on GH Actions) |
| `docker-target-namespace` | string | `""` | Path segment between registry and image name (defaults to lower cased org name or user ID on GH Actions) |
| `docker-push-targets` | string | `""` | JSON array of additional push targets [{registry, namespace?}] |
| `dockerfile-substitution-files` | string | `Dockerfile` | Comma-separated list of files to perform token substitution on (relative to dockerfile-sub-path and docker-context-sub-path) |
| `dockerfile-sub-path` | string | `src/docker` | Directory containing Dockerfile, relative to repo root. |
| `dockerfile-squash` | string | `squash` | Squash mode: squash, squash-all, or no |
| `dockerfile-no-cache` | boolean | `true` | Disable layer caching for reproducible builds |
| `spec-type` | string | *required* | Type of spec (schema or api) |
| `spec-validation-type` | string | `basic` | Schema validator to use (basic, python3-jsonschema) |
| `spec-packaging-base-image` | string | `scratch` | Base image for spec packaging |
| `token-delimiter-style` | string | `shell` | Token delimiter syntax for variables (shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift) |
| `token-name-style` | string | `PascalCase` | Case style for token names (UPPER_SNAKE, lower_snake, lower-kebab, UPPER-KEBAB, camelCase, PascalCase, lower.dot, UPPER.DOT) |
| `token-name-validation` | string | `MATCH` | How to validate user token names (MATCH = must match token-name-style, ALL = accept any valid name) |
| `allow-builtin-token-override` | boolean | `false` | Allow user tokens to override built-in tokens (for template/reusable projects) |
| `config-sub-path` | string | `src/config` | Directory containing user-defined token files (relative) |
| `config-value-trailing-newline` | string | `strip-for-single-line` | How to handle trailing newlines in config values (strip-for-single-line, preserve-all, always-strip-one-newline) |
| `release-branch` | string | `main` | The release branch name |
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `tag-version-max-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `tag-version-calculation-strategy` | string | `git-auto-closest-highest` | Strategy for calculating version (git-auto-closest-highest, file-pattern-match, compound-file-pattern-match) |
| `tag-version-pattern-type` | string | `dockerfile-env-kubectl` | Pattern type for file-pattern-match strategy (dockerfile-env-kubectl, retag-workflow-source-tag, custom) |
| `tag-version-prefix-parts` | string | `""` | Number of parts from source version to use as prefix (default 2, output = prefix + 1 parts). Ignored when tag-version-use-source-version-exact is true. |
| `tag-version-source-sub-path` | string | `""` | Override path to source directory (takes precedence over dockerfile-sub-path) |
| `tag-version-source-file-name` | string | `""` | Override source file name (defaults based on pattern type) |
| `tag-version-source-custom-pattern` | string | `""` | Regex with capture group for version extraction (required for custom pattern type) |
| `tag-version-source-two-sub-path` | string | `""` | Path to source TWO directory (defaults to source ONE path) |
| `tag-version-source-two-file-name` | string | `""` | Source TWO file name (defaults to source ONE file name) |
| `tag-version-source-two-pattern` | string | `""` | Regex with capture group for source TWO (required if same file as source ONE) |
| `tag-version-source-two-prefix-parts` | string | `""` | Number of parts from source TWO version to use in prefix (default 2). Ignored when tag-version-use-source-version-exact is true. |
| `tag-version-use-source-version-exact` | boolean | `false` | Use the exact version found in source file(s) without incrementing (file-based strategies only) |
| `block-slashes` | boolean | `false` | DEPRECATED: Use block-slash-containing-branches instead |
| `qc-block-slash-containing-branches` | boolean | `false` | Block branch names containing slashes |
| `qc-block-double-hyphen-containing-branches` | boolean | `true` | Block branch names containing double hyphens (typo detection) |
| `qc-require-conventional-branches` | boolean | `false` | Require branch names start with feature/, fix/, etc. |
| `qc-require-conventional-commits` | boolean | `false` | Require commits use conventional commit format (feat:, fix:, etc.) |
| `qc-block-conventional-commits` | boolean | `false` | Block commits that use conventional commit format |
| `qc-block-duplicate-commit-messages` | boolean | `true` | Block PRs where two or more commits have identical messages |
| `hook-pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `change-source-note-enabled` | boolean | `true` | Write a git note with merge candidate metadata for release tracking |
| `github-release-enabled` | boolean | `true` | Create a GitHub release on version tags |
| `github-release-substituted-files` | string | `""` | Files with token substitution and version suffix (space-separated) |
| `github-release-verbatim-files` | string | `""` | Files copied as-is with version suffix only (space-separated) |
| `github-release-notes` | string | `""` | Inline release notes string (mutually exclusive with github-release-notes-file) |
| `github-release-notes-file` | string | `""` | Path to release notes file (mutually exclusive with github-release-notes) |
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
| `docker-target-image-full-uri` | Full target image reference |
| `images-pushed` | Number of images pushed |
| `docker-substituted-sub-path` | Directory containing substituted files (relative) |
| `spec-yaml` | File name of spec YAML file |
| `spec-json` | File name of spec JSON file |
