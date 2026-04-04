# Version with Prefix Parts

> See [Guide Usage](../README.md) for how to use these guides.

Use `prefixParts` to derive your version from an upstream version. The build
system takes the first N dot-separated parts and auto-increments the next one.

## How it works

Set `prefixParts` on `sourceOne` to control how many segments to keep from the
extracted version. The build system uses those segments as a fixed prefix, then
auto-increments the next part based on existing tags.

## Example

With source tag `7.2.4` and `prefixParts: 2`:

- Extracted version: `7.2.4`
- Prefix taken: `7.2`
- Auto-incremented releases: `7.2.1`, `7.2.2`, `7.2.3`, ...

## When to use this

This is useful for retag workflows where you track an upstream image's
major.minor but own the patch number. When upstream bumps to `7.3.0`, update
the source tag and your releases start at `7.3.1`.
