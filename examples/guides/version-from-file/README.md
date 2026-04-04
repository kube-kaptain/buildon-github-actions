# Version From File

> See [Guide Usage](../README.md) for how to use these guides.

Extract the image version from a file in your repository instead of auto-incrementing from git tags.

This is useful when the version is defined elsewhere - for example, a `kubectl` version pinned in a Dockerfile `ENV` - and you want the image tag to match that embedded version.

## Version strategies

Kaptain supports two version strategies:

- **git-auto-closest-highest** (default) - automatically increments based on the highest existing git tag
- **file-pattern-match** - reads a version string from a file in the repo using a pattern

This guide demonstrates `file-pattern-match`.

## Pattern types

The `patternType` field tells the workflow how to extract the version:

- **dockerfile-env-kubectl** - matches `ENV KUBECTL_VERSION=X.Y.Z` in a Dockerfile
- Custom regex patterns can be used for other version formats

## Source file config

Under `spec.global.release.versioning`, you specify:

- `sourceOne.subPath` - directory containing the file (relative to repo root)
- `sourceOne.fileName` - the file to read

The workflow reads that file, applies the pattern, and uses the extracted version as the image tag.

## Gotchas

- The `global` scope applies the version strategy to all builds in the spec - use `main` scope if you only want it for a specific build
- If the pattern does not match anything in the file, the build will fail with a version extraction error
- The file must exist at the specified path or the workflow will error before building
