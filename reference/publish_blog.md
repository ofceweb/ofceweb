# Publish the bilingual blog

A convenience wrapper around \[render_blog()\] that sets \`site2branch =
TRUE\` to deploy \`\_site\` to the deployment branch after rendering.

## Usage

``` r
publish_blog(
  path = ".",
  force_freeze = TRUE,
  workers = 8L,
  check_repo = TRUE,
  progress = TRUE,
  render_site = FALSE,
  check_freeze = FALSE,
  trigger = TRUE,
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

- trigger:

  Logical. Passed to \[site2branch()\] to optionally trigger a GitHub
  Actions workflow after deploying. Defaults to \`FALSE\`.

- freeze:

  Logical. If \`TRUE\` (default), passed to \[copy_files()\] to enable
  Quarto freeze mode when copying project scaffolding.

## Value

A data frame of staged git changes, returned invisibly.

## See also

\[render_blog()\], \[site2branch()\]

## Examples

``` r
if (FALSE) { # \dontrun{
publish_blog()
} # }
```
