# Resolve which document \`render_folder()\` should render

Determines the single \`.qmd\`/\`.md\` file to treat as the site's index
page, in order of priority:

1.  \`index\`, if supplied explicitly (e.g. by \[render_folder_addin()\]
    via the active editor document) — must exist in \`target\`.

2.  \`index.qmd\` or \`index.md\`, if present directly in \`target\`.

3.  Otherwise, the most recently modified \`.qmd\`/\`.md\` file directly
    in \`target\` (files starting with \`\_\` are ignored). If more than
    one candidate exists, an informational message names the one picked
    and points to the \`index\` argument for overriding it.

Aborts if \`target\` has no eligible \`.qmd\`/\`.md\` file at all.

## Usage

``` r
adhoc_resolve_index(target, index = NULL, progress = TRUE)
```

## Arguments

- target:

  \`\[character(1)\]\`  
  Absolute path to the folder being rendered.

- index:

  \`\[character(1)\]\`  
  Explicit filename (relative to \`target\`), or \`NULL\` to
  auto-resolve.

- progress:

  \`\[logical(1)\]\`  
  Whether to report the auto-pick via \[cli::cli_alert_info()\].

## Value

\`\[character(1)\]\` The resolved filename (relative to \`target\`).
