# Version from Custom Pattern

> See [Guide Usage](../README.md) for how to use these guides.

Extract a version string from any file using a regular expression with a
capture group. The first capture group becomes the version.

## How it works

Set `strategy: file-pattern-match` and `patternType: custom`, then define
`sourceOne` with the file location and regex pattern.

## Example patterns

| File | Pattern |
|------|---------|
| version.txt | `^([0-9]+\.[0-9]+\.[0-9]+)$` |
| package.json | `"version":\s*"([^"]+)"` |
| Makefile | `^VERSION\s*=\s*(.+)$` |
| build.gradle | `version\s*=\s*'([^']+)'` |

## Notes

- The regex must contain exactly one capture group.
- `subPath` is relative to the repository root.
- The matched value is used as-is for the version - no further transformation.
