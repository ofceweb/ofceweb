# Render the bilingual blog

Orchestrates a full build of the Quarto blog in both French and English.
It rebuilds the posts database, renders each language version in
parallel, updates the Algolia search index and sitemap, patches
Bootstrap CSS hashes, commits cache changes to git, and optionally
deploys the site or launches a local preview server.

## Usage

``` r
render_blog(
  path = ".",
  force_freeze = TRUE,
  workers = 8L,
  check_repo = TRUE,
  progress = TRUE,
  render_site = TRUE,
  check_freeze = FALSE,
  site2branch = FALSE,
  trigger = site2branch,
  freeze = TRUE
)
```

## Arguments

- path:

  Character path to the blog folder, default to ".".

- force_freeze:

  Logical. If \`TRUE\` (default), posts are re-rendered even when a
  cached version exists. Set to \`FALSE\` to reuse the cache wherever
  possible.

- workers:

  Integer. Number of parallel workers passed to
  \[future.mirai::mirai_multisession()\]. Defaults to \`8L\`.

- check_repo:

  Logical. If \`TRUE\` (default), calls \[check_repo_status()\] before
  rendering to ensure the git repository is in a clean state.

- progress:

  Logical. If \`TRUE\` (default), progress bars are displayed during
  long-running steps.

- render_site:

  Logical. If \`TRUE\` (default), starts a local HTTP daemon via
  \[servr::httw()\] to preview \`\_site\` after the build completes.

- check_freeze:

  Logical. If \`TRUE\`, the function aborts when any post is missing
  from the cache (strict freeze mode). Defaults to \`FALSE\`.

- site2branch:

  Logical. Reserved parameter (currently unused inside the function
  body; deployment is controlled by the \`push_site_deploy\` environment
  variable). Defaults to \`FALSE\`.

- trigger:

  Logical. Passed to \[site2branch()\] to optionally trigger a GitHub
  Actions workflow after deploying. Defaults to \`FALSE\`.

- freeze:

  Logical. If \`TRUE\` (default), passed to \[copy_files()\] to enable
  Quarto freeze mode when copying project scaffolding.

## Value

A data frame of staged git changes (output of \[gert::git_status()\]),
returned invisibly.

## Details

The function must be run from within an RStudio project that contains a
\`posts/\` directory. It also expects the project to live under a
directory named \`webblog\` and will prompt for confirmation otherwise.

Two variables are read from the calling environment (not function
arguments): - \`typst\`: passed to \[copy_post()\] to control Typst PDF
rendering. - \`push_site_deploy\`: if \`TRUE\`, calls \[site2branch()\]
to push \`\_site\` to the deployment branch; otherwise prints
instructions for doing so manually.

## See also

\[site2branch()\]

## Examples

``` r
if (FALSE) { # \dontrun{
render_blog()
} # }
```
