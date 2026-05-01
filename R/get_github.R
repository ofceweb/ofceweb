
#' Recursively collect files from a GitHub directory
#'
#' Traverses a GitHub repository directory tree via the Contents API and
#' returns a list of `(url, dest)` pairs for every file that matches the
#' optional extension filter.  Directories are recursed up to `max_depth`
#' levels deep.
#'
#' @param owner GitHub user or organisation name.
#' @param repo  Repository name.
#' @param path  Path inside the repository to start from (e.g. `"posts"`).
#' @param destdir Local destination directory.  Defaults to `path`.
#' @param ref   Git ref (branch, tag, or SHA) to read from.  Defaults to
#'   `"HEAD"`.
#' @param ext   If non-`NULL`, only files whose names end with this string are
#'   collected (e.g. `".qmd"`).
#' @param max_depth Maximum recursion depth.  `Inf` means unlimited.
#' @param .depth Internal recursion counter — do not set manually.
#'
#' @return A list of named lists, each with elements `url` (the raw download
#'   URL) and `dest` (the local file path).
#'
#' @keywords internal
#' @noRd
collect_gh_files <- function(owner, repo, path, destdir=path, ref = "HEAD", ext = NULL, max_depth = Inf, .depth = 0) {
  contents <- gh::gh(
    "GET /repos/{owner}/{repo}/contents/{path}",
    owner = owner, repo = repo, path = path, ref = ref
  )

  files <- list()
  for (item in contents) {
    dest <- file.path(destdir, item$name)
    if (item$type == "file") {
      if (is.null(ext) || endsWith(item$name, ext)) {
        files <- c(files, list(list(url = item$download_url, dest = dest)))
      }
    } else if (item$type == "dir" && .depth < max_depth) {
      dir.create(dest, recursive = TRUE, showWarnings = FALSE)
      files <- c(files, collect_gh_files(owner, repo, item$path, dest, ref, ext, max_depth, .depth + 1))
    }
  }
  files
}

#' Parallel variant of \code{collect_gh_files}
#'
#' Lists the top-level subdirectories of `path` and delegates each subtree to
#' [collect_gh_files()] concurrently via `futurize::futurize()`, reducing
#' wall-clock time for repositories with many first-level directories.
#'
#' @inheritParams collect_gh_files
#'
#' @return Same structure as [collect_gh_files()]: a flat list of
#'   `list(url, dest)` pairs.
#'
#' @keywords internal
#' @noRd
fast_collect_gh_files  <-  function(owner, repo, path, destdir=path, ref = "HEAD", ext = NULL, max_depth = Inf, .depth = 0) {
  contents <- gh::gh(
    "GET /repos/{owner}/{repo}/contents/{path}",
    owner = owner, repo = repo, path = path, ref = ref
  )

  contents <- contents |> purrr::keep(~.x$type == "dir")

  purrr::map( contents,
       ~collect_gh_files(owner, repo, .x$path, destdir = .x$path, ref=ref, ext=ext, max_depth = max_depth, .depth=1) ) |>
    futurize::futurize() |>
    purrr::list_c()

}

#' Download a directory from a GitHub repository
#'
#' Recursively walks a GitHub repository directory, collects all matching
#' files in parallel with [fast_collect_gh_files()], then downloads them
#' locally using `curl`, adding a Bearer token header when a GitHub PAT is
#' available (required for private repositories).
#'
#' @param owner     GitHub user or organisation name.
#' @param repo      Repository name.
#' @param path      Path inside the repository to download (e.g. `"posts"`).
#' @param destdir   Local directory to write files into.  Defaults to `path`.
#' @param ref       Git ref (branch, tag, or SHA).  Defaults to `"HEAD"`.
#' @param ext       If non-`NULL`, only files ending with this string are
#'   downloaded (e.g. `".qmd"`).
#' @param max_depth Maximum directory recursion depth.  Defaults to `3`.
#'
#' @return `invisible(NULL)`, called for its side-effect of writing files to
#'   `destdir`.
#'
#' @examples
#' \dontrun{
#' # Download only .qmd files from the posts/ directory
#' download_gh_dir("OFCE", "Blog_OFCE", "posts", ext = ".qmd", max_depth = 3)
#' }
#'
#' @export
download_gh_dir <- function(owner, repo, path, destdir = path, ref = "HEAD",
                            ext = NULL, max_depth = 3) {
  dir.create(destdir, recursive = TRUE, showWarnings = FALSE)

  message("Collecting file list...")
  files <- fast_collect_gh_files(owner, repo, path, destdir, ref, ext, max_depth)

  if (length(files) == 0) {
    message("No matching files found.")
    return(invisible(NULL))
  }

  urls  <- purrr::map_chr(files, "url")
  dests <- purrr::map_chr(files, "dest")

  # Ensure all destination subdirectories exist
  purrr::walk(unique(dirname(dests)), dir.create, recursive = TRUE, showWarnings = FALSE)

  # multi_download doesn't pass auth headers; raw.githubusercontent.com requires
  # a token for private repos, so we use curl_download with a handle per file.
  token <- tryCatch(gh::gh_token(), error = function(e) "")

  message("Downloading ", length(urls), " file(s)...")
  purrr::walk2(urls, dests, function(url, dest) {
    h <- curl::new_handle()
    if (nchar(token) > 0) {
      curl::handle_setheaders(h, "Authorization" = paste("token", token))
    }
    curl::curl_download(url, dest, handle = h)
  }) |>
    futurize::futurize()

  message("Done: ", length(urls), " file(s) downloaded to ", destdir)
  invisible(NULL)
}

#' Download a single file from a GitHub repository
#'
#' Looks up a file by path in the GitHub Contents API and downloads it to a
#' local destination using `curl`.  A Bearer token is attached automatically
#' when a GitHub PAT is configured (needed for private repositories).
#'
#' @param path  Path to the file inside the repository (e.g.
#'   `"posts/2024-01-01/index.qmd"`).
#' @param dest  Local path to write the file to.  Defaults to `path`.
#' @param owner GitHub user or organisation name.  Defaults to `"ofceweb"`.
#' @param repo  Repository name.  Defaults to `"webblog"`.
#' @param ref   Git ref (branch, tag, or SHA).  Defaults to `"site-deploy"`.
#'
#' @return The local path `dest` on success, or `NULL` if the file was not
#'   found in the repository.
#'
#' @examples
#' \dontrun{
#' download_gh_file("posts/my-post/index.qmd", dest = "local/index.qmd")
#' }
#'
#' @export
download_gh_file <- function(path, dest = path, owner="ofceweb", repo = "webblog", ref="site-deploy") {

  contents <- gh::gh(
    "GET /repos/{owner}/{repo}/contents/.",
    owner = owner, repo = repo, path = fs::path_dir(path), ref = ref
  ) |>
    purrr::keep(~.x[["name"]] == fs::path_file(path))

  if(length(contents)!=1)
    return(NULL)

  url  <- contents[[1]] [["download_url"]]

  token <- tryCatch(gh::gh_token(), error = function(e) "")

  h <- curl::new_handle()

  if (nchar(token) > 0) {
    curl::handle_setheaders(h, "Authorization" = paste("token", token))
  }
  curl::curl_download(url, dest, handle = h)
  return(dest)
}

# Example — download only .qmd files
# download_gh_dir("OFCE", "Blog_OFCE", "posts", ext = ".qmd", max_depth = 3)
