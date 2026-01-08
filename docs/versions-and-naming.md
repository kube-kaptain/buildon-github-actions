# versions-and-naming

Versions & Naming

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `release-branch` | string | `main` | The release branch name |
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `max-version-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `tag-version-calculation-strategy` | string | `git-auto-closest-highest` | Strategy for calculating version (git-auto-closest-highest, file-pattern-match) |
| `tag-version-pattern-type` | string | `dockerfile-env-kubectl` | Pattern type for file-pattern-match strategy (dockerfile-env-kubectl, retag-workflow-source-tag, custom) |
| `tag-version-prefix-parts` | string | `""` | Number of parts from source version to use as prefix (default 2, output = prefix + 1 parts) |
| `dockerfile-sub-path` | string | `src/docker` | Directory containing Dockerfile, relative to repo root. |
| `tag-version-source-sub-path` | string | `""` | Override path to source directory (takes precedence over dockerfile-sub-path) |
| `tag-version-source-file-name` | string | `""` | Override source file name (defaults based on pattern type) |
| `tag-version-source-custom-pattern` | string | `""` | Regex with capture group for version extraction (required for custom pattern type) |
| `output-sub-path` | string | `target` | Build output directory (relative) |
| `substitution-token-style` | string | `shell` | Token delimiter syntax for variables (shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift) |
| `token-name-style` | string | `PascalCase` | Case style for token names (UPPER_SNAKE, lower_snake, lower-kebab, UPPER-KEBAB, camelCase, PascalCase, lower.dot, UPPER.DOT) |
| `token-name-validation` | string | `MATCH` | How to validate user token names (MATCH = must match token-name-style, ALL = accept any valid name) |
| `config-sub-path` | string | `src/config` | Directory containing user-defined token files (relative) |
| `allow-builtin-token-override` | boolean | `false` | Allow user tokens to override built-in tokens (for template/reusable projects) |
| `config-value-trailing-newline` | string | `strip-for-single-line` | How to handle trailing newlines in config values (strip-for-single-line, preserve-all, always-strip-one-newline) |
| `pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `github-release-enabled` | boolean | `true` | Create a GitHub release on version tags |
| `github-release-files` | string | `""` | Files to attach to the release (space-separated) |
| `github-release-notes` | string | `""` | Release notes (leave empty for auto-generated) |
| `github-release-add-version-to-filenames` | boolean | `true` | Add version suffix to release filenames (e.g., file.yaml -> file-1.2.3.yaml) |
| `github-release-substitute-tokens-in-files` | boolean | `true` | Apply token substitution to release files |

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
| `docker-image-name` | Docker image name (prefix/project-name) |
| `git-tag` | Tag for git |
| `is-release` | Whether this is a release build |
| `project-name` | The repository/project name |
