#' Push a rendered site folder to a Git branch
#'
#' Commits the contents of `_site/` (or another folder produced by a static
#' site generator) into an orphan-style commit and force-pushes it to the
#' `site-deploy` branch of the `origin` remote.  Optionally triggers a
#' downstream GitHub Actions workflow (e.g. an FTP deploy) via the
#' `workflow_dispatch` API.
#'
#' Credentials are resolved in the following order:
#' 1. The `DEPLOY_PAT` environment variable (recommended on CI).
#' 2. The OS credential store (macOS Keychain, Windows GCM, Linux libsecret)
#'    via the \pkg{credentials} package — suitable for interactive local use.
#'
#' SSH remote URLs are automatically converted to HTTPS before pushing because
#' libgit2 cannot use the system SSH agent.
#'
#' @param root `[character(1)]`\cr
#'   Path to the root of the local Git repository.
#'   Defaults to [here::here()].
#' @param branch `[character(1)]`\cr
#'   name of the branch targeted ("site-deploy")
#' @param source `[character(1)]`\cr
#'   path to the folder to deploy ("_site")
#' @param progress `[logical(1)]`\cr
#'   If `TRUE` (default), git output is forwarded to the console.
#' @param trigger `[logical(1)]`\cr
#'   If `TRUE` (default), calls [trigger_ftp_deploy()] after a successful push
#'   to dispatch the FTP deploy workflow.  Failures are caught and reported as
#'   warnings so the overall push is not rolled back.
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
site2branch <- function(
    root = here::here(),
    branch = "site-deploy",
    source = "_site",
    progress = TRUE,
    trigger = TRUE) {

  site_dir   <- fs::path(root, source)
  state_file <- fs::path(root, ".ftp-deploy-sync-state.json")

  if (!fs::dir_exists(site_dir)) {
    cli::cli_warn("{source} introuvable \u2014 push vers site-deploy ignor\u00e9.")
    return(invisible(NULL))
  }
  remotes    <- gert::git_remote_list(repo = root)
  origin_url <- remotes$url[remotes$name == "origin"]
  if (length(origin_url) == 0) {
    cli::cli_warn("Pas de remote 'origin' \u2014 push vers {branch} ignor\u00e9.")
    return(invisible(NULL))
  }

  cli::cli_h1("Push de {source} vers la branche {.emph {branch}}")

  # Carry forward the FTP differential state from the current site-deploy branch
  # so the next FTP deploy remains incremental. Silently ignored on first run.
  tryCatch({
    gert::git_fetch(remote = "origin", repo = root, verbose = FALSE)
    system2(
      "git",
      c("-C", shQuote(root), "show",
        "origin/site-deploy:.ftp-deploy-sync-state.json"),
      stdout = as.character(state_file)
    )
  }, error = function(e) NULL)
  maintenant <- ofce::date_jour_heure(lubridate::now())
  # Copy _site/ contents + state (if present) into a fresh temp directory
  tmp <- fs::path(tempdir(), glue::glue("{branch}-{maintenant}"))
  fs::dir_copy(site_dir, tmp)
  if(dir.exists(fs::path(tmp, ".git")))
    fs::dir_delete(fs::path(tmp, ".git"))
  if (fs::file_exists(state_file))
    fs::file_copy(state_file, fs::path(tmp, ".ftp-deploy-sync-state.json"), overwrite = TRUE)

  # Init a fresh repo, make a single orphan-style commit, force-push
  gert::git_init(path = tmp)
  gert::git_add(".", repo = tmp)
  now <- lubridate::stamp("28/12/2026 12:32:54", quiet = TRUE)(
    lubridate::now(tzone = "Europe/Paris"))
  gert::git_commit(
    message = glue::glue("render {now}"),
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
  #     which fails on a fresh repo with no origin/master.
  #   - credential.helper= (empty) prevents git from calling the macOS Keychain
  #     to store the embedded token, which fails non-interactively.
  ret <- system2(
    "git",
    c("-C", shQuote(tmp),
      "-c", "credential.helper=",
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
      trigger_ftp_deploy(root = root),
      error = function(e)
        cli::cli_warn("FTP dispatch \u00e9chou\u00e9 : {e$message} — relancer manuellement avec trigger_ftp_deploy().")
    )
  }
  invisible(NULL)
}

#' Trigger a GitHub Actions workflow via `workflow_dispatch`
#'
#' Sends a `workflow_dispatch` event to the GitHub Actions API to manually
#' start a workflow (typically an FTP deploy job).  This is called
#' automatically by [site2branch()] unless `trigger = FALSE`.
#'
#' The GitHub token is resolved in the following order:
#' 1. The `DEPLOY_PAT` environment variable — **required on CI** because
#'    the built-in `GITHUB_TOKEN` cannot dispatch other workflows (GitHub
#'    blocks it to prevent recursive runs).
#' 2. The OS credential store via \pkg{gitcreds} — suitable for interactive
#'    local use.
#'
#' @param root `[character(1)]`\cr
#'   Path to the local Git repository used to resolve the GitHub owner and
#'   repository name from the `origin` remote URL.
#'   Defaults to [here::here()].
#' @param workflow `[character(1)]`\cr
#'   File name of the workflow to dispatch (e.g. `"ftp_deploy.yml"`).
#' @param branch `[character(1)]`\cr
#'   Branch on which the workflow will be run. Defaults to `"site-deploy"`.
#'
#' @return Invisibly returns `NULL`. Called for its side effects.
#' @export
#'
#' @examples
#' \dontrun{
#' trigger_ftp_deploy()
#' trigger_ftp_deploy(workflow = "deploy.yml", branch = "main")
#' }
trigger_ftp_deploy <- function(root     = here::here(),
                               workflow = "ftp_deploy.yml",
                               branch   = "site-deploy") {
  # Resolve owner/repo from git remote
  remotes    <- gert::git_remote_list(repo = root)
  origin_url <- remotes$url[remotes$name == "origin"]
  if (length(origin_url) == 0)
    cli::cli_abort("Pas de remote 'origin' trouv\u00e9.")
  slug  <- origin_url |> sub(pattern = "\\.git$", replacement = "") |>
    sub(pattern = "^git@[^:]+:", replacement = "") |>
    sub(pattern = "^https://[^/]+/", replacement = "")
  parts <- strsplit(slug, "/")[[1]]
  owner <- parts[1]; repo <- parts[2]

  # Token priority:
  #   1. DEPLOY_PAT env var — must be set on CI; GITHUB_TOKEN cannot dispatch
  #      other workflows (GitHub blocks it to prevent recursive runs).
  #   2. OS credential store (macOS Keychain / Windows GCM) — for local use.
  token <- Sys.getenv("DEPLOY_PAT", "")
  if (!nchar(token))
    token <- tryCatch(
      gitcreds::gitcreds_get("https://github.com")$password,
      error = \(e) ""
    )
  if (!nchar(token))
    cli::cli_abort(c(
      "Aucun token GitHub trouv\u00e9.",
      "i" = "D\u00e9finissez {.envvar DEPLOY_PAT} dans {.file ~/.Renviron} ou connectez-vous avec {.code usethis::create_github_token()}."
    ))

  url <- sprintf(
    "https://api.github.com/repos/%s/%s/actions/workflows/%s/dispatches",
    owner, repo, workflow
  )
  resp <- httr2::request(url) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_headers(
      "Accept"               = "application/vnd.github+json",
      "X-GitHub-Api-Version" = "2022-11-28"
    ) |>
    httr2::req_body_json(list(ref = branch)) |>
    httr2::req_error(is_error = \(r) FALSE) |>
    httr2::req_perform()

  code <- httr2::resp_status(resp)
  if (code == 204L) {
    cli::cli_alert_success("Workflow {.val {workflow}} d\u00e9clench\u00e9 sur {.val {branch}}.")
  } else {
    body <- tryCatch(httr2::resp_body_json(resp)$message, error = \(e) "?")
    cli::cli_abort("GitHub API a retourn\u00e9 HTTP {code}: {body}")
  }
  invisible(NULL)
}
