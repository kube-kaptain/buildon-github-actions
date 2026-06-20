# Kubernetes Bundle - Docker Dockerfile

> See [Guide Usage](../guides/README.md) for how to use the three files.

Minimal build with no overrides.

Packages Kubernetes manifests and builds a Docker image from a Dockerfile
for third-party stacks whose hard-coded refs can't be made to fit Kaptain's
naming conventions.

Kaptain manifest generators don't run automatically in this process.
