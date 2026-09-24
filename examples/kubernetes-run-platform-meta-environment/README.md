# Kubernetes Run Platform Meta Environment

> See [Guide Usage](../guides/README.md) for how to use the three files.

Minimal build: one environment in `spec.contents` and every setting defaulted.

A run platform manages a cluster. Its `spec.contents` are environments
(`run-*`), consumed through their deploy-manifests sets. It builds a deploy
image holding those sets, its own deploy-manifests set (so it can redeploy
itself), and any cluster-scoped resources its environments delegate to it
(collected, not yet applied by the deploy scripts).

Each environment's deployer is marked seed-and-compare by default and is set
aside at deploy time rather than applied with the rest. The run platform owns
the secrets its environments' deployers need, such as each
`<Environment>/EnvironmentPassphrase`, in its own `src/secrets`.

See [run platform with environments](../guides/run-platform-with-environments/README.md).
