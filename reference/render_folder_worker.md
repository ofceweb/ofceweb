# Worker function for render_folder (internal synchronous implementation)

This function contains the actual render logic, separated so it can be
called either directly (synchronous) or from a background job script.

## Usage

``` r
render_folder_worker(path, index, slug, progress, preview)
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Folder to render (relative or absolute). Defaults to \`"."\`.

- index:

  \`\[character(1)\]\`  
  Filename (relative to \`path\`) of the file to treat as the home page
  (e.g., \`"slides.qmd"\`, \`"notes.md"\`). Must be a \`.qmd\` or
  \`.md\` file directly in \`path\`. If \`NULL\` (default), resolved via
  \[adhoc_resolve_index()\]: \`index.qmd\`/\`index.md\` if present,
  otherwise the most recently modified \`.qmd\`/\`.md\` candidate (an
  informational message names the file picked when more than one
  candidate exists). Only this single document is rendered — see
  Details.

- slug:

  \`\[character(1)\]\`  
  Override the auto-computed slug (unique identifier). If \`NULL\`
  (default), computed from the folder's relative path using
  \[adhoc_slug()\]. Persisted in \`\_site/.adhoc-meta.json\` for
  \[deploy_folder()\].

- progress:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), progress is reported to the console.

- preview:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), launches a live preview server via
  \[servr::httw()\] on the rendered site \*\*when \`as_job = FALSE\`\*\*
  only (ignored when \`as_job = TRUE\` — use \[preview_folder()\]
  afterwards instead).

## Value

Invisibly returns the resulting URL (character string).
