# GitHub Release Options

> See [Guide Usage](../README.md) for how to use these guides.

Configure GitHub Releases to attach build artifacts, add release notes,
and control filename versioning.

## File types

- **substitutedFiles** - tokens in these files are replaced with actual
  values (e.g. version strings) before attaching to the release.
- **verbatimFiles** - attached to the release exactly as they are in the
  repository, with no token replacement.
- **rawFiles** - attached to the release exactly as they are and also expected
  and required to have version already in the file name before the extension.

Both accept comma-separated paths relative to the repository root.

## Options

- `notes` - custom release notes text. Leave empty (`''`) for
  auto-generated notes based on commits since the last release.
- `addVersionToFilenames` - when `true`, the version is appended to
  each attached filename (e.g. `output-1.2.3.txt`).

## Notes

- The `enabled: false` flag is required to deactivate GitHub Releases.
- Paths configured that do not exist at release time cause a failure.
