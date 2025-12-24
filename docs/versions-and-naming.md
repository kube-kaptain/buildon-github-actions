# versions-and-naming

Versions & Naming

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `default-branch` | string | `main` | The default/release branch name |
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `max-version-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |

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
| `is-release` | Whether this is a release build |
| `project-name` | The repository/project name |
