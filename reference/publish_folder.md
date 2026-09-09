# Render and deploy a folder as a standalone Quarto site, in one step

Convenience wrapper chaining \[render_folder()\] and
\[deploy_folder()\]: renders \`path\` as a standalone Quarto site, then
immediately pushes and deploys it to \`staging.ofce.fr\`. This is the
typical entry point for ad-hoc folder publishing. Call
\[render_folder()\] and \[deploy_folder()\] separately instead when you
want to iterate on the render (e.g. via \[preview_folder()\]) before
deploying.

## Usage

``` r
publish_folder(
  path = ".",
  index = NULL,
  slug = NULL,
  encrypt = TRUE,
  progress = TRUE,
  trigger = TRUE,
  full_deploy = FALSE,
  as_job = TRUE
)
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Folder to render and deploy (relative or absolute). Defaults to
  \`"."\`.

- index:

  \`\[character(1)\]\`  
  See \[render_folder()\].

- slug:

  \`\[character(1)\]\`  
  Override the auto-computed slug (unique identifier). If \`NULL\`
  (default), \[render_folder()\] computes it and persists it in
  \`\_site/.adhoc-meta.json\`, from which \[deploy_folder()\] then reads
  it back — so both steps agree on the same slug without it needing to
  be passed explicitly.

- encrypt:

  \`\[logical(1)\]\`  
  See \[deploy_folder()\]. Defaults to \`TRUE\`.

- progress:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default), progress is reported to the console (or the
  Jobs pane console when \`as_job = TRUE\`).

- trigger:

  \`\[logical(1)\]\`  
  See \[deploy_folder()\]. Defaults to \`TRUE\`.

- full_deploy:

  \`\[logical(1)\]\`  
  See \[deploy_folder()\]. Defaults to \`FALSE\`.

- as_job:

  \`\[logical(1)\]\`  
  If \`TRUE\` (default) and RStudio is available (checked via
  \`rstudioapi::isAvailable()\`), runs the full render + deploy pipeline
  as a single background job in RStudio's Background Jobs pane. All
  output (including errors) streams live to the Jobs pane console; when
  done, a summary appears in the global environment as
  \`adhoc_last_publish\` (a list with \`ok\`, \`url\`, and optionally
  \`error\`). If \`FALSE\` or RStudio is unavailable, runs synchronously
  in the current session. The local preview server
  (\[preview_folder()\]) is not launched in either mode — call it
  separately if you want a local preview.

## Value

Invisibly returns the resulting URL (character string) when synchronous
(\`as_job = FALSE\`) or RStudio unavailable. When \`as_job = TRUE\` with
RStudio available, returns \`NULL\` immediately and populates
\`adhoc_last_publish\` in the global environment when the job finishes.

## See also

\[render_folder()\], \[deploy_folder()\], \[preview_folder()\]
