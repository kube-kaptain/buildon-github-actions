# Retag Upstream Image

> See [Guide Usage](../README.md) for how to use these guides.

Pull an upstream vendor image and push it to your private registry under your
own versioning scheme.

This is useful when you want to mirror third-party images (e.g. nginx, redis)
into your organisation's GHCR or other registry, giving you control over what
versions are deployed and a single source of truth for image provenance along
with guaranteed stability over time since tags are by default immutable in this
system.

## How it works

The `docker-build-retag` workflow pulls the source image specified in `KaptainPM.yaml`,
then pushes it to your target registry with your chosen version tag. No Dockerfile
is needed - the image content is unchanged.

## Version strategy

For retag workflows, you typically want one of:

- **retag-workflow-source-tag** - use the upstream tag as-is (e.g. `1.25`)
- **file-pattern-match** - extract a version from a file in your repo

The default `git-auto-closest-highest` strategy also works if you want your own
independent version sequence.

## Gotchas

- The source image config (registry, namespace, image name, tag) lives entirely
  in `KaptainPM.yaml` under `spec.main.docker.retag`
- If the upstream registry requires authentication, add it under `spec.main.docker.logins`
- The source tag is a string - always quote numeric tags like `'1.25'` in YAML
