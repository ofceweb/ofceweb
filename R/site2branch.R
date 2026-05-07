#' Push a rendered site folder to a Git branch
#'
#' Commits the contents of `_site/` (or another folder produced by a static
#' site generator) into an orphan-style commit and force-pushes it to the
#' `site-deploy` branch (or what is spefiied in `branch`) of the `origin` remote.  Optionally triggers a
#' downstream GitHub Actions workflow (e.g. an FTP deploy) via the
#' `workflow_dispatch` API (check your default branch is `main`).
#'
#' Credentials are resolved in the following order:
#' 1. The `DEPLOY_PAT` environment variable (recommended on CI).
#' 2. The OS credential store (macOS Keychain, Windows GCM, Linux libsecret)
#'    via the \pkg{credentials} package — suitable for interactive local use.
#'
#' SSH remote URLs are automatically converted to HTTPS before pushing because
#' libgit2 cannot use the system SSH agent.
#'
#' @param path `[character(1)]`\cr
#'   Path to the root of the local Git repository.
#'   Defaults to [here::here()].
#' @param branch `[character(1)]`\cr
#'   name of the branch targeted ("site-deploy")
#' @param source `[character(1)]`\cr
#'   path to the folder to deploy ("_site")
#' @param progress `[logical(1)]`\cr
#'   If `TRUE` (default), git output is forwarded to the console.
#' @param trigger `[logical(1)]`\cr
#'   If `TRUE` (default to `TRUE`), calls [trigger_ftp_deploy()] after a successful push
#'   to dispatch the FTP deploy workflow.  Failures are caught and reported as
#'   warnings so the overall push is not rolled back. Usually, a push on site-deploy is going to trigger the deploy.
#' @param workflow `[character(1)]`\cr
#'   name of the workflow to trigger
#' @param full_deploy `[logical(1)]`\cr
#'   If `FALSE` (default), the `.ftp-deploy-sync-state.json` file is carried
#'   forward from the remote branch so the FTP upload remains incremental.
#'   Set to `TRUE` to zero out every hash in the state file before pushing,
#'   which causes ftp-deploy to re-upload every file without deleting anything
#'   unrelated on the FTP server.
#'
#' @return Invisibly returns `NULL`. Called for its side effects.
#' @export
#'
#' @examples
#' \dontrun{
#' # Push _site/ and trigger the FTP workflow
#' site2branch()
#'
#' # Push only, without triggering the downstream workflow
#' site2branch(trigger = FALSE)
#'
#' # Force a full re-upload (ignore incremental state)
#' site2branch(full_deploy = TRUE)
#' }
#'
site2branch <- function(
    path = ".",
    branch = "site-deploy",
    source = "_site",
    progress = TRUE,
    trigger = TRUE,
    workflow = "ftp_deploy.yml",
    full_deploy = FALSE) {
  root <- path
  site_dir   <- fs::path(root, source)
  state_file <- fs::path(root, ".ftp-deploy-sync-state.json")

  if (!fs::dir_exists(site_dir)) {
    cli::cli_warn("{source} introuvable \u2014 push vers {branch} ignor\u00e9.")
    return(invisible(NULL))
  }
  remotes    <- gert::git_remote_list(repo = root)
  origin_url <- remotes$url[remotes$name == "origin"]
  if (length(origin_url) == 0) {
    cli::cli_warn("Pas de remote 'origin' \u2014 push vers {branch} ignor\u00e9.")
    return(invisible(NULL))
  }

  cli::cli_h1("Push de {source} vers la branche {.emph {branch}}")

  # Always fetch the FTP state from the remote branch so we have the latest copy
  # (the workflow commits it back after each deploy). Silently ignored on first run.
  tryCatch({
    gert::git_fetch(remote = "origin", repo = root, verbose = FALSE)
    system2(
      "git",
      c("-C", shQuote(root), "show",
        "origin/{branch}:.ftp-deploy-sync-state.json" |> glue::glue()),
      stdout = as.character(state_file)
    )
  }, error = function(e) NULL)

  maintenant <- ofce::date_jour_heure(lubridate::now(), short=TRUE)
  # Copy _site/ contents + state into a fresh temp directory.
  # full_deploy = FALSE: carry forward state as-is for an incremental upload.
  # full_deploy = TRUE:  zero every hash so ftp-deploy sees all files as changed
  #                      and re-uploads everything without wiping the FTP server.
  tmp <- fs::path(tempdir(), glue::glue("{branch}-{maintenant}"))
  fs::dir_copy(site_dir, tmp)
  if (dir.exists(fs::path(tmp, ".git")))
    fs::dir_delete(fs::path(tmp, ".git"))

  dest_state <- fs::path(tmp, ".ftp-deploy-sync-state.json")
  if (fs::file_exists(state_file)) {
    if (!full_deploy) {
      fs::file_copy(state_file, dest_state, overwrite = TRUE)
    } else {
      state <- jsonlite::read_json(state_file)
      state$data <- lapply(state$data, function(e) { e$hash <- ""; e })
      jsonlite::write_json(state, dest_state, auto_unbox = TRUE, pretty = TRUE)
    }
  }

  # Init a fresh repo, make a single orphan-style commit, force-push
  gert::git_init(path = tmp)
  gert::git_add(".", repo = tmp)
  gert::git_commit(
    message = glue::glue("render {maintenant}"),
    repo    = tmp,
    author  = gert::git_signature_default(repo = root)
  )
  # Embed credentials in the remote URL so libgit2 doesn't need to look them
  # up via a credential helper (which fails in a fresh repo on Windows).
  # On CI: DEPLOY_PAT env var (PAT triggers ftp_deploy.yml workflow).
  # Locally: OS keystore via credentials package (GCM / Keychain / libsecret).
  #
  # libgit2 cannot use the system SSH agent, so convert SSH URLs to HTTPS first.
  https_url <- if (grepl("^git@", origin_url)) {
    sub("^git@([^:]+):(.+)$", "https://\\1/\\2", origin_url)
  } else {
    origin_url
  }
  push_url <- tryCatch({
    pat <- Sys.getenv("DEPLOY_PAT", "")
    if (nchar(pat) > 0) {
      sub("https://", paste0("https://x-access-token:", pat, "@"), https_url)
    } else {
      cred <- credentials::git_credential_ask(https_url)
      sub("https://", paste0("https://", cred$username, ":", cred$password, "@"),
          https_url)
    }
  }, error = function(e) {
    cli::cli_warn("Impossible de r\u00e9cup\u00e9rer les credentials \u2014 tentative sans authentification.")
    https_url
  })
  existing_remotes <- gert::git_remote_list(repo = tmp)
  if ("origin" %in% existing_remotes$name) {
    gert::git_remote_set_url(name = "origin", url = push_url, repo = tmp)
  } else {
    gert::git_remote_add(url = push_url, name = "origin", repo = tmp)
  }
  # Use system git for the push:
  #   - gert::git_push() tries to set a local tracking branch afterwards,
  #     which fails on a fresh repo with no origin/main
  #   - credential.helper= (empty) prevents git from calling the macOS Keychain
  #     to store the embedded token, which fails non-interactively.
  ret <- system2(
    "git",
    c("-C", shQuote(tmp),
      "-c", "credential.helper=",
      "-c", "push.useForceWithLease=false",
      "push", "--force", push_url,
      glue::glue("HEAD:refs/heads/{branch}")),
    stdout = if (progress) "" else FALSE,
    stderr = if (progress) "" else FALSE
  )
  if (ret != 0L)
    cli::cli_abort("git push a échoué (code {ret}).")

  fs::dir_delete(tmp)
  cli::cli_alert_success("{source} pouss\u00e9 vers la branche {branch}.")

  if (trigger) {
    tryCatch(
      trigger_action(root = root, workflow = workflow),
      error = function(e)
        cli::cli_warn("FTP dispatch \u00e9chou\u00e9 : {e$message} — relancer manuellement avec trigger_action().")
    )
  }
  invisible(NULL)
}

