# buildon-github-actions

Reusable GitHub Actions library for CI/CD pipelines with quality enforcement and automatic versioning.

## Project Structure

```
.github/
  workflows/                            # Reusable workflow templates (callable by consumers)
    basic-quality-and-versioning.yaml   # Combined: quality + versioning
    basic-quality-checks.yaml           # Quality checks only
    versions-and-naming.yaml            # Versioning only
    build.yaml                          # Dogfooding - this repo's own CI
src/
  actions/                              # Composite actions (wrap scripts for GitHub)
    basic-quality-checks/
    versions-and-naming/
  scripts/                              # Shell scripts (CI-agnostic logic)
    basic-quality-checks
    versions-and-naming
  test/                                 # BATS tests with fixture repos
    fixtures/                           # Git bundles for test scenarios
    repo-gen/                           # Scripts to generate fixtures
examples/                               # Usage examples for consumers
```

## Architecture

1. **Scripts** (`src/scripts/`) contain all logic - CI-agnostic, no GitHub-specific code
2. **Actions** (`src/actions/*/action.yaml`) wrap scripts, map GitHub context to env vars
3. **Workflows** (`.github/workflows/*.yaml`) compose actions into pipelines
4. **Consumers** reference workflows by version tag

### Kaptain Deployment Model

This repo provides the CI/CD build side. The broader Kaptain system has three layers:

- **Apps**: Individual applications with their own repos. Build pipelines publish manifests via repo providers (docker image, GitHub release, etc.)
- **Products**: Aggregate N apps into a deployable unit. Defined in `kaptain-product.yaml`. Reference app manifest sources.
- **Environments**: Deploy products (or individual apps) to clusters. Defined in `kaptain-environment.yaml`. Pull manifests from repo providers.

The publish scripts here (`kubernetes-manifest-publish`, plugins in `kube-manifest-repo-providers/`) handle the build-time upload. Download is not a simple inverse - environments call the download N times, once for each product/app being aggregated.

## Key Design Decisions

- Scripts use generic env vars (`PR_BRANCH`, `TARGET_BRANCH`), actions map from GitHub context
- Use `.yaml` not `.yml`
- All text files have trailing newlines
- Exit code 42 for infrastructure failures (missing target branch, etc.)
- Bit flags for quality check failures (1=bad branch, 2=bad commit, 4=merge, 8=not rebased, 16=bad target)
- Never use `latest` tags for Docker images - always pin to specific latest version for stability

## Environment Variables

Scripts use env vars for configuration:

| Variable | Default | Description |
|----------|---------|-------------|
| `DEFAULT_BRANCH` | `main` | The release branch name |
| `ADDITIONAL_RELEASE_BRANCHES` | `""` | Comma-separated additional release branches |
| `MAX_VERSION_PARTS` | `3` | Fail if version exceeds this depth |
| `PR_BRANCH` | current branch | Source branch for PR checks |
| `TARGET_BRANCH` | `DEFAULT_BRANCH` | Target branch for rebase checks |
| `BLOCK_SLASHES` | `false` | Block `/` in branch names |

## Tag Algorithm

1. Find closest annotated tag to HEAD (by commit distance)
2. If multiple at same distance, use newest by creation date
3. Look up highest version in that series across entire repo
4. Increment and push

## Testing

```bash
.github/bin/run-tests.bash
```

Runs shellcheck + BATS tests against fixture repos.

## Bash Portability

macOS ships bash 3.2, GitHub Actions ubuntu-24.04 has bash 5.x. Key differences:

- **Arithmetic with `set -e`**: `((count++))` when count is 0 returns exit status 1 in bash 5.x (expression evaluates to 0), killing the script with `set -e`. Use `count=$((count + 1))` instead.
- **Empty arrays with `set -u`**: `"${array[@]}"` on an empty array may fail as "unbound variable" in older bash. Use `"${array[@]+"${array[@]}"}"` if needed.

Always test in CI, not just locally - "works on my machine" hits hard with bash version differences.

## Common Tasks

### Add a new action

1. Create script in `src/scripts/` (CI-agnostic)
2. Create action wrapper in `src/actions/<name>/action.yaml`
3. Map GitHub context to generic env vars in the action
4. Add tests in `src/test/`
5. Run `src/bin/assemble-workflows.bash` to regenerate docs

## Git Workflow

- Never touch the git index - don't stage files, don't run `git add`. The user manages what gets committed.
- Always re-read files before editing them to avoid overwriting manual changes. Don't rely on cached content.
- Never use the superpowers:finishing-a-development-branch skill - the user handles branch completion themselves.

## SPDX License Header

```
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2025 Kaptain contributors (Fred Cooke)
```
