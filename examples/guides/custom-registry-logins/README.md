# Custom Registry Logins

> See [Guide Usage](../README.md) for how to use these guides.

Authenticate to additional Docker registries beyond the automatic GHCR login.

This is needed when your Dockerfile pulls base images from private registries,
or when you want to push to registries that require explicit credentials.

## Login types

KaptainPM supports several login types:

- **username-password** - standard username and token/password pair (Docker Hub, Harbor, ECR, etc)
- **github-token** - uses the built-in GITHUB_TOKEN (this is what GHCR uses automatically)

Each login entry is keyed by the registry hostname and specifies `usernameSecret`
and `passwordSecret` - these are the names of GitHub Actions secrets, not the
actual credentials.

## GHCR is automatic

You never need to add a login for `ghcr.io` unless you want to push to multiple
package locations. The workflow configures `ghcr.io` for the package associated
with your repo automatically using the built-in GITHUB_TOKEN. Only add entries
for registries beyond GHCR unless you're pushing to multiple package locations.

## How secrets flow

1. In `KaptainPM.yaml`, you reference secret names (e.g. `DOCKERHUB_USER`)
2. In `build.yaml`, you pass those secrets to the reusable workflow via the `docker-registry-logins-secrets` input
3. The workflow reads `KaptainPM.yaml` to know which secrets map to which registry

Make sure every secret name referenced in `KaptainPM.yaml` is also passed in the
`build.yaml` secrets block.

## Gotchas

- Docker Hub's registry hostname is `docker.io` - not `registry.hub.docker.com`
- Harbor and other self-hosted registries use their FQDN as the key
- If a login is missing or the secret is empty, the build will fail at the pull or push step with an authentication error
