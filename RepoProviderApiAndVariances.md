# Repo Provider API and Variances

## Overview

Manifest repo providers package and publish Kubernetes manifests to various registries/repositories. Each provider wraps the manifests zip into a provider-specific format and publishes to the appropriate registry.

## Provider Terminology Variances

| Provider | Server Term | Owner/Namespace Term | URL Pattern |
|----------|-------------|---------------------|-------------|
| **Docker** | Registry | (path segment) | `registry/path/image:tag` |
| **npm** | Registry | Scope (`@scope`) | `https://registry/` + scope in package.json |
| **RubyGems** | Host / Gem Server | Owner (in URL path) | `https://host/OWNER` |
| **Maven** | Repository | GroupId (`io.github.owner`) | `https://repo/OWNER/REPO` |
| **NuGet** | Source / Feed | Owner (in URL path) | `https://source/OWNER/index.json` |
| **GitHub Release** | (n/a) | Repository | `https://github.com/OWNER/REPO/releases` |

## Generic Script Variables

Scripts are CI-agnostic. They use generic variable names, not GitHub-specific ones.

### Package Scripts

| Variable | Required | Used By | Description |
|----------|----------|---------|-------------|
| `MANIFESTS_ZIP_PATH` | Yes | All | Path to manifests zip file |
| `MANIFESTS_ZIP_NAME` | Yes | All | Filename of the zip |
| `PROJECT_NAME` | Yes | All | Project name (becomes package/artifact name) |
| `VERSION` | Yes | All | Package version |
| `REGISTRY_OWNER` | Yes | npm, rubygems, nuget | Package owner/namespace |
| `REGISTRY_URL` | Yes | npm | Registry URL for publishConfig |
| `MAVEN_GROUP_ID` | Yes | maven | Maven groupId (e.g., `io.github.owner`) |
| `OUTPUT_PATH` | No | All | Build output directory (default: `target`) |
| `HOMEPAGE_URL` | No | rubygems, nuget | Optional homepage/repo URL for metadata |

### Publish Scripts

| Variable | Required | Used By | Description |
|----------|----------|---------|-------------|
| `MANIFESTS_ARTIFACT_PATH` | Yes | All | Path to packaged artifact (from package step) |
| `MANIFESTS_URI` | Yes | All | Package reference URI (from package step) |
| `REGISTRY_OWNER` | Yes | npm, rubygems, nuget | Package owner/namespace |
| `REGISTRY_URL` | Yes | All new providers | Registry/repository URL |
| `REGISTRY_REPO` | Yes | maven | Repository path (e.g., `owner/repo`) |
| `AUTH_TOKEN` | No | All | Authentication token (optional - uses pre-configured auth if not set) |
| `AUTH_USERNAME` | Conditional | maven | Username (required if AUTH_TOKEN set) |
| `IS_RELEASE` | No | All | `true` to publish, `false` to skip (default: `false`) |
| `MAVEN_GROUP_ID` | Yes | maven | Maven groupId (from package step) |
| `MAVEN_ARTIFACT_ID` | Yes | maven | Maven artifactId (from package step) |
| `VERSION` | Yes | maven | Artifact version |

## GitHub Actions Mappings

The action.yaml files map GitHub context to generic script variables.

### Required Mappings for Publish Action

| GitHub Context | Generic Variable | Notes |
|---------------|------------------|-------|
| `${{ github.token }}` | `AUTH_TOKEN` | Optional - CI may pre-configure auth |
| `${{ github.actor }}` | `AUTH_USERNAME` | Required for maven when AUTH_TOKEN set |
| `${{ github.repository_owner }}` | `REGISTRY_OWNER` | Package namespace |
| `${{ github.repository }}` | `REGISTRY_REPO` | For maven registry URL |

### Registry URL Defaults (GitHub Packages)

| Provider | Default REGISTRY_URL |
|----------|---------------------|
| npm | `https://npm.pkg.github.com` |
| rubygems | `https://rubygems.pkg.github.com/${REGISTRY_OWNER}` |
| maven | `https://maven.pkg.github.com/${REGISTRY_REPO}` |
| nuget | `https://nuget.pkg.github.com/${REGISTRY_OWNER}/index.json` |

## Work Completed

### Scripts Created (8 total)

All in `src/scripts/plugins/kubernetes-manifests-repo-providers/`:

- `kubernetes-manifests-repo-provider-npm-package`
- `kubernetes-manifests-repo-provider-npm-publish`
- `kubernetes-manifests-repo-provider-rubygems-package`
- `kubernetes-manifests-repo-provider-rubygems-publish`
- `kubernetes-manifests-repo-provider-maven-package`
- `kubernetes-manifests-repo-provider-maven-publish`
- `kubernetes-manifests-repo-provider-nuget-package`
- `kubernetes-manifests-repo-provider-nuget-publish`

### Tests Created

All in `src/test/`:

- `kubernetes-manifests-repo-provider-npm-package.bats`
- `kubernetes-manifests-repo-provider-npm-publish.bats`
- `kubernetes-manifests-repo-provider-rubygems-package.bats`
- `kubernetes-manifests-repo-provider-rubygems-publish.bats`
- `kubernetes-manifests-repo-provider-maven-package.bats`
- `kubernetes-manifests-repo-provider-maven-publish.bats`
- `kubernetes-manifests-repo-provider-nuget-package.bats`
- `kubernetes-manifests-repo-provider-nuget-publish.bats`

All 393 tests pass.

## Work Remaining

### 1. Fix Existing Action Files

The existing action.yaml files pass GitHub-specific variables directly to scripts:

**`src/actions/kubernetes-manifests-repo-provider-publish/action.yaml`:**
- Currently passes `GITHUB_TOKEN: ${{ github.token }}` directly
- Needs to map to generic `AUTH_TOKEN`, `AUTH_USERNAME`, `REGISTRY_OWNER`, etc.

**`src/actions/kubernetes-manifests-repo-provider-package/action.yaml`:**
- Needs to pass `REGISTRY_OWNER` for providers that need it

### 2. Extend Actions for New Providers

The action.yaml files currently only support `docker` and `github-release` providers. They need:

1. New inputs for provider-specific config:
   - `maven-group-id` (for maven provider)
   - `registry-url` (override for all)
   - `registry-owner` (override, defaults to `github.repository_owner`)

2. Logic to compute `REGISTRY_URL` based on provider type

3. Documentation updates listing all available providers

### 3. Consider Maven GroupId Default

Decision needed: Should `MAVEN_GROUP_ID` default to `io.github.${owner}` or remain strictly required?

Decision made: Yes, this is a reasonable GH Actions level default behaviour.

## Design Principles

1. **Scripts are CI-agnostic** - No `GITHUB_*` variables in scripts
2. **AUTH_TOKEN is optional** - Scripts work with pre-configured CI auth (Azure DevOps, GitLab, etc.)
3. **Action.yaml does the mapping** - GitHub-specific context mapped to generic vars
4. **Sensible defaults in actions** - GitHub Package URLs defaulted in action.yaml, not scripts
