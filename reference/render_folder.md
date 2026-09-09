# Render an arbitrary folder as a standalone Quarto site

Renders any folder — anywhere inside a larger git project — as a small
standalone Quarto site in an isolated temp directory, leaving only a
\`\_site/\` artifact inside that folder. The generated site is marked
with a small OFCE quick-publish banner for context. The slug (unique
identifier) is computed from the folder's relative path within its repo
and persisted in \`\_site/.adhoc-meta.json\`.

## Usage

``` r
render_folder(
  path = ".",
  index = NULL,
  slug = NULL,
  progress = TRUE,
  preview = TRUE,
  as_job = TRUE
)
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Folder to render (relative or absolute). Defaults to \`"."\`.

- index:

  \`\[character(1)\]\`  
  Filename (relative to \`path\`) of the file to treat as the home page
  (e.g., \`"slides.qmd"\`, \`"notes.md"\`). Must be a single \`.qmd\` or
  \`.md\` file. If \`NULL\` (default), auto-detects when exactly one
  \`.qmd\` exists directly in \`path\`; otherwise errors with a list of
  candidates.

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

- as_job:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), and RStudio is available (checked via
  \`rstudioapi::isAvailable()\`), runs the render pipeline as a
  background job in RStudio's Background Jobs pane. All output
  (including errors) streams live to the Jobs pane console; when done, a
  summary appears in the global environment as \`adhoc_last_render\` (a
  list with \`ok\`, \`url\`, and optionally \`error\`). If \`FALSE\` or
  RStudio is unavailable, runs synchronously in the current session. See
  Details for integration patterns.

## Value

Invisibly returns \`NULL\` when synchronous (\`as_job = FALSE\`) or
RStudio unavailable. When \`as_job = TRUE\` with RStudio available,
returns immediately and populates \`adhoc_last_render\` in the global
environment when the job finishes.

## Details

\## Render pipeline

1\. Resolves the enclosing git repository root from \`path\`. 2.
Computes a deterministic \`slug\` (if not overridden). 3. Creates a
scratch temp directory and copies \`path\`'s contents into it (excluding
\`\_site/\`, \`.quarto/\`, \`\_freeze/\`, \`.git\*\`). 4. Collects any
\`\_extensions/\` directories from \`path\` or its ancestors (up to the
repo root) and includes them in the temp copy so extension shortcodes
resolve correctly. 5. If the temp copy has no \`\_quarto.yml\`, writes a
minimal default one. 6. Renders the folder via
\`quarto::quarto_render()\` in the temp directory. 7. Locates the HTML
output for \`index\` and copies it to \`\_site/index.html\` (preserving
the original filename too). 8. Post-processes all \`\*.html\` files to
inject a small OFCE quick-publish banner right after the opening
\`\<body...\>\` tag. 9. Cleans \`.DS_Store\` files, then copies the temp
\`\_site/\` into \`\<path\>/\_site/\` (replacing if present). Writes
metadata (slug, index, timestamp) to \`\_site/.adhoc-meta.json\`. 10. If
\`preview = TRUE\` and \`as_job = FALSE\`, launches
\[preview_folder()\].

\## Self-contained folders

The folder must be reasonably self-contained. Relative paths that climb
outside it (e.g., \`../shared-bib.bib\`, \`../../www/logo.png\`) won't
resolve in the temp copy, since only the folder itself (plus discovered
\`\_extensions/\`) is copied over. If \`quarto_render()\` fails on a
missing file, check whether any includes are pointing outside the
folder.

\## \`.gitignore\` housekeeping

We recommend adding \`\_site/\` to the folder's \`.gitignore\` if not
already present, so it isn't accidentally committed: “\` echo "\_site/"
\>\> \<path\>/.gitignore “\`

## See also

\[deploy_folder()\], \[publish_folder()\], \[preview_folder()\],
\[render_prev()\]
