# Run Environment With Delegated Cluster-Scoped Resources

> See [Guide Usage](../README.md) for how to use these guides.

For an environment whose deployer should only hold rights in its own
namespace.

With `clusterScopedDelegation: parent` the build carves the cluster-scoped
resources (CRDs, ClusterRoles, webhooks and the like) out of the deploy image
into a separate `-cluster-scoped-resources.zip`, published with the
environment's manifests. The run platform that lists this environment in its
`spec.contents` collects that zip into its own deploy image, at
`/kd/cluster-scoped-on-behalf/`, to apply with its cluster rights. Applying
that set is not in the deploy scripts yet.

The default, `self`, keeps everything in the environment's own deploy and gives
its deployer the rights to apply it.

Sensitive resources (RBAC, webhooks, ingress) need a signoff in
`src/signoffs/`, mirroring their path in the manifest tree. A build that
finds one without writes a ready-to-review skeleton under
`kaptain-out/run-finalise/signoffs-needed/`.
