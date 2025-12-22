# Workflow Dev Guide

## Workflow Generation

Reusable workflows in `.github/workflows/` are generated from templates. Do not edit them directly.

### Structure

```
src/
  workflow-templates/          # Source templates with INJECT markers
  steps-common/                # Shared step chunks (0-based indentation)
  bin/assemble-workflows.bash  # Generator script
.github/workflows/             # Generated output (do not edit directly)
```

### Adding or Modifying Workflows

1. Use a ticket to discuss a new idea before raising a PR - no point doing the work if we don't want the idea
2. Add or edit templates in `src/workflow-templates/` - if adding use the others as a guide on how to structure your new one
3. Use `# INJECT: <chunk-name>` (without suffix)) to insert shared common steps
4. Add or edit chunks in `src/steps-common/<chunk-name>.yaml` as needed
5. Run the generator:
   ```bash
   ./src/bin/assemble-workflows.bash
   ```
6. Review the diff of the .github/workflows folder and ensure the changes look right, files are added as you expect, etc
7. Commit workflow templates, common steps, and generated workflows together with an appropriate meaningful commit comment
8. Push to a meaningful useful branchname and raise a PR

### Writing Common Steps

Chunks use zero-based indentation. The generator applies the correct indent based on the marker's position in the template.

```yaml
# src/steps-common/example.yaml
- name: Example step
  run: echo "hello"

- name: Another step
  run: echo "world"
```

### Placeholders

Chunks support `${WORKFLOW_NAME}` which resolves to the template filename without extension.