#' Push a rendered site folder to a Git branch, set for publish
#'
#' Commits the contents of `_site_publish/` into an orphan-style commit and force-pushes it to the
#' `site-publish` branch of the `origin` remote.  Triggers a
#' downstream GitHub Actions workflow (e.g. an FTP deploy) via the
#' `workflow_dispatch` API (check your default branch is `main`).
#'
#' Credentials are resolved in the following order:
#' 1. The `DEPLOY_PAT` environment variable (recommended on CI).
#' 2. The OS credential store (macOS Keychain, Windows GCM, Linux libsecret)
#'    via the \pkg{credentials} package — suitable for interactive local use.
#'
#' SSH remote URLs are automatically converted to HTTPS before pushing because
#' libgit2 cannot use the system SSH agent.
#'
#' @param path `[character(1)]`\cr
#'   Path to the root of the local Git repository.
#'   Defaults to [here::here()].
#' @param progress `[logical(1)]`\cr
#'   If `TRUE` (default), git output is forwarded to the console.
#' @param trigger `[logical(1)]`\cr
#'   If `TRUE` (default to `FALSE`), calls [trigger_ftp_deploy()] after a successful push
#'   to dispatch the FTP deploy workflow.  Failures are caught and reported as
#'   warnings so the overall push is not rolled back. Usually, a push on site-deploy is going to trigger the deploy.
#' @param full_deploy `[logical(1)]`\cr
#'   Passed to [site2branch()]. Set to `TRUE` to force a complete re-upload.
#'
#' @return Invisibly returns `NULL`. Called for its side effects.
#' @export
#'
#' @examples
#' \dontrun{
#' # Push _site/ and trigger the FTP workflow
#' site2branch()
#'
#' # Push only, without triggering the downstream workflow
#' site2branch(trigger = FALSE)
#' }
#'
site2publish <- function(
    path = ".",
    progress = TRUE,
    trigger = TRUE,
    full_deploy = FALSE) {
site2branch(
  path=path,
  branch="site-publish",
  source="_site_publish",
  progress = progress,
  trigger=trigger,
  workflow="ftp_deploy_publish.yml",
  full_deploy = full_deploy)
}
