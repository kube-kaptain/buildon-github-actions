# Kubernetes Bundle - Vendor Helm Rendered

> See [Guide Usage](../guides/README.md) for how to use the three files.

Minimum example - the chart-source fields shown in `KaptainPM.yaml` are
required, but no other overrides are applied. Pick either `ociChart` or
the `repoUrl` + `chartName` pair (XOR).

Renders a vendor Helm chart into individual manifests, processes and
validates them, then packages with token substitution.
