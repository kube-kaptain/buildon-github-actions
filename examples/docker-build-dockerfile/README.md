# Docker Build Dockerfile

> See [Guide Usage](../guides/README.md) for how to use the three files.

Minimal build with no overrides.

Builds a Docker image from `src/docker/Dockerfile` with layer squashing. PRs
build with a PRERELEASE tag (not pushed); merges build with a clean version
and push to GHCR.
