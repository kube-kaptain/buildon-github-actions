# Release Branches

> See [Guide Usage](../README.md) for how to use these guides.

By default, only merges to `main` trigger a version tag and release.
Use `additionalBranches` to enable releases from maintenance branches
like `main-1.x` or `main-2.x`.

Each release branch gets its own independent version sequence.
Merges to any listed branch push a version tag following that
branch's version line.

If the tagging strategy is file based the tagging will be automatically
correct based on the, presumably different, file contents in your branch.
However if tagging strategy is git auto then you need to push a seed tag
along with your branch to steer the tagging away from the prior tags eg
by adding a patch version to a 2-part version or bumping or something.

## Configuration

- `release.branch` - the primary release branch (default: `main`)
- `release.additionalBranches` - comma-separated list of extra branches

## Notes

- Branch names must exist in the repository before they can produce releases.
- Version tags are scoped per branch, so `main` and `main-1.x` do not
  interfere with each other provided they are in a different series.
- If the series is the same the versions and release artifacts will come from
  whichever branch last released - if both are in use you'll get a yoyoing effect
  and associated unpredictable outcomes if the branch content differs meaningfully
