# Download a directory from a GitHub repository

Recursively walks a GitHub repository directory, collects all matching
files in parallel with \[fast_collect_gh_files()\], then downloads them
locally using \`curl\`, adding a Bearer token header when a GitHub PAT
is available (required for private repositories).

## Usage

``` r
download_gh_dir(
  owner,
  repo,
  path,
  destdir = path,
  ref = "HEAD",
  ext = NULL,
  max_depth = 3
)
```

## Arguments

- owner:

  GitHub user or organisation name.

- repo:

  Repository name.

- path:

  Path inside the repository to download (e.g. \`"posts"\`).

- destdir:

  Local directory to write files into. Defaults to \`path\`.

- ref:

  Git ref (branch, tag, or SHA). Defaults to \`"HEAD"\`.

- ext:

  If non-\`NULL\`, only files ending with this string are downloaded
  (e.g. \`".qmd"\`).

- max_depth:

  Maximum directory recursion depth. Defaults to \`3\`.

## Value

\`invisible(NULL)\`, called for its side-effect of writing files to
\`destdir\`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Download only .qmd files from the posts/ directory
download_gh_dir("OFCE", "Blog_OFCE", "posts", ext = ".qmd", max_depth = 3)
} # }
```
