# Unsupported Token Formats

These token substitution patterns are not supported due to conflicts with YAML syntax or Kubernetes-native structures.

| Name | Pattern | Example | Problem |
|------|---------|---------|---------|
| Make/Azure Pipelines | `$(var)` | `$(MyApP)` | Kubernetes natively interpolates `$(VAR)` for env var substitution in pod specs |
| React/Svelte | `{var}` | `{MyApP}` | Conflicts with JSON in annotations, ConfigMap data, and strategic merge patches |
| Smarty/PHP | `{$var}` | `{$MyApP}` | Conflicts with JSON structures |
| ColdFusion | `#var#` | `#MyApP#` | YAML treats `#` as comment start — value gets truncated |
| Ruby/Pug/Spring EL | `#{var}` | `#{MyApP}` | YAML treats `#` as comment start — value gets truncated |
