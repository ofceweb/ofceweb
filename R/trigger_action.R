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
#'   Branch on which the workflow will be run. Defaults to `NULL`, which
#'   auto-detects the repository's default branch via the GitHub API.
#' @param inputs `[list()]`\cr
#'   Named list of workflow inputs passed to the `workflow_dispatch` event
#'   (e.g. `list(profile = "review")`). Defaults to an empty list (no inputs).
#'
#' @return Invisibly returns `NULL`. Called for its side effects.
#' @section Other:
#'
#' @export
#'
#' @examples
#' \dontrun{
#' trigger_action()
#' trigger_action(workflow = "deploy.yml")
#' }
trigger_action <- function(root     = ".",
                           workflow = "ftp_deploy.yml",
                           branch   = NULL,
                           inputs   = list()) {
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

  # If branch not specified, detect default branch from GitHub API
  if (is.null(branch)) {
    repo_url <- sprintf(
      "https://api.github.com/repos/%s/%s", owner, repo
    )
    repo_resp <- httr2::request(repo_url) |>
      httr2::req_auth_bearer_token(token) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      ) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()
    branch <- tryCatch(
      httr2::resp_body_json(repo_resp)$default_branch,
      error = \(e) "main"
    )
  }

  url <- sprintf(
    "https://api.github.com/repos/%s/%s/actions/workflows/%s/dispatches",
    owner, repo, workflow
  )
  body <- list(ref = branch)
  if (length(inputs) > 0) body$inputs <- inputs

  resp <- httr2::request(url) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_headers(
      "Accept"               = "application/vnd.github+json",
      "X-GitHub-Api-Version" = "2022-11-28"
    ) |>
    httr2::req_body_json(body) |>
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
