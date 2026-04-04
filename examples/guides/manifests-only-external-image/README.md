# Manifests Only - External Image

> See [Guide Usage](../README.md) for how to use these guides.

Package Kubernetes manifests for an image that is built by another system or
repository. No Docker build happens in this workflow.

This is useful when your image is built by a separate CI pipeline (or a different
repo) and you only need to generate and version the Kubernetes manifests that
reference it.

## How it works

The `kubernetes-app-manifests-only` workflow skips the Docker build entirely.
Instead, it generates Kubernetes manifests using the generators defined in
`KaptainPM.yaml` and substitutes the image reference from `externalImage`.

## External image substitution

When `externalImage` is present, the workflow replaces image reference tokens
in the generated manifests with the specified name and tag. If `externalImage`
is omitted, the tokens remain as-is - this is useful when a product-level
deploy process handles substitution later.

## Generators

The `generators` block defines what Kubernetes resources to create. In this example:

- A `deployment` workload with 2 replicas
- A container listening on port 8080

## Gotchas

- There is no Docker build or push - the workflow only produces manifests
- The `externalImage.tag` is a string - always quote numeric tags like `'2.1.0'`
- If you omit `externalImage`, the manifests will use `ghcr.io` and your gh org/user.
