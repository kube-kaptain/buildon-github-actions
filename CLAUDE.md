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

## Key Design Decisions

- Scripts use generic env vars (`PR_BRANCH`, `TARGET_BRANCH`), actions map from GitHub context
- Use `.yaml` not `.yml`
- All text files have trailing newlines
- Exit code 42 for infrastructure failures (missing target branch, etc.)
- Bit flags for quality check failures (1=bad branch, 2=bad commit, 4=merge, 8=not rebased, 16=bad target)

## Environment Variables

Scripts use env vars for configuration:

| Variable | Default | Description |
|----------|---------|-------------|
| `DEFAULT_BRANCH` | `main` | The release branch name |
| `PATCH_BRANCHES` | `""` | Comma-separated additional release branch patterns |
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
./src/test/run-tests.sh
```

Runs shellcheck + BATS tests against fixture repos.

## Common Tasks

### Add a new action

1. Create script in `src/scripts/` (CI-agnostic)
2. Create action wrapper in `src/actions/<name>/action.yaml`
3. Map GitHub context to generic env vars in the action
4. Add tests in `src/test/`
