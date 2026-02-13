# kubernetes-app-docker-retag

Kubernetes App - Docker Retag

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `output-sub-path` | string | `target` | Build output directory (relative) |
| `docker-registry-logins` | string | `""` | YAML config for Docker registry logins (registry URL as key) |
| `docker-target-registry` | string | `""` | Target container registry domain (defaults to ghcr.io on gh actions) |
| `docker-target-base-path` | string | `""` | Path between registry and image name (defaults to lower cased org name on gh actions) |
| `docker-push-targets` | string | `""` | JSON array of additional push targets [{registry, base-path?}] |
| `docker-source-registry` | string | *required* | Upstream registry (e.g., docker.io) |
| `docker-source-base-path` | string | `""` | Path between registry and image name (e.g., library) |
| `docker-source-image-name` | string | *required* | Upstream image name (e.g., nginx) |
| `docker-source-tag` | string | *required* | Upstream image tag (e.g., 1.25) |
| `manifests-sub-path` | string | `src/kubernetes` | Directory containing Kubernetes manifests (relative) |
| `manifests-repo-provider-type` | string | `docker` | Repo provider type for manifest storage (default: docker, currently the only supported provider) |
| `manifests-packaging-base-image` | string | `""` | Base image for manifest packaging (default: scratch) |
| `kubernetes-global-additional-labels` | string | `""` | Additional labels for all Kubernetes manifests (comma-separated key=value) |
| `kubernetes-global-additional-annotations` | string | `""` | Additional annotations for all Kubernetes manifests (comma-separated key=value) |
| `kubernetes-configmap-sub-path` | string | `src/configmap` | Directory containing ConfigMap data files (relative) |
| `kubernetes-configmap-name-checksum-injection` | boolean | `true` | Enable checksum injection suffix in ConfigMap name |
| `kubernetes-configmap-additional-labels` | string | `""` | Additional labels specific to ConfigMap (comma-separated key=value) |
| `kubernetes-configmap-additional-annotations` | string | `""` | Additional annotations specific to ConfigMap (comma-separated key=value) |
| `kubernetes-secret-template-sub-path` | string | `src/secret.template` | Directory containing Secret template data files (relative) |
| `kubernetes-secret-template-name-checksum-injection` | boolean | `true` | Enable checksum injection suffix in Secret name |
| `kubernetes-secret-template-additional-labels` | string | `""` | Additional labels specific to Secret template (comma-separated key=value) |
| `kubernetes-secret-template-additional-annotations` | string | `""` | Additional annotations specific to Secret template (comma-separated key=value) |
| `kubernetes-serviceaccount-generation-enabled` | boolean | `false` | Enable ServiceAccount generation |
| `kubernetes-serviceaccount-name-suffix` | string | `""` | Optional suffix for ServiceAccount name and filename |
| `kubernetes-serviceaccount-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-serviceaccount-additional-labels` | string | `""` | Additional labels specific to ServiceAccount (comma-separated key=value) |
| `kubernetes-serviceaccount-additional-annotations` | string | `""` | Additional annotations specific to ServiceAccount (comma-separated key=value) |
| `kubernetes-workload-type` | string | `deployment` | Workload type to generate (deployment, statefulset, daemonset, none) |
| `kubernetes-workload-replicas` | string | `""` | Replica count (empty for token, NO for HPA management, number for fixed) |
| `kubernetes-workload-revision-history-limit` | string | `10` | Number of revisions to retain (ReplicaSets for Deployment, ControllerRevisions for StatefulSet) |
| `kubernetes-workload-min-ready-seconds` | string | `0` | Minimum seconds a pod must be ready before considered available (0 to disable) |
| `kubernetes-workload-name-suffix` | string | `""` | Optional suffix for workload name and filename |
| `kubernetes-workload-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-workload-env-sub-path` | string | `""` | Directory containing environment variable files (default per workload type) |
| `kubernetes-workload-additional-labels` | string | `""` | Additional labels specific to workload (comma-separated key=value) |
| `kubernetes-workload-additional-annotations` | string | `""` | Additional annotations specific to workload (comma-separated key=value) |
| `kubernetes-workload-container-port` | string | `1024` | Container port |
| `kubernetes-workload-container-command` | string | `""` | Container command override (space-separated, respects quotes like shell) |
| `kubernetes-workload-container-args` | string | `""` | Container args override (space-separated, respects quotes like shell) |
| `kubernetes-workload-image-reference-style` | string | `combined` | Image reference style (combined, separate, project-name-prefixed-combined, project-name-prefixed-separate) |
| `kubernetes-workload-readonly-root-filesystem` | boolean | `true` | Enable read-only root filesystem |
| `kubernetes-workload-seccomp-profile` | string | `DISABLED` | Seccomp profile (DISABLED, RuntimeDefault, Localhost, Unconfined) |
| `kubernetes-workload-automount-service-account-token` | boolean | `false` | Automount service account token |
| `kubernetes-workload-image-pull-secrets` | string | `ENABLED` | Include imagePullSecrets in pod spec (ENABLED/DISABLED) |
| `kubernetes-workload-resources-memory` | string | `10Mi` | Memory limit (e.g., 128Mi, 1Gi) |
| `kubernetes-workload-resources-cpu-request` | string | `100m` | CPU request (e.g., 100m, 1) |
| `kubernetes-workload-resources-cpu-limit` | string | `""` | CPU limit (empty for no limit) |
| `kubernetes-workload-resources-ephemeral-storage` | string | `10Mi` | Ephemeral storage request/limit (e.g., 10Mi, 100Mi, 1Gi) |
| `kubernetes-workload-configmap-mount-path` | string | `/configmap` | ConfigMap mount path in container |
| `kubernetes-workload-secret-mount-path` | string | `/secret` | Secret mount path in container |
| `kubernetes-workload-configmap-keys-for-env` | string | `""` | Comma/space-separated ConfigMap keys to expose as env vars |
| `kubernetes-workload-secret-keys-for-env` | string | `""` | Comma/space-separated Secret keys to expose as env vars |
| `kubernetes-workload-termination-grace-period-seconds` | string | `10` | Termination grace period in seconds |
| `kubernetes-workload-prestop-command` | string | `""` | PreStop hook command (empty for none) |
| `kubernetes-workload-affinity-strategy` | string | `spread-nodes-and-zones-ha` | Pod affinity strategy plugin name |
| `kubernetes-workload-tolerations` | string | `""` | Tolerations as JSON array (e.g., [{"key":"dedicated","operator":"Equal","value":"app","effect":"NoSchedule"}]) |
| `kubernetes-workload-node-selector` | string | `""` | Node selector (comma-separated key=value pairs, e.g., disktype=ssd,zone=us-east-1a) |
| `kubernetes-workload-dns-policy` | string | `""` | DNS policy (ClusterFirst, ClusterFirstWithHostNet, Default, None) |
| `kubernetes-workload-priority-class-name` | string | `""` | Priority class name for pod scheduling priority |
| `kubernetes-workload-probe-liveness-check-type` | string | `http-get` | Liveness probe type (http-get, tcp-socket, exec, grpc, none) |
| `kubernetes-workload-probe-liveness-http-path` | string | `/liveness` | Liveness probe HTTP path |
| `kubernetes-workload-probe-liveness-http-scheme` | string | `HTTP` | Liveness probe HTTP scheme (HTTP, HTTPS) |
| `kubernetes-workload-probe-liveness-tcp-port` | string | `""` | Liveness probe TCP port (defaults to container port) |
| `kubernetes-workload-probe-liveness-exec-command` | string | `""` | Liveness probe exec command |
| `kubernetes-workload-probe-liveness-grpc-port` | string | `""` | Liveness probe gRPC port (defaults to container port) |
| `kubernetes-workload-probe-liveness-grpc-service` | string | `""` | Liveness probe gRPC service name |
| `kubernetes-workload-probe-liveness-initial-delay-seconds` | string | `10` | Liveness probe initial delay in seconds |
| `kubernetes-workload-probe-liveness-period-seconds` | string | `10` | Liveness probe period in seconds |
| `kubernetes-workload-probe-liveness-timeout-seconds` | string | `5` | Liveness probe timeout in seconds |
| `kubernetes-workload-probe-liveness-failure-threshold` | string | `3` | Liveness probe failure threshold |
| `kubernetes-workload-probe-liveness-termination-grace-period-seconds` | string | `""` | Liveness probe termination grace period (empty for default) |
| `kubernetes-workload-probe-readiness-check-type` | string | `http-get` | Readiness probe type (http-get, tcp-socket, exec, grpc, none) |
| `kubernetes-workload-probe-readiness-http-path` | string | `/readiness` | Readiness probe HTTP path |
| `kubernetes-workload-probe-readiness-http-scheme` | string | `HTTP` | Readiness probe HTTP scheme (HTTP, HTTPS) |
| `kubernetes-workload-probe-readiness-tcp-port` | string | `""` | Readiness probe TCP port (defaults to container port) |
| `kubernetes-workload-probe-readiness-exec-command` | string | `""` | Readiness probe exec command |
| `kubernetes-workload-probe-readiness-grpc-port` | string | `""` | Readiness probe gRPC port (defaults to container port) |
| `kubernetes-workload-probe-readiness-grpc-service` | string | `""` | Readiness probe gRPC service name |
| `kubernetes-workload-probe-readiness-initial-delay-seconds` | string | `5` | Readiness probe initial delay in seconds |
| `kubernetes-workload-probe-readiness-period-seconds` | string | `5` | Readiness probe period in seconds |
| `kubernetes-workload-probe-readiness-timeout-seconds` | string | `3` | Readiness probe timeout in seconds |
| `kubernetes-workload-probe-readiness-failure-threshold` | string | `3` | Readiness probe failure threshold |
| `kubernetes-workload-probe-readiness-success-threshold` | string | `1` | Readiness probe success threshold |
| `kubernetes-workload-probe-startup-check-type` | string | `http-get` | Startup probe type (http-get, tcp-socket, exec, grpc, none) |
| `kubernetes-workload-probe-startup-http-path` | string | `/startup` | Startup probe HTTP path |
| `kubernetes-workload-probe-startup-http-scheme` | string | `HTTP` | Startup probe HTTP scheme (HTTP, HTTPS) |
| `kubernetes-workload-probe-startup-tcp-port` | string | `""` | Startup probe TCP port (defaults to container port) |
| `kubernetes-workload-probe-startup-exec-command` | string | `""` | Startup probe exec command |
| `kubernetes-workload-probe-startup-grpc-port` | string | `""` | Startup probe gRPC port (defaults to container port) |
| `kubernetes-workload-probe-startup-grpc-service` | string | `""` | Startup probe gRPC service name |
| `kubernetes-workload-probe-startup-initial-delay-seconds` | string | `0` | Startup probe initial delay in seconds |
| `kubernetes-workload-probe-startup-period-seconds` | string | `5` | Startup probe period in seconds |
| `kubernetes-workload-probe-startup-timeout-seconds` | string | `3` | Startup probe timeout in seconds |
| `kubernetes-workload-probe-startup-failure-threshold` | string | `30` | Startup probe failure threshold |
| `kubernetes-workload-probe-startup-termination-grace-period-seconds` | string | `""` | Startup probe termination grace period (empty for default) |
| `kubernetes-deployment-env-sub-path` | string | `src/deployment-env` | Path to deployment environment variables directory |
| `kubernetes-deployment-additional-labels` | string | `""` | Additional labels for Deployment resources (key=value,key=value) |
| `kubernetes-deployment-additional-annotations` | string | `""` | Additional annotations for Deployment resources (key=value,key=value) |
| `kubernetes-deployment-max-surge` | string | `1` | Max surge during rolling update (integer or percentage, e.g., 1 or 25%) |
| `kubernetes-deployment-max-unavailable` | string | `0` | Max unavailable during rolling update (integer or percentage, e.g., 0 or 25%) |
| `kubernetes-statefulset-env-sub-path` | string | `src/statefulset-env` | Path to statefulset environment variables directory |
| `kubernetes-statefulset-additional-labels` | string | `""` | Additional labels for StatefulSet resources (key=value,key=value) |
| `kubernetes-statefulset-additional-annotations` | string | `""` | Additional annotations for StatefulSet resources (key=value,key=value) |
| `kubernetes-statefulset-service-name` | string | `""` | Headless service name (empty for auto-derived from project name) |
| `kubernetes-statefulset-pod-management-policy` | string | `OrderedReady` | Pod management policy (OrderedReady or Parallel) |
| `kubernetes-statefulset-allow-unreliable-pod-management-policy` | string | `""` | Required acknowledgment to use Parallel pod management (must be I_LIKE_DOWNTIME) |
| `kubernetes-statefulset-update-strategy-type` | string | `RollingUpdate` | Update strategy type (RollingUpdate or OnDelete) |
| `kubernetes-statefulset-update-strategy-partition` | string | `""` | Partition for rolling updates (empty for none) |
| `kubernetes-statefulset-pvc-enabled` | string | `true` | Enable persistent volume claim template (true/false) |
| `kubernetes-statefulset-pvc-storage-class` | string | `""` | Storage class for PVC (empty for cluster default) |
| `kubernetes-statefulset-pvc-storage-size` | string | `1Gi` | Storage size for PVC (e.g., 1Gi, 10Gi) |
| `kubernetes-statefulset-pvc-access-mode` | string | `ReadWriteOnce` | PVC access mode (ReadWriteOnce, ReadOnlyMany, ReadWriteMany) |
| `kubernetes-statefulset-pvc-volume-name` | string | `data` | Volume name for the PVC template |
| `kubernetes-statefulset-pvc-mount-path` | string | `/data` | Mount path for the persistent volume |
| `kubernetes-daemonset-update-strategy-type` | string | `RollingUpdate` | Update strategy type (RollingUpdate or OnDelete) |
| `kubernetes-daemonset-max-unavailable` | string | `1` | Max unavailable pods during rolling update (number or percentage) |
| `kubernetes-daemonset-host-network` | string | `false` | Use host network namespace (true/false) |
| `kubernetes-daemonset-host-pid` | string | `false` | Use host PID namespace (true/false) |
| `kubernetes-daemonset-host-ipc` | string | `false` | Use host IPC namespace (true/false) |
| `kubernetes-daemonset-run-as-non-root` | boolean | `true` | Require non-root user (true/false, set false for system-level DaemonSets that need root) |
| `kubernetes-daemonset-privileged` | string | `false` | Run container in privileged mode (true/false) |
| `kubernetes-daemonset-dns-policy` | string | `""` | DNS policy (ClusterFirst, ClusterFirstWithHostNet, Default, None) |
| `kubernetes-daemonset-tolerations` | string | `""` | Tolerations as JSON array (e.g., [{"operator":"Exists"}] or [{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]) |
| `kubernetes-daemonset-node-selector` | string | `""` | Node selector labels (comma-separated key=value) |
| `kubernetes-job-name-suffix` | string | `""` | Optional suffix for Job name and filename |
| `kubernetes-job-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-job-backoff-limit` | string | `0` | Number of retries before marking Job as failed (0 = fail immediately) |
| `kubernetes-job-completions` | string | `1` | Number of successful completions needed |
| `kubernetes-job-parallelism` | string | `1` | Number of pods running at any time |
| `kubernetes-job-active-deadline-seconds` | string | `""` | Maximum time in seconds the Job can run (optional) |
| `kubernetes-job-ttl-seconds-after-finished` | string | `86400` | Cleanup time after Job completion in seconds |
| `kubernetes-job-restart-policy` | string | `Never` | Pod restart policy (Never or OnFailure) |
| `kubernetes-job-env-sub-path` | string | `""` | Path to Job environment variables directory |
| `kubernetes-job-additional-labels` | string | `""` | Additional labels for Job resources (key=value,key=value) |
| `kubernetes-job-additional-annotations` | string | `""` | Additional annotations for Job resources (key=value,key=value) |
| `kubernetes-job-liveness-probe-enabled` | string | `false` | Enable liveness probe (uses workload probe settings when true) |
| `kubernetes-job-readiness-probe-enabled` | string | `false` | Enable readiness probe (uses workload probe settings when true) |
| `kubernetes-job-startup-probe-enabled` | string | `false` | Enable startup probe (uses workload probe settings when true) |
| `kubernetes-cronjob-name-suffix` | string | `""` | Optional suffix for CronJob name and filename |
| `kubernetes-cronjob-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-cronjob-concurrency-policy` | string | `Forbid` | How to handle concurrent job runs (Allow, Forbid, Replace) |
| `kubernetes-cronjob-starting-deadline-seconds` | string | `""` | Deadline for starting job if missed scheduled time (optional) |
| `kubernetes-cronjob-successful-jobs-history-limit` | string | `1` | Number of successful jobs to retain for log collection |
| `kubernetes-cronjob-failed-jobs-history-limit` | string | `5` | Number of failed jobs to retain to show failure patterns |
| `kubernetes-cronjob-backoff-limit` | string | `0` | Number of retries before marking job as failed (0 = fail immediately) |
| `kubernetes-cronjob-completions` | string | `1` | Number of successful completions needed |
| `kubernetes-cronjob-parallelism` | string | `1` | Number of pods running at any time |
| `kubernetes-cronjob-active-deadline-seconds` | string | `""` | Maximum time in seconds the job can run (optional) |
| `kubernetes-cronjob-restart-policy` | string | `Never` | Pod restart policy (Never or OnFailure) |
| `kubernetes-cronjob-env-sub-path` | string | `""` | Path to CronJob environment variables directory |
| `kubernetes-cronjob-additional-labels` | string | `""` | Additional labels for CronJob resources (key=value,key=value) |
| `kubernetes-cronjob-additional-annotations` | string | `""` | Additional annotations for CronJob resources (key=value,key=value) |
| `kubernetes-cronjob-liveness-probe-enabled` | string | `false` | Enable liveness probe (uses workload probe settings when true) |
| `kubernetes-cronjob-readiness-probe-enabled` | string | `false` | Enable readiness probe (uses workload probe settings when true) |
| `kubernetes-cronjob-startup-probe-enabled` | string | `false` | Enable startup probe (uses workload probe settings when true) |
| `kubernetes-poddisruptionbudget-generation-enabled` | string | `""` | Enable PodDisruptionBudget generation (true, false, or empty for auto based on workload type) |
| `kubernetes-poddisruptionbudget-name-suffix` | string | `""` | Optional suffix for PDB name and filename |
| `kubernetes-poddisruptionbudget-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-poddisruptionbudget-strategy` | string | `max-unavailable` | PDB constraint strategy (min-available or max-unavailable) |
| `kubernetes-poddisruptionbudget-value` | string | `1` | Value for the chosen strategy (integer or percentage, e.g., 1, 50%) |
| `kubernetes-poddisruptionbudget-additional-labels` | string | `""` | Additional labels specific to PodDisruptionBudget (comma-separated key=value) |
| `kubernetes-poddisruptionbudget-additional-annotations` | string | `""` | Additional annotations specific to PodDisruptionBudget (comma-separated key=value) |
| `kubernetes-service-generation-enabled` | string | `""` | Enable Service generation (true, false, or empty for auto based on workload type) |
| `kubernetes-service-type` | string | `ClusterIP` | Service type (ClusterIP, Headless, NoSelector, NodePort, LoadBalancer, ExternalName) |
| `kubernetes-service-port` | string | `80` | Service port (not used for ExternalName) |
| `kubernetes-service-target-port` | string | `""` | Target port (defaults to container port, not used for ExternalName) |
| `kubernetes-service-protocol` | string | `TCP` | Protocol (TCP, UDP, SCTP) |
| `kubernetes-service-port-name` | string | `""` | Named port identifier (optional) |
| `kubernetes-service-node-port` | string | `""` | Node port number (NodePort type only, empty for auto-assign) |
| `kubernetes-service-external-name` | string | `""` | External DNS name (required for ExternalName type) |
| `kubernetes-service-external-traffic-policy` | string | `""` | External traffic policy (Cluster or Local, NodePort/LoadBalancer only) |
| `kubernetes-service-name-suffix` | string | `""` | Optional suffix for Service name and filename |
| `kubernetes-service-combined-sub-path` | string | `""` | Sub-path within combined/ for output |
| `kubernetes-service-additional-labels` | string | `""` | Additional labels specific to Service (comma-separated key=value) |
| `kubernetes-service-additional-annotations` | string | `""` | Additional annotations specific to Service (comma-separated key=value) |
| `token-delimiter-style` | string | `shell` | Token delimiter syntax for variables (shell, mustache, helm, erb, github-actions, blade, stringtemplate, ognl, t4, swift) |
| `token-name-style` | string | `PascalCase` | Case style for token names (UPPER_SNAKE, lower_snake, lower-kebab, UPPER-KEBAB, camelCase, PascalCase, lower.dot, UPPER.DOT) |
| `token-name-validation` | string | `MATCH` | How to validate user token names (MATCH = must match token-name-style, ALL = accept any valid name) |
| `allow-builtin-token-override` | boolean | `false` | Allow user tokens to override built-in tokens (for template/reusable projects) |
| `config-sub-path` | string | `src/config` | Directory containing user-defined token files (relative) |
| `config-value-trailing-newline` | string | `strip-for-single-line` | How to handle trailing newlines in config values (strip-for-single-line, preserve-all, always-strip-one-newline) |
| `release-branch` | string | `main` | The release branch name |
| `additional-release-branches` | string | `""` | Comma-separated list of additional release branches |
| `tag-version-max-parts` | number | `3` | Maximum allowed version parts (fail if exceeded) |
| `tag-version-calculation-strategy` | string | `git-auto-closest-highest` | Strategy for calculating version (git-auto-closest-highest, file-pattern-match, compound-file-pattern-match) |
| `tag-version-pattern-type` | string | `dockerfile-env-kubectl` | Pattern type for file-pattern-match strategy (dockerfile-env-kubectl, retag-workflow-source-tag, custom) |
| `tag-version-prefix-parts` | string | `""` | Number of parts from source version to use as prefix (default 2, output = prefix + 1 parts). Ignored when tag-version-use-source-version-exact is true. |
| `tag-version-source-sub-path` | string | `""` | Override path to source directory (takes precedence over dockerfile-sub-path) |
| `tag-version-source-file-name` | string | `""` | Override source file name (defaults based on pattern type) |
| `tag-version-source-custom-pattern` | string | `""` | Regex with capture group for version extraction (required for custom pattern type) |
| `tag-version-source-two-sub-path` | string | `""` | Path to source TWO directory (defaults to source ONE path) |
| `tag-version-source-two-file-name` | string | `""` | Source TWO file name (defaults to source ONE file name) |
| `tag-version-source-two-pattern` | string | `""` | Regex with capture group for source TWO (required if same file as source ONE) |
| `tag-version-source-two-prefix-parts` | string | `""` | Number of parts from source TWO version to use in prefix (default 2). Ignored when tag-version-use-source-version-exact is true. |
| `tag-version-use-source-version-exact` | boolean | `false` | Use the exact version found in source file(s) without incrementing (file-based strategies only) |
| `block-slashes` | boolean | `false` | DEPRECATED: Use block-slash-containing-branches instead |
| `qc-block-slash-containing-branches` | boolean | `false` | Block branch names containing slashes |
| `qc-block-double-hyphen-containing-branches` | boolean | `true` | Block branch names containing double hyphens (typo detection) |
| `qc-require-conventional-branches` | boolean | `false` | Require branch names start with feature/, fix/, etc. |
| `qc-require-conventional-commits` | boolean | `false` | Require commits use conventional commit format (feat:, fix:, etc.) |
| `qc-block-conventional-commits` | boolean | `false` | Block commits that use conventional commit format |
| `qc-block-duplicate-commit-messages` | boolean | `true` | Block PRs where two or more commits have identical messages |
| `hook-pre-tagging-tests-script-sub-path` | string | `""` | Path to pre-tagging test script relative to .github/ (e.g., bin/pre-tagging.bash) |
| `hook-pre-package-prepare-script-sub-path` | string | `""` | Path to pre-package prepare script relative to .github/ (e.g., bin/pre-package-prepare.bash) |
| `hook-post-package-tests-script-sub-path` | string | `""` | Path to post-package test script relative to .github/ (e.g., bin/post-package.bash) |
| `github-release-enabled` | boolean | `true` | Create a GitHub release on version tags |
| `github-release-substituted-files` | string | `""` | Files with token substitution and version suffix (space-separated) |
| `github-release-verbatim-files` | string | `""` | Files copied as-is with version suffix only (space-separated) |
| `github-release-notes` | string | `""` | Inline release notes string (mutually exclusive with github-release-notes-file) |
| `github-release-notes-file` | string | `""` | Path to release notes file (mutually exclusive with github-release-notes) |
| `github-release-add-version-to-filenames` | boolean | `true` | Add version suffix to release filenames (e.g., file.yaml -> file-1.2.3.yaml) |

## Secrets

| Secret | Description |
|--------|-------------|
| `docker-registry-logins-secrets` | JSON object of secrets for docker-registry-logins (e.g., {"DOCKER_USER": "x", "DOCKER_PASS": "y"}) |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | The generated version |
| `version-major` | Major version number |
| `version-minor` | Minor version number |
| `version-patch` | Patch version number |
| `version-2-part` | Version padded/truncated to 2 parts |
| `version-3-part` | Version padded/truncated to 3 parts |
| `version-4-part` | Version padded/truncated to 4 parts |
| `docker-tag` | Tag for Docker images |
| `docker-image-name` | Docker image name |
| `git-tag` | Tag for git |
| `project-name` | The repository/project name |
| `is-release` | Whether this is a release build |
| `docker-source-image-full-uri` | Full source image reference |
| `docker-target-image-full-uri` | Full target image reference |
| `docker-image-full-uri` | Full docker image reference (alias for docker-target-image-full-uri) |
| `images-pushed` | Number of images pushed |
| `manifests-zip-sub-path` | Directory containing manifests zip file (relative) |
| `manifests-zip-file-name` | Name of manifests zip file |
| `manifests-uri` | Reference to published manifests (format depends on repo provider) |
| `manifests-published` | Whether manifests were published |
