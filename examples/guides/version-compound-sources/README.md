# Version from Compound Sources

> See [Guide Usage](../README.md) for how to use these guides.

Build a version string from two different files. Takes N parts from the first
source as a prefix, then appends the value from the second source.

## How it works

Set `strategy: compound-file-pattern-match` and define both `sourceOne` and
`sourceTwo`. The `prefixParts` field on sourceOne controls how many
dot-separated segments to take from the first match.

## Example

Given a Dockerfile with `ENV KUBECTL_VERSION=1.29.4` and a file
`PATCH_VERSION` containing `3`:

- sourceOne extracts `1.29.4`, prefixParts 2 takes `1.29`
- sourceTwo extracts `3`
- Final version: `1.29.3`

## When to use this

This pattern is useful when you track an upstream version but maintain your
own patch level. The upstream major.minor comes from one file, and your
independent patch number comes from another.
