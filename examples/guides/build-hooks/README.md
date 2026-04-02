# Build Hooks

> See [Guide Usage](../README.md) for how to use these guides.

Wire up custom scripts at various points in the build pipeline.Each hook value
is a path to an executable script in the repository. Unconfigured empty hooks
are skipped, misconfigured non-existent scripts or scripts that are not marked
as executable cause a failure.

## Hook points

Hooks run in this order during the build:

- **preBuild** - runs before quality checks. Setup tasks, generated files,
  dependency installation, environment preparation.

- **preTaggingTests** - runs after quality checks, before the version tag.
  Unit tests, linting, static analysis, licence checks.

- **postVersionsAndNaming** - runs after the version is determined.
  Version-dependent code generation, changelog updates, build metadata.

- **preDockerPrepare** - runs before Docker build preparation.
  Downloading build-time dependencies, generating Dockerfile fragments,
  preparing build context.

- **postDockerTests** - runs after the Docker image is built.
  Container smoke tests, vulnerability scanning, image size checks,
  integration tests against the built image.

- **prePackagePrepare** - runs before manifest/spec packaging.
  Generating additional manifests, validating config, preparing
  packaging inputs.

- **postPackageTests** - runs after packaging is complete.
  Validating packaged output, dry-run deployments, package integrity
  checks.

- **postBuild** - runs at the end of the pipeline.
  Cleanup, notifications, metrics, triggering downstream pipelines.

## Notes

- Scripts must be executable (`chmod +x`).
- Each script receives the build environment variables set by earlier
  stages (version, image name, registry, etc).
- Not all hooks are available in all workflow types - docker hooks only
  run in docker workflows, package hooks only in kubernetes app workflows.
