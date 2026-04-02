# Multi-Registry Push

> See [Guide Usage](../README.md) for how to use these guides.

Build a Docker image and push it to multiple registries - GHCR plus one or more
additional registries such as AWS ECR.

This is common in multi-cloud or multi-account setups where the same image needs
to be available in several locations for example Lambda where you want the image
in N accounts - the build can publish to the primary registry and N other ones as
needed. Lambda only accepts ECR images so this feature is useful for that. Another
use case would be to have an entire second registry as a live backup in case of DR.

## How it works

GHCR is always the primary registry and its login is handled automatically. To
push to additional registries, you configure two things in `KaptainPM.yaml`:

1. **`docker.logins`** - credentials for each additional registry
2. **`docker.pushTargets`** - the list of additional registries to push to

The workflow builds the image once, then pushes it to GHCR and every entry in `pushTargets`.

## Secrets

Each login references GitHub Actions secrets by name. In the example, `ECR_USER_EAST`
and `ECR_TOKEN_EAST` must be set in your repository or organisation secrets.

The `build.yaml` passes secrets to the reusable workflow via `docker-registry-logins-secrets`.
This is a JSON blob the workflow constructs from your `KaptainPM.yaml` login
config - you just need to make sure the referenced secrets exist.

## Gotchas

- GHCR login is automatic - do not add it to `docker.logins`
- Each `pushTargets` entry must have a corresponding `docker.logins` entry or the push will fail with an auth error
- ECR tokens expire - use a mechanism like OIDC or a token refresh step if your tokens are short-lived
