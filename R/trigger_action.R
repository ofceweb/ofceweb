#' Déclenche un workflow GitHub Actions via `workflow_dispatch`
#'
#' Envoie un événement `workflow_dispatch` à l'API GitHub Actions pour
#' démarrer manuellement un workflow (typiquement un job de déploiement
#' FTP). Ceci est appelé automatiquement par [site2branch()] sauf si
#' `trigger = FALSE`.
#'
#' Le token GitHub est résolu dans l'ordre suivant :
#' 1. La variable d'environnement `DEPLOY_PAT` — **requise en CI** car le
#'    `GITHUB_TOKEN` intégré ne peut pas déclencher d'autres workflows
#'    (GitHub le bloque pour empêcher les exécutions récursives).
#' 2. Le gestionnaire d'identifiants du système via \pkg{gitcreds} — adapté à
#'    un usage interactif local.
#'
#' @param root `[character(1)]`\cr
#'   Chemin vers le dépôt Git local utilisé pour résoudre le propriétaire et
#'   le nom du dépôt GitHub depuis l'URL du remote `origin`.
#'   Défaut [here::here()].
#' @param workflow `[character(1)]`\cr
#'   Nom du fichier de workflow à déclencher (ex. `"ftp_deploy.yml"`).
#' @param branch `[character(1)]`\cr
#'   Branche sur laquelle le workflow sera exécuté. Défaut `NULL`, ce qui
#'   détecte automatiquement la branche par défaut du dépôt via l'API
#'   GitHub.
#' @param inputs `[list()]`\cr
#'   Liste nommée d'entrées de workflow transmises à l'événement
#'   `workflow_dispatch` (ex. `list(profile = "review")`). Défaut une liste
#'   vide (pas d'entrée).
#'
#' @return Renvoie invisiblement `NULL`. Appelée pour ses effets de bord.
#' @keywords internal
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
