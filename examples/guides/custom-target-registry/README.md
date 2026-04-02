# Custom Target Registry

> See [Guide Usage](../README.md) for how to use these guides.

By default, built images are pushed to GHCR (`ghcr.io`). Use
`docker.targetRegistry` to push to a different registry such as
ECR, GCR, Harbor, or Nexus.

## Configuration

- `docker.targetRegistry` - the registry hostname (e.g. `harbor.internal.example.com`)
- `docker.targetNamespace` - the path segment between the registry and
  the image name (e.g. `platform-team` produces
  `harbor.internal.example.com/platform-team/<image>`)

## Requirements

The target registry must have a matching entry in `docker.logins` so the
workflow can authenticate before pushing. Credentials are passed through
the `docker-registry-logins-secrets` block in `build.yaml`.

## Notes

- If you omit `targetRegistry`, the default remains `ghcr.io`.
- The namespace is not the Kubernetes namespace - it is the registry
  path component (often an org, team, or project name).
