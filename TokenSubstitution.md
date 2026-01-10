# Token Substitution System

File-based token substitution for Kubernetes manifests and other template files.

## Overview

Tokens are represented as files:
- **Filename** = token name (e.g., `ProjectName`)
- **Content** = token value (e.g., `my-app`)

The system substitutes `${ProjectName}` (or other syntax) with `my-app` across all manifest files.

## Directory Structure

```
src/
  config/                    # User-defined tokens (configurable via config-sub-path)
    MyVar                    # Simple token
    MyCategory/
      MySubVar               # Nested token -> ${MyCategory/MySubVar}
  kubernetes/                # Manifest files with token placeholders

target/manifests/            # Build output
  config/                    # Token files (built-in + user)
  substituted/<project>/     # After substitution
  zip/                       # Final artifact
```

## Configuration

| Input | Default | Description |
|-------|---------|-------------|
| `token-delimiter-style` | `shell` | Delimiter syntax for tokens |
| `token-name-style` | `PascalCase` | Naming convention for tokens |
| `token-name-validation` | `MATCH` | `MATCH` = must match style, `ALL` = any valid name |
| `allow-builtin-token-override` | `false` | Allow user tokens to override built-ins |
| `config-sub-path` | `src/config` | Directory for user-defined tokens (relative) |
| `config-value-trailing-newline` | `strip-for-single-line` | How to handle trailing newlines |

## Substitution Token Styles

| Style | Syntax | Example |
|-------|--------|---------|
| `shell` | `${}` | `${MyVar}` |
| `mustache` | `{{ }}` | `{{ MyVar }}` |
| `helm` | `{{ .Values. }}` | `{{ .Values.MyVar }}` |
| `erb` | `<%= %>` | `<%= MyVar %>` |
| `github-actions` | `${{ }}` | `${{ MyVar }}` |
| `blade` | `{{ $ }}` | `{{ $MyVar }}` |
| `stringtemplate` | `$$` | `$MyVar$` |
| `ognl` | `%{}` | `%{MyVar}` |
| `t4` | `<#= #>` | `<#= MyVar #>` |
| `swift` | `\()` | `\(MyVar)` |

## Token Name Styles

| Style | Valid Examples | Invalid Examples |
|-------|----------------|------------------|
| `UPPER_SNAKE` | `MY_VAR`, `MY_2_VAR`, `2_MY_VAR` | `my_var`, `my-var` |
| `lower_snake` | `my_var`, `my_2_var`, `2_my_var` | `MY_VAR`, `my-var` |
| `lower-kebab` | `my-var`, `my-2-var`, `2-my-var` | `MY_VAR`, `my_var` |
| `UPPER-KEBAB` | `MY-VAR`, `MY-2-VAR`, `2-MY-VAR` | `my-var`, `my_var` |
| `camelCase` | `myVar`, `my2Var`, `2MyVar` | `MyVar`, `my_var` |
| `PascalCase` | `MyVar`, `My2Var`, `2MyVar` | `myVar`, `MY_VAR` |
| `lower.dot` | `my.var`, `my.2.var`, `2.my.var` | `MY.VAR`, `my_var` |
| `UPPER.DOT` | `MY.VAR`, `MY.2.VAR`, `2.MY.VAR` | `my.var`, `MY_VAR` |
| `ALL` | Any of the above | Hidden files, special chars |

**Notes:**
- Leading digits allowed (e.g., `2-my-var`)
- Nested paths use `/` (e.g., `MyCategory/MySubVar`)
- Hidden files always blocked (`.gitkeep`, `.DS_Store`)
- `camelCase` with leading digit requires uppercase after (e.g., `2MyVar` not `2myVar`)

## Built-in Tokens

Always available:

| Token | Source |
|-------|--------|
| `PROJECT_NAME` | Input (required) |
| `VERSION` | Input (required) |
| `IS_RELEASE` | From versions step |
| `MANIFESTS_ZIP_NAME` | Computed: `${PROJECT_NAME}-${VERSION}-manifests.zip` |

Optional (when provided):

| Token | Source |
|-------|--------|
| `DOCKER_TAG` | Input |
| `DOCKER_IMAGE_NAME` | Input |
| `DOCKER_IMAGE_FULL_URI` | Input (docker workflows) |
| `TARGET_REGISTRY` | Input |
| `TARGET_BASE_PATH` | Input |

Built-in token names are converted to match `token-name-style` (e.g., `PROJECT_NAME` becomes `ProjectName` with PascalCase).

## User Tokens

Place files in `src/config/` (or configured `config-sub-path`):

```
src/config/
  DatabaseUrl           # ${DatabaseUrl} -> file content
  AppConfig/
    LogLevel            # ${AppConfig/LogLevel} -> file content
```

## Trailing Newline Handling

| Mode | Single-line | Multi-line |
|------|-------------|------------|
| `strip-for-single-line` (default) | Strip trailing `\n` | Preserve all |
| `preserve-all` | Preserve all | Preserve all |
| `always-strip-one-newline` | Strip one `\n` | Strip one `\n` |

**Why strip by default?** Values are typically inserted mid-string (e.g., `prefix-${var}-suffix`). A trailing newline would break YAML formatting.
**And the real reason?** People are forgetful and careless by their very nature - even the best of us - and they forget to use -n with echo or just use an editor.

## Token Chaining

Tokens can reference other tokens. Primary use case: across build stages.

```
# App build: ${app-database-url} stays unsubstituted

# Product build: provides mapping
src/config/app-database-url  ->  ${shared-database-url}

# Env build: provides final value
src/config/shared-database-url  ->  postgres://prod:5432
```

**Self-referential tokens allowed:** A token can contain a reference to itself for pass-through to downstream builds.

## Conflict Detection

When `allow-builtin-token-override: false` (default), user tokens cannot shadow built-ins:

```
src/config/ProjectName   # CONFLICT with built-in!
src/config/MyCustomVar   # OK
```

Set `allow-builtin-token-override: true` for template projects that need to defer built-in values to downstream builds.

## Validation Rules

Tokens directory is validated for:
- No symlinks (security: prevents path traversal)
- No binary files (must be text)
- Names match configured style

All violations listed before failing.
