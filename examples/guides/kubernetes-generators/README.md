# Kubernetes Generators

> See [Guide Usage](../README.md) for how to use these guides.

Configure how Kubernetes manifests are generated for your workload.

## Generator sections

- **common** - Labels and annotations applied to all generated manifests.
- **workload** - The main workload resource. Set `type` to one of: `deployment`, `cronjob`, `daemonset`, or `job`.
- **service** - Whether to generate a Service resource.
- **serviceAccount** - Whether to generate a ServiceAccount.

## Workload types

For `deployment`, you can set replicas, revision history, and container settings
such as port and security context options.

For `cronjob`, additional fields are available: `schedule`,
`successfulJobsHistoryLimit`, and `failedJobsHistoryLimit`.

For `daemonset` and `job`, the relevant Kubernetes fields are exposed in the
same nested structure.

## Container settings

Container configuration sits under `workload.container` and controls port,
resource requests/limits, security context flags like `readonlyRootFilesystem`,
and probe definitions.
