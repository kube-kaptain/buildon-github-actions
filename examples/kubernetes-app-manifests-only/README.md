# Kubernetes App - Manifests Only

> See [Guide Usage](../guides/README.md) for how to use the three files.

Minimal build with no overrides.

Packages Kubernetes manifests without building a Docker image. Use when
deploying an externally-built image or when manifests reference an image
built elsewhere. Configure `externalImage` in `KaptainPM.yaml` to substitute
image references.
