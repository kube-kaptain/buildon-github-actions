# Kubernetes Run Environment

> See [Guide Usage](../guides/README.md) for how to use the three files.

Minimal build: one app in `spec.contents` and every setting defaulted.

Builds a deployable environment from its `spec.contents` children and any
local manifests in `src/kubernetes`:

* the deploy image, carrying the finalised workload and baked env-var contract
* a deploy-manifests set that runs that image, for the run platform that
  deploys this environment
* the environment contents and provenance zips, published on the release

Config values go in `src/config`, encrypted secret values in `src/secrets`.
Defaults: deployment mode with keelson auto-update, the environment applies its
own cluster-scoped resources, and its deployer is seeded by its run platform.

Guides for other shapes: [job mode](../guides/run-environment-job-mode/README.md),
[delegated cluster-scoped resources](../guides/run-environment-delegated-cluster-scoped/README.md),
[config and secrets](../guides/run-environment-config-and-secrets/README.md).
