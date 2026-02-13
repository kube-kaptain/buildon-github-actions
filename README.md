# Build On GitHub Actions

Reusable GitHub Actions for CI/CD pipelines with quality enforcement and automatic versioning.

## Features

- **Quality enforcement** - Block GitHub UI branch names, default commit messages, merge commits, unrebased branches
- **Automatic versioning** - Semantic version tags based on git history, supports any number of version parts
- **Patch branch support** - Configure additional release branches for hotfix workflows

## Quick Start

Reference the reusable workflow from your repo:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: kube-kaptain/buildon-github-actions/.github/workflows/basic-quality-and-versioning.yaml@v1
    permissions:
      contents: write
```

See [`examples/`](examples/) for more usage patterns.

## Examples

<!-- EXAMPLES-START -->
| Example | Description |
|---------|-------------|
| [`additional-release-branches.yaml`](examples/additional-release-branches.yaml) | Support hotfix workflows by building on branches other than the default and still getting releases published |
| [`basic-quality-and-versioning.yaml`](examples/basic-quality-and-versioning.yaml) | Standard build setup |
| [`cronjob-history-and-cleanup.yaml`](examples/cronjob-history-and-cleanup.yaml) | CronJobs in Kaptain use sensible defaults for history retention and cleanup |
| [`daemonset-privileged-and-tolerations.yaml`](examples/daemonset-privileged-and-tolerations.yaml) | This example demonstrates a DaemonSet configured for system-level agents that |
| [`docker-build-dockerfile-no-squash.yaml`](examples/docker-build-dockerfile-no-squash.yaml) | Build a Docker image without --squash, preserving layer history |
| [`docker-build-dockerfile.yaml`](examples/docker-build-dockerfile.yaml) | Build a Docker image from a Dockerfile with --squash (default) to flatten |
| [`docker-build-retag-base-path.yaml`](examples/docker-build-retag-base-path.yaml) | Many registries use base paths in addition to the normal image name for projects or teams |
| [`docker-build-retag-custom-registry.yaml`](examples/docker-build-retag-custom-registry.yaml) | Push to a registry other than GHCR (Nexus, ECR, GCR, Harbor, etc) |
| [`docker-build-retag.yaml`](examples/docker-build-retag.yaml) | Pull an upstream image, retag with your name and new version, push to your registry |
| [`docker-push-targets.yaml`](examples/docker-push-targets.yaml) | Push the same Docker image to multiple registries |
| [`docker-registry-logins-explicit.yaml`](examples/docker-registry-logins-explicit.yaml) | docker-registry-logins-secrets |
| [`docker-registry-logins-ghcr-pat.yaml`](examples/docker-registry-logins-ghcr-pat.yaml) |   - Push to packages in a different repo or org (GITHUB_TOKEN is scoped to current repo) |
| [`github-release-options.yaml`](examples/github-release-options.yaml) | All workflows that include versions-and-naming create GitHub releases by default |
| [`job-versioned-naming.yaml`](examples/job-versioned-naming.yaml) | Jobs in Kaptain use a unique naming strategy designed for "run once per version" |
| [`kube-app-generators.yaml`](examples/kube-app-generators.yaml) | This example demonstrates how to use the Kubernetes manifest generators with |
| [`optional-test-scripts.yaml`](examples/optional-test-scripts.yaml) | Shows how to add custom test scripts to workflows that support them |
| [`quality-only.yaml`](examples/quality-only.yaml) | Enforce quality standards on PRs without automatic tagging |
| [`spec-check-filter-release.yaml`](examples/spec-check-filter-release.yaml) | Build and release JSON Schema or API spec files |
| [`version-exact-from-file.yaml`](examples/version-exact-from-file.yaml) | Use the version found in a source file as-is, without incrementing |
| [`version-from-compound-sources.yaml`](examples/version-from-compound-sources.yaml) | Combine versions from TWO source files to create a compound version |
| [`version-from-custom-pattern.yaml`](examples/version-from-custom-pattern.yaml) | Extract version from any file using a custom regex pattern |
| [`version-from-dockerfile.yaml`](examples/version-from-dockerfile.yaml) | Extract version from an ENV variable in your Dockerfile rather than using git tags |
| [`version-from-retag-source-tag.yaml`](examples/version-from-retag-source-tag.yaml) | Extract version from the source-tag input in a retag workflow file |
| [`version-prefix-parts.yaml`](examples/version-prefix-parts.yaml) | Control how many parts of the source version become the prefix for auto-incrementing |
<!-- EXAMPLES-END -->

## Components

### Workflows

<!-- WORKFLOWS-START -->
| Workflow | Description |
|----------|-------------|
| `basic-quality-checks.yaml` | Enforces basic quality - blocks bad branch names, bad commit messages, and bad branch structure |
| `basic-quality-and-versioning.yaml` | Quality checks and naming/versioning combined - the standard foundation for most projects |
| `docker-build-dockerfile.yaml` | Everything from quality and versions above, but also builds a docker image from a Dockerfile |
| `docker-build-retag.yaml` | Everything from quality and version above, but also pulls, retags, and republishes a docker image |
| `kubernetes-app-manifests-only.yaml` | Everything from quality and version above, plus packages Kubernetes manifests with token substitution |
| `kubernetes-app-docker-dockerfile.yaml` | Everything from both docker Dockerfile and Kubernetes manifest packaging - a full kube app build |
| `kubernetes-app-docker-retag.yaml` | Everything from both docker retag and Kubernetes manifest packaging - for apps using upstream images |
| `spec-check-filter-release.yaml` | Everything from quality and version above, but also validates and packages a JSON Schema or an API Spec |
<!-- WORKFLOWS-END -->

### Actions

<!-- ACTIONS-START -->
| Action | Description |
|--------|-------------|
| `basic-quality-checks` | Basic quality checks for commits and branches |
| `docker-build-dockerfile` | Builds a Docker image from a Dockerfile with token substitution (build only, push handled by docker-push-all) |
| `docker-build-retag` | Pulls and retags Docker images (no push) |
| `docker-multi-tag` | Tags a Docker image for multiple registries |
| `docker-push-all` | Pushes all Docker images registered during build/tag steps |
| `docker-registry-logins` | Authenticate to container registries (GHCR by default, configure others as needed) |
| `generate-kubernetes-configmap` | Generates a Kubernetes ConfigMap manifest from files in a directory |
| `generate-kubernetes-poddisruptionbudget` | Generates a Kubernetes PodDisruptionBudget manifest for controlling voluntary disruptions |
| `generate-kubernetes-secret-template` | Generates a Kubernetes Secret template manifest from files in a directory |
| `generate-kubernetes-service` | Generates a Kubernetes Service manifest with tokenized values |
| `generate-kubernetes-serviceaccount` | Generates a Kubernetes ServiceAccount manifest for pod identity and RBAC binding |
| `generate-kubernetes-workload` | Routes to appropriate workload generator (Deployment, StatefulSet, etc.) |
| `git-push-tag` | Pushes an existing git tag to origin |
| `github-check-run` | Create or update GitHub Check Runs for granular PR status reporting |
| `github-release-prepare` | Prepares files for GitHub release with optional substitution and version suffix |
| `github-release` | Create GitHub release with assets from prepared directory |
| `hook-post-docker-tests` | Runs user's hook script after Docker image is built for integration tests, security scans, or validation |
| `hook-post-package-tests` | Runs user's hook script after manifest packaging for validation, additional tests, or verification |
| `hook-pre-docker-prepare` | Runs user's hook script before Docker build preparation to modify Dockerfile, copy files, or perform setup |
| `hook-pre-package-prepare` | Runs user's hook script before manifest packaging to generate ConfigMaps, modify manifests, or add files |
| `hook-pre-tagging-tests` | Runs user's hook script before tagging/versioning for custom validation or preparation |
| `kubernetes-manifests-package-only-token-override` | Overrides docker image tokens for manifests-only workflow |
| `kubernetes-manifests-package-prepare` | Prepares manifests and tokens for packaging |
| `kubernetes-manifests-package` | Packages Kubernetes manifests into a zip with variable substitution |
| `kubernetes-manifests-repo-provider-package` | Packages manifests for repo provider (builds docker image). Does NOT publish. |
| `kubernetes-manifests-repo-provider-publish` | Publishes manifests via pluggable repo provider. Requires package step to run first. |
| `resolve-target-registry-and-base-path` | Resolves target registry (defaults to ghcr.io) and computes base path (auto-detects org for GHCR) |
| `validate-tooling` | Validates required tools are available before build |
| `versions-and-naming` | Generates version numbers, tags, and naming for releases |
<!-- ACTIONS-END -->

## Configuration

### All Inputs

<!-- INPUTS-START -->
| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `allow-builtin-token-override` | boolean | `false` | Allow user tokens to override built-in tokens (for template/reusable projects) |
| `block-slashes` | boolean | `false` | DEPRECATED: Use block-slash-containing-branches instead |
| `config-sub-path` | string | `src/config` | Directory containing user-defined token files (relative) |
| `config-value-trailing-newline` | string | `strip-for-single-line` | How to handle trailing newlines in config values (strip-for-single-line, preserve-all, always-strip-one-newline) |
| `docker-image-name-override` | string | `""` | Docker image name (if provided, substitutes into manifests; if empty, token remains for later substitution) |
| `docker-image-tag-override` | string | `""` | Docker image tag (if provided, substitutes into manifests; if empty, token remains for later substitution) |
| `docker-push-targets` | string | `""` | JSON array of additional push targets [{registry, base-path?}] |
| `docker-registry-logins` | string | `""` | YAML config for Docker registry logins (registry URL as key) |
| `docker-source-base-path` | string | `""` | Path between registry and image name (e.g., library) |
| `docker-source-image-name` | string | *required* | Upstream image name (e.g., nginx) |
| `docker-source-registry` | string | *required* | Upstream registry (e.g., docker.io) |
| `docker-source-tag` | string | *required* | Upstream image tag (e.g., 1.25) |
| `docker-target-base-path` | string | `""` | Path between registry and image name (defaults to lower cased org name on gh actions) |
| `docker-target-registry` | string | `""` | Target container registry domain (defaults to ghcr.io on gh actions) |
| `dockerfile-no-cache` | boolean | `true` | Disable layer caching for reproducible builds |
| `dockerfile-squash` | string | `squash` | Squash mode: squash, squash-all, or no |
| `dockerfile-sub-path` | string | `src/docker` | Directory containing Dockerfile, relative to repo root. |
| `dockerfile-substitution-files` | string | `Dockerfile` | Comma-separated list of files to perform token substitution on (relative to dockerfile-sub-path and docker-context-sub-path) |
| `github-release-add-version-to-filenames` | boolean | `true` | Add version suffix to release filenames (e.g., file.yaml -> file-1.2.3.yaml) |
| `github-release-enabled` | boolean | `true` | Create a GitHub release on version tags |
| `github-release-notes` | string | `""` | Inline release notes string (mutually exclusive with github-release-notes-file) |
| `github-release-notes-file` | string | `""` | Path to release notes file (mutually exclusive with github-release-notes) |
| `github-release-substituted-files` | string | `""` | Files with token substitution and version suffix (space-separated) |
| `github-release-verbatim-files` | string | `""` | Files copied as-is with version suffix only (space-separated) |
| `hook-post-docker-tests-script-sub-path` | string | `""` | Path to post-docker test script relative to .github/ (e.g., bin/post-docker.bash) |
| `hook-post-package-tests-script-sub-path` | string | `""` | Path to post-package test script relative to .github/ (e.g., bin/post-package.bash) |
| `hook-pre-docker-prepare-script-sub-path` | string | `""` | Path to pre-docker prepare script relative to .github/ (e.g., bin/pre-docker-prepare.bash) |
| `hook-pre-package-prepare-script-sub-path` | string | `""` | Path to pre-package prepare script relative to .github/ (e.g., bin/pre-package-prepare.bash) |
| `hook-pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `kubernetes-configmap-additional-annotations` | string | `""` | Additional annotations specific to ConfigMap (comma-separated key=value) |
| `kubernetes-configmap-additional-labels` | string | `""` | Additional labels specific to ConfigMap (comma-separated key=value) |
| `kubernetes-configmap-name-checksum-injection` | boolean | `true` | Enable checksum injection suffix in ConfigMap name |
| `kubernetes-configmap-sub-path` | string | `src/configmap` | Directory containing ConfigMap data files (relative) |
| `kubernetes-cronjob-active-deadline-seconds` | string | `""` | Maximum time in seconds the job can run (optional) |
| `kubernetes-cronjob-additional-annotations` | string | `""` | Additional annotations for CronJob resources (key=value,key=value) |
| `kubernetes-cronjob-additional-labels` | string | `""` | Additional labels for CronJob resources (key=value,key=value) |
| `kubernetes-cronjob-backoff-limit` | string | `0` | Number of retries before marking job as failed (0 = fail immediately) |
| `kubernetes-cronjob-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-cronjob-completions` | string | `1` | Number of successful completions needed |
| `kubernetes-cronjob-concurrency-policy` | string | `Forbid` | How to handle concurrent job runs (Allow, Forbid, Replace) |
| `kubernetes-cronjob-env-sub-path` | string | `""` | Path to CronJob environment variables directory |
| `kubernetes-cronjob-failed-jobs-history-limit` | string | `5` | Number of failed jobs to retain to show failure patterns |
| `kubernetes-cronjob-liveness-probe-enabled` | string | `false` | Enable liveness probe (uses workload probe settings when true) |
| `kubernetes-cronjob-name-suffix` | string | `""` | Optional suffix for CronJob name and filename |
| `kubernetes-cronjob-parallelism` | string | `1` | Number of pods running at any time |
| `kubernetes-cronjob-readiness-probe-enabled` | string | `false` | Enable readiness probe (uses workload probe settings when true) |
| `kubernetes-cronjob-restart-policy` | string | `Never` | Pod restart policy (Never or OnFailure) |
| `kubernetes-cronjob-starting-deadline-seconds` | string | `""` | Deadline for starting job if missed scheduled time (optional) |
| `kubernetes-cronjob-startup-probe-enabled` | string | `false` | Enable startup probe (uses workload probe settings when true) |
| `kubernetes-cronjob-successful-jobs-history-limit` | string | `1` | Number of successful jobs to retain for log collection |
| `kubernetes-daemonset-dns-policy` | string | `""` | DNS policy (ClusterFirst, ClusterFirstWithHostNet, Default, None) |
| `kubernetes-daemonset-host-ipc` | string | `false` | Use host IPC namespace (true/false) |
| `kubernetes-daemonset-host-network` | string | `false` | Use host network namespace (true/false) |
| `kubernetes-daemonset-host-pid` | string | `false` | Use host PID namespace (true/false) |
| `kubernetes-daemonset-max-unavailable` | string | `1` | Max unavailable pods during rolling update (number or percentage) |
| `kubernetes-daemonset-node-selector` | string | `""` | Node selector labels (comma-separated key=value) |
| `kubernetes-daemonset-privileged` | string | `false` | Run container in privileged mode (true/false) |
| `kubernetes-daemonset-run-as-non-root` | boolean | `true` | Require non-root user (true/false, set false for system-level DaemonSets that need root) |
| `kubernetes-daemonset-tolerations` | string | `""` | Tolerations as JSON array (e.g., [{"operator":"Exists"}] or [{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]) |
| `kubernetes-daemonset-update-strategy-type` | string | `RollingUpdate` | Update strategy type (RollingUpdate or OnDelete) |
| `kubernetes-deployment-additional-annotations` | string | `""` | Additional annotations for Deployment resources (key=value,key=value) |
| `kubernetes-deployment-additional-labels` | string | `""` | Additional labels for Deployment resources (key=value,key=value) |
| `kubernetes-deployment-env-sub-path` | string | `src/deployment-env` | Path to deployment environment variables directory |
| `kubernetes-deployment-max-surge` | string | `1` | Max surge during rolling update (integer or percentage, e.g., 1 or 25%) |
| `kubernetes-deployment-max-unavailable` | string | `0` | Max unavailable during rolling update (integer or percentage, e.g., 0 or 25%) |
| `kubernetes-global-additional-annotations` | string | `""` | Additional annotations for all Kubernetes manifests (comma-separated key=value) |
| `kubernetes-global-additional-labels` | string | `""` | Additional labels for all Kubernetes manifests (comma-separated key=value) |
| `kubernetes-job-active-deadline-seconds` | string | `""` | Maximum time in seconds the Job can run (optional) |
| `kubernetes-job-additional-annotations` | string | `""` | Additional annotations for Job resources (key=value,key=value) |
| `kubernetes-job-additional-labels` | string | `""` | Additional labels for Job resources (key=value,key=value) |
| `kubernetes-job-backoff-limit` | string | `0` | Number of retries before marking Job as failed (0 = fail immediately) |
| `kubernetes-job-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-job-completions` | string | `1` | Number of successful completions needed |
| `kubernetes-job-env-sub-path` | string | `""` | Path to Job environment variables directory |
| `kubernetes-job-liveness-probe-enabled` | string | `false` | Enable liveness probe (uses workload probe settings when true) |
| `kubernetes-job-name-suffix` | string | `""` | Optional suffix for Job name and filename |
| `kubernetes-job-parallelism` | string | `1` | Number of pods running at any time |
| `kubernetes-job-readiness-probe-enabled` | string | `false` | Enable readiness probe (uses workload probe settings when true) |
| `kubernetes-job-restart-policy` | string | `Never` | Pod restart policy (Never or OnFailure) |
| `kubernetes-job-startup-probe-enabled` | string | `false` | Enable startup probe (uses workload probe settings when true) |
| `kubernetes-job-ttl-seconds-after-finished` | string | `86400` | Cleanup time after Job completion in seconds |
| `kubernetes-poddisruptionbudget-additional-annotations` | string | `""` | Additional annotations specific to PodDisruptionBudget (comma-separated key=value) |
| `kubernetes-poddisruptionbudget-additional-labels` | string | `""` | Additional labels specific to PodDisruptionBudget (comma-separated key=value) |
| `kubernetes-poddisruptionbudget-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-poddisruptionbudget-generation-enabled` | string | `""` | Enable PodDisruptionBudget generation (true, false, or empty for auto based on workload type) |
| `kubernetes-poddisruptionbudget-name-suffix` | string | `""` | Optional suffix for PDB name and filename |
| `kubernetes-poddisruptionbudget-strategy` | string | `max-unavailable` | PDB constraint strategy (min-available or max-unavailable) |
| `kubernetes-poddisruptionbudget-value` | string | `1` | Value for the chosen strategy (integer or percentage, e.g., 1, 50%) |
| `kubernetes-secret-template-additional-annotations` | string | `""` | Additional annotations specific to Secret template (comma-separated key=value) |
| `kubernetes-secret-template-additional-labels` | string | `""` | Additional labels specific to Secret template (comma-separated key=value) |
| `kubernetes-secret-template-name-checksum-injection` | boolean | `true` | Enable checksum injection suffix in Secret name |
| `kubernetes-secret-template-sub-path` | string | `src/secret.template` | Directory containing Secret template data files (relative) |
| `kubernetes-service-additional-annotations` | string | `""` | Additional annotations specific to Service (comma-separated key=value) |
| `kubernetes-service-additional-labels` | string | `""` | Additional labels specific to Service (comma-separated key=value) |
| `kubernetes-service-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-service-external-name` | string | `""` | External DNS name (required for ExternalName type) |
| `kubernetes-service-external-traffic-policy` | string | `""` | External traffic policy (Cluster or Local, NodePort/LoadBalancer only) |
| `kubernetes-service-generation-enabled` | string | `""` | Enable Service generation (true, false, or empty for auto based on workload type) |
| `kubernetes-service-name-suffix` | string | `""` | Optional suffix for Service name and filename |
| `kubernetes-service-node-port` | string | `""` | Node port number (NodePort type only, empty for auto-assign) |
| `kubernetes-service-port` | string | `80` | Service port (not used for ExternalName) |
| `kubernetes-service-port-name` | string | `""` | Named port identifier (optional) |
| `kubernetes-service-protocol` | string | `TCP` | Protocol (TCP, UDP, SCTP) |
| `kubernetes-service-target-port` | string | `""` | Target port (defaults to container port, not used for ExternalName) |
| `kubernetes-service-type` | string | `ClusterIP` | Service type (ClusterIP, Headless, NoSelector, NodePort, LoadBalancer, ExternalName) |
| `kubernetes-serviceaccount-additional-annotations` | string | `""` | Additional annotations specific to ServiceAccount (comma-separated key=value) |
| `kubernetes-serviceaccount-additional-labels` | string | `""` | Additional labels specific to ServiceAccount (comma-separated key=value) |
| `kubernetes-serviceaccount-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-serviceaccount-generation-enabled` | boolean | `false` | Enable ServiceAccount generation |
| `kubernetes-serviceaccount-name-suffix` | string | `""` | Optional suffix for ServiceAccount name and filename |
| `kubernetes-statefulset-additional-annotations` | string | `""` | Additional annotations for StatefulSet resources (key=value,key=value) |
| `kubernetes-statefulset-additional-labels` | string | `""` | Additional labels for StatefulSet resources (key=value,key=value) |
| `kubernetes-statefulset-allow-unreliable-pod-management-policy` | string | `""` | Required acknowledgment to use Parallel pod management (must be I_LIKE_DOWNTIME) |
| `kubernetes-statefulset-env-sub-path` | string | `src/statefulset-env` | Path to statefulset environment variables directory |
| `kubernetes-statefulset-pod-management-policy` | string | `OrderedReady` | Pod management policy (OrderedReady or Parallel) |
| `kubernetes-statefulset-pvc-access-mode` | string | `ReadWriteOnce` | PVC access mode (ReadWriteOnce, ReadOnlyMany, ReadWriteMany) |
| `kubernetes-statefulset-pvc-enabled` | string | `true` | Enable persistent volume claim template (true/false) |
| `kubernetes-statefulset-pvc-mount-path` | string | `/data` | Mount path for the persistent volume |
| `kubernetes-statefulset-pvc-storage-class` | string | `""` | Storage class for PVC (empty for cluster default) |
| `kubernetes-statefulset-pvc-storage-size` | string | `1Gi` | Storage size for PVC (e.g., 1Gi, 10Gi) |
| `kubernetes-statefulset-pvc-volume-name` | string | `data` | Volume name for the PVC template |
| `kubernetes-statefulset-service-name` | string | `""` | Headless service name (empty for auto-derived from project name) |
| `kubernetes-statefulset-update-strategy-partition` | string | `""` | Partition for rolling updates (empty for none) |
| `kubernetes-statefulset-update-strategy-type` | string | `RollingUpdate` | Update strategy type (RollingUpdate or OnDelete) |
| `kubernetes-workload-additional-annotations` | string | `""` | Additional annotations specific to workload (comma-separated key=value) |
| `kubernetes-workload-additional-labels` | string | `""` | Additional labels specific to workload (comma-separated key=value) |
| `kubernetes-workload-affinity-strategy` | string | `spread-nodes-and-zones-ha` | Pod affinity strategy plugin name |
| `kubernetes-workload-automount-service-account-token` | boolean | `false` | Automount service account token |
| `kubernetes-workload-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-workload-configmap-keys-for-env` | string | `""` | Comma/space-separated ConfigMap keys to expose as env vars |
| `kubernetes-workload-configmap-mount-path` | string | `/configmap` | ConfigMap mount path in container |
| `kubernetes-workload-container-args` | string | `""` | Container args override (space-separated, respects quotes like shell) |
| `kubernetes-workload-container-command` | string | `""` | Container command override (space-separated, respects quotes like shell) |
| `kubernetes-workload-container-port` | string | `1024` | Container port |
| `kubernetes-workload-dns-policy` | string | `""` | DNS policy (ClusterFirst, ClusterFirstWithHostNet, Default, None) |
| `kubernetes-workload-env-sub-path` | string | `""` | Directory containing environment variable files (default per workload type) |
| `kubernetes-workload-image-pull-secrets` | string | `ENABLED` | Include imagePullSecrets in pod spec (ENABLED/DISABLED) |
| `kubernetes-workload-image-reference-style` | string | `combined` | Image reference style (combined, separate, project-name-prefixed-combined, project-name-prefixed-separate) |
| `kubernetes-workload-min-ready-seconds` | string | `0` | Minimum seconds a pod must be ready before considered available (0 to disable) |
| `kubernetes-workload-name-suffix` | string | `""` | Optional suffix for workload name and filename |
| `kubernetes-workload-node-selector` | string | `""` | Node selector (comma-separated key=value pairs, e.g., disktype=ssd,zone=us-east-1a) |
| `kubernetes-workload-prestop-command` | string | `""` | PreStop hook command (empty for none) |
| `kubernetes-workload-priority-class-name` | string | `""` | Priority class name for pod scheduling priority |
| `kubernetes-workload-probe-liveness-check-type` | string | `http-get` | Liveness probe type (http-get, tcp-socket, exec, grpc, none) |
| `kubernetes-workload-probe-liveness-exec-command` | string | `""` | Liveness probe exec command |
| `kubernetes-workload-probe-liveness-failure-threshold` | string | `3` | Liveness probe failure threshold |
| `kubernetes-workload-probe-liveness-grpc-port` | string | `""` | Liveness probe gRPC port (defaults to container port) |
| `kubernetes-workload-probe-liveness-grpc-service` | string | `""` | Liveness probe gRPC service name |
| `kubernetes-workload-probe-liveness-http-path` | string | `/liveness` | Liveness probe HTTP path |
| `kubernetes-workload-probe-liveness-http-scheme` | string | `HTTP` | Liveness probe HTTP scheme (HTTP, HTTPS) |
| `kubernetes-workload-probe-liveness-initial-delay-seconds` | string | `10` | Liveness probe initial delay in seconds |
| `kubernetes-workload-probe-liveness-period-seconds` | string | `10` | Liveness probe period in seconds |
| `kubernetes-workload-probe-liveness-tcp-port` | string | `""` | Liveness probe TCP port (defaults to container port) |
| `kubernetes-workload-probe-liveness-termination-grace-period-seconds` | string | `""` | Liveness probe termination grace period (empty for default) |
| `kubernetes-workload-probe-liveness-timeout-seconds` | string | `5` | Liveness probe timeout in seconds |
| `kubernetes-workload-probe-readiness-check-type` | string | `http-get` | Readiness probe type (http-get, tcp-socket, exec, grpc, none) |
| `kubernetes-workload-probe-readiness-exec-command` | string | `""` | Readiness probe exec command |
| `kubernetes-workload-probe-readiness-failure-threshold` | string | `3` | Readiness probe failure threshold |
| `kubernetes-workload-probe-readiness-grpc-port` | string | `""` | Readiness probe gRPC port (defaults to container port) |
| `kubernetes-workload-probe-readiness-grpc-service` | string | `""` | Readiness probe gRPC service name |
| `kubernetes-workload-probe-readiness-http-path` | string | `/readiness` | Readiness probe HTTP path |
| `kubernetes-workload-probe-readiness-http-scheme` | string | `HTTP` | Readiness probe HTTP scheme (HTTP, HTTPS) |
| `kubernetes-workload-probe-readiness-initial-delay-seconds` | string | `5` | Readiness probe initial delay in seconds |
| `kubernetes-workload-probe-readiness-period-seconds` | string | `5` | Readiness probe period in seconds |
| `kubernetes-workload-probe-readiness-success-threshold` | string | `1` | Readiness probe success threshold |
| `kubernetes-workload-probe-readiness-tcp-port` | string | `""` | Readiness probe TCP port (defaults to container port) |
| `kubernetes-workload-probe-readiness-timeout-seconds` | string | `3` | Readiness probe timeout in seconds |
| `kubernetes-workload-probe-startup-check-type` | string | `http-get` | Startup probe type (http-get, tcp-socket, exec, grpc, none) |
| `kubernetes-workload-probe-startup-exec-command` | string | `""` | Startup probe exec command |
| `kubernetes-workload-probe-startup-failure-threshold` | string | `30` | Startup probe failure threshold |
| `kubernetes-workload-probe-startup-grpc-port` | string | `""` | Startup probe gRPC port (defaults to container port) |
| `kubernetes-workload-probe-startup-grpc-service` | string | `""` | Startup probe gRPC service name |
| `kubernetes-workload-probe-startup-http-path` | string | `/startup` | Startup probe HTTP path |
| `kubernetes-workload-probe-startup-http-scheme` | string | `HTTP` | Startup probe HTTP scheme (HTTP, HTTPS) |
| `kubernetes-workload-probe-startup-initial-delay-seconds` | string | `0` | Startup probe initial delay in seconds |
| `kubernetes-workload-probe-startup-period-seconds` | string | `5` | Startup probe period in seconds |
| `kubernetes-workload-probe-startup-tcp-port` | string | `""` | Startup probe TCP port (defaults to container port) |
| `kubernetes-workload-probe-startup-termination-grace-period-seconds` | string | `""` | Startup probe termination grace period (empty for default) |
| `kubernetes-workload-probe-startup-timeout-seconds` | string | `3` | Startup probe timeout in seconds |
| `kubernetes-workload-readonly-root-filesystem` | boolean | `true` | Enable read-only root filesystem |
| `kubernetes-workload-replicas` | string | `""` | Replica count (empty for token, NO for HPA management, number for fixed) |
| `kubernetes-workload-resources-cpu-limit` | string | `""` | CPU limit (empty for no limit) |
| `kubernetes-workload-resources-cpu-request` | string | `100m` | CPU request (e.g., 100m, 1) |
| `kubernetes-workload-resources-ephemeral-storage` | string | `10Mi` | Ephemeral storage request/limit (e.g., 10Mi, 100Mi, 1Gi) |
| `kubernetes-workload-resources-memory` | string | `10Mi` | Memory limit (e.g., 128Mi, 1Gi) |
| `kubernetes-workload-revision-history-limit` | string | `10` | Number of revisions to retain (ReplicaSets for Deployment, ControllerRevisions for StatefulSet) |
| `kubernetes-workload-seccomp-profile` | string | `DISABLED` | Seccomp profile (DISABLED, RuntimeDefault, Localhost, Unconfined) |
| `kubernetes-workload-secret-keys-for-env` | string | `""` | Comma/space-separated Secret keys to expose as env vars |
| `kubernetes-workload-secret-mount-path` | string | `/secret` | Secret mount path in container |
| `kubernetes-workload-termination-grace-period-seconds` | string | `10` | Termination grace period in seconds |
| `kubernetes-workload-tolerations` | string | `""` | Tolerations as JSON array (e.g., [{"key":"dedicated","operator":"Equal","value":"app","effect":"NoSchedule"}]) |
| `kubernetes-workload-type` | string | `deployment` | Workload type to generate (deployment, statefulset, daemonset, none) |
| `manifests-packaging-base-image` | string | `""` | Base image for manifest packaging (default: scratch) |
| `manifests-repo-provider-type` | string | `docker` | Repo provider type for manifest storage (default: docker, currently the only supported provider) |
| `manifests-sub-path` | string | `src/kubernetes` | Directory containing Kubernetes manifests (relative) |
| `output-sub-path` | string | `target` | Build output directory (relative) |
| `qc-block-conventional-commits` | boolean | `false` | Block commits that use conventional commit format |
| `qc-block-double-hyphen-containing-branches` | boolean | `true` | Block branch names containing double hyphens (typo detection) |
| `qc-block-duplicate-commit-messages` | boolean | `true` | Block PRs where two or more commits have identical messages |
| `qc-block-slash-containing-branches` | boolean | `false` | Block branch names containing slashes |
| `qc-require-conventional-branches` | boolean | `false` | Require branch names start with feature/, fix/, etc. |
| `qc-require-conventional-commits` | boolean | `false` | Require commits use conventional commit format (feat:, fix:, etc.) |
| `release-branch` | string | `main` | The release branch name |
| `spec-packaging-base-image` | string | `scratch` | Base image for spec packaging |
| `spec-type` | string | *required* | Type of spec (schema or api) |
| `spec-validation-type` | string | `basic` | Schema validator to use (basic, python3-jsonschema) |
| `tag-version-calculation-strategy` | string | `git-auto-closest-highest` | Strategy for calculating version (git-auto-closest-highest, file-pattern-match, compound-file-pattern-match) |
| `tag-version-max-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `tag-version-pattern-type` | string | `dockerfile-env-kubectl` | Pattern type for file-pattern-match strategy (dockerfile-env-kubectl, retag-workflow-source-tag, custom) |
| `tag-version-prefix-parts` | string | `""` | Number of parts from source version to use as prefix (default 2, output = prefix + 1 parts). Ignored when tag-version-use-source-version-exact is true. |
| `tag-version-source-custom-pattern` | string | `""` | Regex with capture group for version extraction (required for custom pattern type) |
| `tag-version-source-file-name` | string | `""` | Override source file name (defaults based on pattern type) |
| `tag-version-source-sub-path` | string | `""` | Override path to source directory (takes precedence over dockerfile-sub-path) |
| `tag-version-source-two-file-name` | string | `""` | Source TWO file name (defaults to source ONE file name) |
| `tag-version-source-two-pattern` | string | `""` | Regex with capture group for source TWO (required if same file as source ONE) |
| `tag-version-source-two-prefix-parts` | string | `""` | Number of parts from source TWO version to use in prefix (default 2). Ignored when tag-version-use-source-version-exact is true. |
| `tag-version-source-two-sub-path` | string | `""` | Path to source TWO directory (defaults to source ONE path) |
| `tag-version-use-source-version-exact` | boolean | `false` | Use the exact version found in source file(s) without incrementing (file-based strategies only) |
| `token-delimiter-style` | string | `shell` | Token delimiter syntax for variables (shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift) |
| `token-name-style` | string | `PascalCase` | Case style for token names (UPPER_SNAKE, lower_snake, lower-kebab, UPPER-KEBAB, camelCase, PascalCase, lower.dot, UPPER.DOT) |
| `token-name-validation` | string | `MATCH` | How to validate user token names (MATCH = must match token-name-style, ALL = accept any valid name) |
<!-- INPUTS-END -->

### Secrets

<!-- SECRETS-START -->
| Secret | Description |
|--------|-------------|
| `docker-registry-logins-secrets` | JSON object of secrets for docker-registry-logins (e.g., {"DOCKER_USER": "x", "DOCKER_PASS": "y"}) |
<!-- SECRETS-END -->

### Workflow Documentation

<!-- WORKFLOW-DOCS-START -->
| Workflow | Description | Documentation |
|----------|-------------|---------------|
| `basic-quality-and-versioning.yaml` | Basic Quality and Versioning | [docs/basic-quality-and-versioning.md](docs/basic-quality-and-versioning.md) |
| `basic-quality-checks.yaml` | Basic Quality Checks | [docs/basic-quality-checks.md](docs/basic-quality-checks.md) |
| `docker-build-dockerfile.yaml` | Docker Build Dockerfile | [docs/docker-build-dockerfile.md](docs/docker-build-dockerfile.md) |
| `docker-build-retag.yaml` | Docker Build Retag | [docs/docker-build-retag.md](docs/docker-build-retag.md) |
| `kubernetes-app-docker-dockerfile.yaml` | Kubernetes App - Docker Dockerfile | [docs/kubernetes-app-docker-dockerfile.md](docs/kubernetes-app-docker-dockerfile.md) |
| `kubernetes-app-docker-retag.yaml` | Kubernetes App - Docker Retag | [docs/kubernetes-app-docker-retag.md](docs/kubernetes-app-docker-retag.md) |
| `kubernetes-app-manifests-only.yaml` | Kubernetes App - Manifests Only | [docs/kubernetes-app-manifests-only.md](docs/kubernetes-app-manifests-only.md) |
| `spec-check-filter-release.yaml` | Spec Check Filter Release | [docs/spec-check-filter-release.md](docs/spec-check-filter-release.md) |
<!-- WORKFLOW-DOCS-END -->

## Versioning

Tags are generated based on the closest annotated tag in git history:

- **No tags**: Starts at `1.0.0`
- **Single-part**: (`42`): Increments to `43`
- **Two-part** (`1.2`): Increments to `1.3`
- **Three-part** (`1.2.3`): Increments to `1.2.4`
- **Four-part** (`1.2.3.4`): Increments to `1.2.3.5` (requires `max-version-parts: 4`)

Non-release branches get `-PRERELEASE` suffix on Docker tags.

### Tag Selection

The algorithm finds the right tag to increment:

1. **Find closest tag**: Walk commit history from HEAD, find the nearest annotated tag by commit distance
2. **Break ties by date**: If multiple tags are equidistant (e.g., after a merge), use the newest by creation date
3. **Scan entire repo**: Look up the highest version in that series across all branches (handles isolated/orphan branches)
4. **Increment**: Bump the last component of the highest version found

This means:
- A backfilled tag on an older commit won't hijack your series
- After merging branches with different tags, the newest tag wins
- Hotfix branches can't accidentally collide with main's newer versions

### Alternative: Dockerfile ENV Version

For version-locked images (kubectl, helm, terraform), use `dockerfile-env-version` strategy:

```yaml
uses: kube-kaptain/buildon-github-actions/.github/workflows/docker-build-dockerfile.yaml@v1
with:
  tag-version-calculation-strategy: dockerfile-env-version
  dockerfile-sub-path: src/docker      # default
  env-variable-name: KUBECTL_VERSION   # default
```

This extracts the version from your Dockerfile's `ENV` line:

```dockerfile
FROM alpine:3.19
ENV KUBECTL_VERSION=1.28.0
```

The algorithm:
1. Extract version from `ENV KUBECTL_VERSION=x.y.z`
2. Use `x.y` as the series prefix
3. Find highest existing `x.y.*` tag
4. Increment patch: `1.28.0` → `1.28.1` → `1.28.2`, etc

When you update `KUBECTL_VERSION=1.29.0`, versioning automatically switches to the `1.29.*` series.

### Docker Registry Logins

Configure logins to container registries (Docker Hub, ECR, GCR, ACR, Quay, etc.) when your builds need to pull from or push to private registries.

#### GHCR Behavior

- **If `ghcr.io` is NOT in config**: Auto-login with GITHUB_TOKEN (same-org access works automatically)
- **If `ghcr.io` IS in config**: Use only the supplied credentials (required for cross-org access with a PAT)

You only need to configure `ghcr.io` explicitly when accessing packages from other organizations.

#### Option A: secrets: inherit (Recommended)

Use [`examples/docker-registry-logins-inherit.yaml`](examples/docker-registry-logins-inherit.yaml)

Simple and secure - all repository secrets are available to the reusable workflow. The workflow looks up secret values by the names you specify in the config.

**Pros:**
- Minimal boilerplate
- No risk of JSON syntax errors
- Easy to add new registries

**Cons:**
- All secrets are technically accessible (though only named ones are used)

#### Option B: Explicit JSON

Use [`examples/docker-registry-logins-explicit.yaml`](examples/docker-registry-logins-explicit.yaml)

Verbose but explicit - you list exactly which secrets are passed to the workflow.

**Pros:**
- Shows exactly what secrets the workflow receives
- Useful for security audits

**Cons:**
- More typing
- JSON syntax errors are easy to make
- Must update secret list when adding registries

#### Supported Login Types

| Type | Use Case |
|------|----------|
| `username-password` | Docker Hub, Quay, private registries |
| `aws-ecr` | AWS ECR with IAM access keys |
| `aws-ecr-github-actions-oidc` | AWS ECR via GitHub Actions OIDC (no long-lived keys) |
| `gcp-gar` | Google Artifact Registry with service account key |
| `gcp-gar-github-actions-oidc` | Google Artifact Registry via GitHub Actions OIDC |
| `azure-acr` | Azure Container Registry with service principal |
| `azure-acr-github-actions-oidc` | Azure ACR via GitHub Actions OIDC |

### Outputs

**Version formats:**

| Output | Example | Use case |
|--------|---------|----------|
| `version` | `1.2.3` | Primary version |
| `version-major` | `1` | Major component |
| `version-minor` | `2` | Minor component |
| `version-patch` | `3` | Patch component |
| `version-2-part` | `1.2` | Two-part format |
| `version-3-part` | `1.2.3` | Semver format |
| `version-4-part` | `1.2.3.0` | Four-part format |

**Build metadata:**

| Output | Example | Description |
|--------|---------|-------------|
| `docker-tag` | `1.2.3` or `1.2.3-PRERELEASE` | Ready-to-use image tag |
| `docker-image-name` | `some/some-repo` | Image name from repo prefix |
| `is-release` | `true` or `false` | Whether this is a release branch build |
| `project-name` | `some-repo` | Contains repo name, to be used for all artifact names |

## Quality Checks

### Always On (cannot be disabled)

| Check | Blocks | Why |
|-------|--------|-----|
| GitHub default branch names | `user-patch-1` patterns | Forces descriptive branch names |
| GitHub UI commit messages | `Update filename`, `Create filename`, `Delete filename` | Forces descriptive commit messages |
| Merge commits | Any commit with 2+ parents | Enforces rebase workflow |
| Branch up to date | Branch that are out of date and need to be rebased | Must be fast-forward to guarantee correct test results |
| Invalid PR target | PRs targeting non-allowed branches | Enforces release branch discipline |

### Default On (can be disabled)

| Check | Input | Default | Blocks |
|-------|-------|---------|--------|
| Double hyphens | `block-double-hyphens` | `true` | `--` in branch names (typo detection) |

### Default Off (opt-in)

| Check | Input | Default | Requires/Blocks |
|-------|-------|---------|-----------------|
| Slashes | `block-slashes` | `false` | Blocks `/` in branch names |
| Conventional branches | `require-conventional-branches` | `false` | Requires `feature/`, `feat/`, `bugfix/`, `fix/`, `hotfix/`, `release/`, `chore/` prefix |
| Conventional commits | `require-conventional-commits` | `false` | Requires `build:`, `chore:`, `ci:`, `docs:`, `feat:`, `fix:`, `perf:`, `refactor:`, `revert:`, `style:`, `test:` prefix |
| Block conventional | `block-conventional-commits` | `false` | Blocks conventional commit format |

## Development

```bash
src/bin/assemble-workflows.bash  # Regenerate workflows and docs only - no tests
.github/bin/run-tests.bash       # Run shellcheck, executable checks, BATS tests, etc AND regenerate as above
```

The assemble script:
1. Lints workflow templates for input consistency
2. Generates `.github/workflows/*.yaml` from `src/workflow-templates/`
3. Generates `docs/*.md` for each workflow
4. Updates README tables between markers

Run after modifying templates. Commit the generated workflows, generated docs/ and updated README.md along with the associated source files you changed.

## Project Licensing

This project uses multiple licenses:

| Component | License | Terms |
|-----------|---------|-------|
| Source code and scripts | MIT | Free to use, modify, distribute with attribution |
| Examples (`examples/`) | CC0-1.0 | Public domain, use freely without attribution |
| Documentation (`*.md`) | CC-BY-SA-4.0 | Attribute to Kaptain contributors, share modifications under same license |

Forks must preserve license headers and attribution. See [LICENSE.txt](LICENSE.txt) for full details.

## SPDX License Header

```
SPDX-License-Identifier: MIT
Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
```
