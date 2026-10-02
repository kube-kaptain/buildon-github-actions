# Run Environment Job Mode

> See [Guide Usage](../README.md) for how to use these guides.

Deploys by running a job on each image update rather than keeping a
reconciler running.

* `deployMode: job` generates a suspended CronJob that keelson triggers when
  the deploy image changes, plus a zero-scale Deployment of the same image an
  operator can scale to 1 to debug.
* Job mode needs `imageAutoUpdateProvider: keelson` (or `none` for manual
  runs); keel cannot trigger jobs.
* After a deploy the pod stays up so `/kd/work/` can be inspected, then
  exits: `jobPostDeploySleepAfterSuccess` (default `10m`) and
  `jobPostDeploySleepAfterFailure` (default `24h`). `0` exits straight away.
