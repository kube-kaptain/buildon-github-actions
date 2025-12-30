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

## Fetch-and-Extract Scripts (Download Side)

The reciprocal of package+publish. Single combined operation since manifests are useless until extracted.

### Script Naming

```
src/scripts/plugins/kubernetes-manifests-repo-providers/
  kubernetes-manifests-repo-provider-docker-fetch-and-extract
  kubernetes-manifests-repo-provider-github-release-fetch-and-extract
  kubernetes-manifests-repo-provider-npm-fetch-and-extract
  kubernetes-manifests-repo-provider-rubygems-fetch-and-extract
  kubernetes-manifests-repo-provider-maven-fetch-and-extract
  kubernetes-manifests-repo-provider-nuget-fetch-and-extract
```

### Positional Argument APIs

Unlike publish-side (env vars for CI integration), fetch uses positional args for direct invocation from config-driven dispatchers.

| Provider | Args | Example |
|----------|------|---------|
| **docker** | `<image-uri> <output-dir>` | `ghcr.io/myorg/myapp-manifests:1.2.3 target/env/myapp` |
| **github-release** | `<repo> <tag> <asset-name> <output-dir>` | `myorg/myapp v1.2.3 myapp-manifests-1.2.3.zip target/env/myapp` |
| **npm** | `<package-spec> <output-dir>` | `@myorg/myapp-manifests@1.2.3 target/env/myapp` |
| **rubygems** | `<gem-name> <version> <output-dir>` | `myapp-manifests 1.2.3 target/env/myapp` |
| **maven** | `<gav-coordinates> <output-dir>` | `io.github.myorg:myapp-manifests:1.2.3:zip target/env/myapp` |
| **nuget** | `<package-id> <version> <output-dir>` | `MyApp.Manifests 1.2.3 target/env/myapp` |

### Fetch-and-Extract Flow by Provider

| Provider | CLI | Download Command | Extract Method |
|----------|-----|------------------|----------------|
| **docker** | docker | `docker pull` + `docker create` + `docker cp` | `unzip` from copied file |
| **github-release** | gh | `gh release download --repo <repo> --pattern <asset>` | `unzip` downloaded asset |
| **npm** | npm | `npm pack <package>@<version>` | `tar xzf` then `unzip` inner zip |
| **rubygems** | gem | `gem fetch <name> -v <version>` | `gem unpack` then `unzip` inner zip |
| **maven** | mvn | `mvn dependency:copy -Dartifact=<gav>` | `unzip` downloaded artifact |
| **nuget** | dotnet | `dotnet nuget ... ` or `nuget install` | Extract from .nupkg (zip format) |

### Registry/Source Configuration

For non-default registries, optional env vars can override:

| Provider | Env Var | Default (GitHub Packages) |
|----------|---------|---------------------------|
| **docker** | (in URI) | `ghcr.io` |
| **github-release** | (n/a) | `github.com` |
| **npm** | `NPM_REGISTRY` | `https://npm.pkg.github.com` |
| **rubygems** | `GEM_HOST` | `https://rubygems.pkg.github.com` |
| **maven** | `MAVEN_REPO_URL` | `https://maven.pkg.github.com` |
| **nuget** | `NUGET_SOURCE` | `https://nuget.pkg.github.com` |

### Authentication Challenge

**The Problem:**

Docker is straightforward - CI does N `docker login` calls based on user config, and if users have multiple docker sources (their own + partner ecosystems), they add logins for each. All subsequent pulls just work.

Other providers are trickier. Consider:

```yaml
components:
  our-app:
    provider: npm
    registry: npm.pkg.github.com  # needs GITHUB_TOKEN

  partner-lib:
    provider: npm
    registry: npm.partner.io      # needs PARTNER_NPM_TOKEN

  public-thing:
    provider: npm
    registry: registry.npmjs.org  # maybe no auth, or different token
```

Three npm sources, three different auth configs. How do scripts (which must remain CI-agnostic) get the right auth for each?

**Options Under Consideration:**

