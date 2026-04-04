# GHCR PAT Authentication

> See [Guide Usage](../README.md) for how to use these guides.

By default, the workflow authenticates to GHCR using the built-in
`GITHUB_TOKEN`. Use a Personal Access Token (PAT) instead when:

- Pushing images to a different organization's GHCR
- The default token lacks `packages:write` permission
- You need cross-repo image access

## How it works

When you define `ghcr.io` explicitly in `docker.logins`, it replaces the
automatic `GITHUB_TOKEN` authentication entirely. You must then supply
credentials via the secrets mapping in `build.yaml`.

## Secrets mapping

The `docker-registry-logins-secrets` block in `build.yaml` maps GitHub
repository secrets into the names referenced by `KaptainPM.yaml`. Both
`GHCR_USER` and `GHCR_PAT` must be configured as repository or
organization secrets.
