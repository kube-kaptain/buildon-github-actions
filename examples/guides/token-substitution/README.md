# Token Substitution

> See [Guide Usage](../README.md) for how to use these guides.

Configure how token substitution works in your build. Files in the config
directory become tokens - the file name is the token name, the file content
is the value.

## Delimiter styles

- **shell** - `${Token}` syntax
- **mustache** - `{{Token}}` syntax

## Name styles

- **PascalCase** - `MyToken`
- **UPPER_SNAKE** - `MY_TOKEN`
- **camelCase** - `myToken`
- **kebab-case** - `my-token`

## Built-in tokens

Tokens like `Version` and `DockerTag` are always available. Set
`allowBuiltinOverride: false` to prevent custom tokens from shadowing them.

## Custom tokens

Create a file in your `configSubPath` directory (default `src/config`). The
file name becomes the token name and the file content becomes the value. The
`configValueTrailingNewline` option controls whitespace - use
`strip-for-single-line` to trim trailing newlines from single-line values.