| Option | Approach | Pros | Cons |
|--------|----------|------|------|
| **1. Pre-step auth** | Action.yaml configures all auth before script runs | Simple for script | Requires knowing all sources upfront in action |
| **2. Auth block in config** | `auth:` section maps registries to secret names | Declarative | Who expands secret refs? Script can't see CI secrets |
| **3. Generic env vars** | `NPM_AUTH_npm_pkg_github_com=token` | Explicit | Ugly naming, hard to document |
| **4. Credential helper** | Script calls helper: `kaptain-cred-helper npm registry.io` | Clean separation | Helper still needs secret source |
| **5. File-based handoff** | CI writes secrets to `.kaptain-auth/{registry}`, script reads | CI-agnostic contract | File management overhead |

**Option 5 Detail:**

```yaml
# CI action populates files
- run: |
    mkdir -p .kaptain-auth
    echo "${{ secrets.GITHUB_TOKEN }}" > .kaptain-auth/npm.pkg.github.com
    echo "${{ secrets.PARTNER_TOKEN }}" > .kaptain-auth/npm.partner.io
```

```bash
# Script reads (CI-agnostic)
get_auth_token() {
  local registry="$1"
  cat ".kaptain-auth/${registry}" 2>/dev/null || echo ""
}
```

**Docker Comparison:**

Docker already has this solved via `docker login` which persists to `~/.docker/config.json`. The other CLIs have similar mechanisms:
- npm: `~/.npmrc` with `//registry/:_authToken=...`
- gem: `~/.gem/credentials`
- maven: `~/.m2/settings.xml`
- nuget: `nuget sources add` / `~/.nuget/NuGet.Config`

Could we just require users to configure these in a pre-step, same as docker? The difference is docker login is commonly understood; the others are more obscure.

**Current Status:** Needs further thought. May defer non-docker providers until auth pattern is resolved.

### Version Range Resolution

Another complexity: components may specify version ranges rather than exact versions.

```yaml
components:
  stable-lib:
    version: "^1.2.0"      # any 1.x >= 1.2.0

  pinned-thing:
    version: "2.3.4"       # exact

  latest-patch:
    version: "~3.1.0"      # 3.1.x only
```

**Provider Range Syntax:**

| Provider | Range Syntax Examples | Resolution Mechanism |
|----------|----------------------|---------------------|
| **npm** | `^1.2.3`, `~1.2.3`, `>=1 <2` | `npm view pkg versions` |
| **maven** | `[1.0,2.0)`, `[1.0,)`, `LATEST` | Metadata XML in repo |
| **rubygems** | `~> 1.2`, `>= 1.0, < 2.0` | `gem search -ra` |
| **nuget** | `1.*` (use prefix only!) | NuGet API query (⚠️ range syntax picks OLDEST, not newest) |
| **docker** | (none native) | Query registry API, filter tags |
| **github-release** | (none native) | `gh release list`, filter |

**The Docker/GitHub Problem:**

These don't have native range support. Options:
1. **Query and filter**: List all tags/releases, apply semver filter
2. **Require exact versions**: No ranges for these providers
3. **Convention-based aliases**: `latest`, `stable` tags that repo maintains

**Resolution Phase:**

Fetch-and-extract scripts currently expect exact versions. Range resolution would need to happen before calling them:

```bash
# Pseudocode
resolved_version=$(resolve_version "$provider" "$package" "$range")
"kubernetes-manifests-repo-provider-${provider}-fetch-and-extract" \
  "$package" "$resolved_version" "$output_dir"
```

Could be:
- Separate `resolve-version` script per provider
- Built into dispatcher
- Part of fetch-and-extract (query first, then fetch)

**Current Status:** Needs design. Adds complexity to both config parsing and fetch scripts.

## Design Principles

1. **Scripts are CI-agnostic** - No `GITHUB_*` variables in scripts
2. **AUTH_TOKEN is optional** - Scripts work with pre-configured CI auth (Azure DevOps, GitLab, etc.)
3. **Action.yaml does the mapping** - GitHub-specific context mapped to generic vars
4. **Sensible defaults in actions** - GitHub Package URLs defaulted in action.yaml, not scripts
5. **Publish uses env vars** - For CI integration with mapped context
6. **Fetch uses positional args** - For direct invocation from config-driven dispatchers
