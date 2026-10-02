# Run Platform With Environments

> See [Guide Usage](../README.md) for how to use these guides.

A run platform deploys the environments listed in its `spec.contents`.

* **Secrets it owns.** Each environment's deployer needs values the
  environment cannot supply for itself. Put them in the run platform's
  `src/secrets/`, encrypted:
  * `<Environment>/EnvironmentPassphrase.age` per environment, the token name
    style form of its project name (`run-shop-prod` is `RunShopProd`);
  * any token an environment's own deploy-image Secret uses;
  * `ImagePullSecrets/<Registry>/Username.age` and `Password.age` for the
    registries its manifests pull from.
* **Signoffs.** The environments' deployers carry RBAC, so they need signoffs
  in `src/signoffs/<environment>/...`. The first build writes skeletons under
  `kaptain-out/run-finalise/signoffs-needed/` to review and copy in.
* **Seeding.** An environment deployer marked seed-and-compare (the default,
  `imageDeployManifestsApplyMode`) is set aside at deploy time, not applied
  with the rest. An environment built with `enforce-state-normally` is applied
  like any other resource.
* **Delegated cluster-scoped resources** from environments built with
  `clusterScopedDelegation: parent` are collected into the run platform's
  deploy image at `/kd/cluster-scoped-on-behalf/`. Applying them is not in the
  deploy scripts yet.

Environments must be released before a run platform build can resolve them.
