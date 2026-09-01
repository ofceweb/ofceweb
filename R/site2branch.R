#' Pousse un dossier de site rendu vers une branche Git
#'
#' Commite le contenu de `_site/` (ou un autre dossier produit par un
#' générateur de site statique) dans un commit de type orphelin et le
#' force-pousse vers la branche `site-deploy` (ou celle indiquée dans
#' `branch`) du remote `origin`. Déclenche en option un workflow GitHub
#' Actions en aval (ex. un déploiement FTP) via l'API `workflow_dispatch` (la
#' branche par défaut est détectée automatiquement).
#'
#' Les identifiants sont résolus dans l'ordre suivant :
#' 1. La variable d'environnement `DEPLOY_PAT` (recommandé en CI).
#' 2. Le gestionnaire d'identifiants du système (Keychain macOS, GCM Windows,
#'    libsecret Linux) via le paquet \pkg{credentials} — adapté à un usage
#'    interactif local.
#'
#' Les URL de remote en SSH sont automatiquement converties en HTTPS avant le
#' push car libgit2 ne peut pas utiliser l'agent SSH du système.
#'
#' @param path `[character(1)]`\cr
#'   Chemin vers la racine du dépôt Git local.
#'   Défaut ".".
#' @param branch `[character(1)]`\cr
#'   nom de la branche ciblée ("site-deploy")
#' @param source `[character(1)]`\cr
#'   chemin du dossier à déployer ("_site")
#' @param progress `[logical(1)]`\cr
#'   Si `TRUE` (défaut), la sortie git est transmise à la console.
#' @param trigger `[logical(1)]`\cr
#'   Si `TRUE` (défaut `TRUE`), appelle [trigger_ftp_deploy()] après un push
#'   réussi pour déclencher le workflow de déploiement FTP. Les échecs sont
#'   capturés et signalés comme des avertissements sans annuler le push.
#'   Généralement, un push sur site-deploy va déclencher le déploiement.
#' @param workflow `[character(1)]`\cr
#'   nom du workflow à déclencher
#' @param full_deploy `[logical(1)]`\cr
#'   Si `FALSE` (défaut), le fichier `.ftp-deploy-sync-state.json` est
#'   reporté depuis la branche distante afin que l'upload FTP reste
#'   incrémental. Mettre `TRUE` pour remettre à zéro chaque hash du fichier
#'   d'état avant le push, ce qui pousse ftp-deploy à re-uploader tous les
#'   fichiers sans rien supprimer d'autre sur le serveur FTP.
#' @param inputs `[list()]`\cr
#'   Liste nommée d'entrées de workflow transmises à [trigger_action()] en
#'   tant qu'entrées `workflow_dispatch` (ex. `list(profile = "review")`).
#'   Défaut une liste vide.
#'
#' @return Renvoie invisiblement `NULL`. Appelée pour ses effets de bord.
#' @keywords internal
#' @examples
#' \dontrun{
#' # Pousser _site/ et déclencher le workflow FTP
#' site2branch()
#'
#' # Pousser seulement, sans déclencher le workflow en aval
#' site2branch(trigger = FALSE)
#'
#' # Forcer un re-upload complet (ignorer l'état incrémental)
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
    full_deploy = FALSE,
    inputs = list()) {
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
      trigger_action(root = root, workflow = workflow, inputs = inputs),
      error = function(e) {
        cli::cli_warn("FTP dispatch \u00e9chou\u00e9 : {e$message}")
        cli::cli_warn("... relancer manuellement avec trigger_action() ou vérifier que la branche main a été poussée sur github.com.")
      }
    )
  }
  invisible(NULL)
}

#' Pousse un dossier de site rendu vers une branche Git, pour publication
#'
#' Commite le contenu de `_site_publish/` dans un commit de type orphelin et
#' le force-pousse vers la branche `site-publish` du remote `origin`.
#' Déclenche un workflow GitHub Actions en aval (ex. un déploiement FTP) via
#' l'API `workflow_dispatch` (la branche par défaut est détectée
#' automatiquement).
#'
#' Les identifiants sont résolus dans l'ordre suivant :
#' 1. La variable d'environnement `DEPLOY_PAT` (recommandé en CI).
#' 2. Le gestionnaire d'identifiants du système (Keychain macOS, GCM Windows,
#'    libsecret Linux) via le paquet \pkg{credentials} — adapté à un usage
#'    interactif local.
#'
#' Les URL de remote en SSH sont automatiquement converties en HTTPS avant le
#' push car libgit2 ne peut pas utiliser l'agent SSH du système.
#'
#' @param path `[character(1)]`\cr
#'   Chemin vers la racine du dépôt Git local.
#'   Défaut ".".
#' @param progress `[logical(1)]`\cr
#'   Si `TRUE` (défaut), la sortie git est transmise à la console.
#' @param trigger `[logical(1)]`\cr
#'   Si `TRUE` (défaut `FALSE`), appelle [trigger_ftp_deploy()] après un push
#'   réussi pour déclencher le workflow de déploiement FTP. Les échecs sont
#'   capturés et signalés comme des avertissements sans annuler le push.
#'   Généralement, un push sur site-deploy va déclencher le déploiement.
#' @param full_deploy `[logical(1)]`\cr
#'   Transmis à [site2branch()]. Mettre `TRUE` pour forcer un re-upload
#'   complet.
#'
#' @return Renvoie invisiblement `NULL`. Appelée pour ses effets de bord.
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Pousser _site/ et déclencher le workflow FTP
#' site2branch()
#'
#' # Pousser seulement, sans déclencher le workflow en aval
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
