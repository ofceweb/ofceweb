#' Pousse la page de redirection vers la version courante d'un site OFCE
#'
#' Génère un `index.html` de redirection pointant vers la version courante du
#' site (lue depuis le `site-path` du `_quarto.yml`) et le pousse sur la
#' branche `site-redirect`, puis déclenche le workflow `ftp_redirect.yml` pour
#' publier la page sur le serveur FTP.
#'
#' Sans effet (sortie silencieuse) si `site-path` ne contient pas de segment
#' de version (`/v[0-9]+`) ou si `ofce_host` n'est pas `true`.
#'
#' Appelée automatiquement par [site_version_up()] lors d'un incrément de
#' version, et par [stage_site()] à chaque déploiement staging.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Logique. Si `TRUE` (défaut), déclenche `ftp_redirect.yml`
#'   après le push via [trigger_action()].
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [site_version_up()], [stage_site()], [deploy_site()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_create dir_delete
#' @importFrom cli cli_h1 cli_alert_success cli_alert_warning cli_alert_info cli_abort cli_warn
#' @importFrom yaml read_yaml
#' @importFrom gert git_remote_list git_fetch git_init git_add git_commit git_signature_default git_remote_add git_remote_set_url
#' @importFrom glue glue
#' @export
push_site_redirect <- function(path = ".", progress = TRUE, trigger = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  yml <- yaml::read_yaml(yml_path)

  if (!isTRUE(yml$ofce_host))
    cli::cli_abort(
      "{.fn push_site_redirect} ne fonctionne que si {.code ofce_host: true} \\
       est défini dans le {.file _quarto.yml}.")

  site_path <- yml$website$`site-path`
  if (is.null(site_path) || !nzchar(site_path)) {
    cli::cli_alert_warning(
      "{.code site-path} absent du {.file _quarto.yml} — redirection ignorée.")
    return(invisible(NULL))
  }

  if (!grepl("/v\\d+", site_path)) {
    cli::cli_alert_info(
      "{.code site-path} sans segment de version — redirection non nécessaire.")
    return(invisible(NULL))
  }

  # Version = dernier segment du site-path (ex. "v0")
  segments <- strsplit(site_path, "/", fixed = TRUE)[[1]]
  version  <- segments[length(segments)]

  # redirect_dir (chemin FTP) = site-path sans préfixe de localisation ni version
  # ex. "staging/mysite/v0" → segments sans premier et dernier → "mysite"
  ftp_segments <- segments[-c(1L, length(segments))]
  redirect_dir <- paste(ftp_segments, collapse = "/")
  if (!grepl("/$", redirect_dir)) redirect_dir <- paste0(redirect_dir, "/")

  # ---- Variable GitHub FTP_REDIRECT_DIR -------------------------------------
  set_gh_var(root, "FTP_REDIRECT_DIR", redirect_dir)

  # ---- Génération du HTML de redirection ------------------------------------
  # website.title n'est plus jamais écrit par setup_wp()/setup_prev()/
  # setup_site() (nettoyé par update_navbar()) ; on préfère le `title` de
  # premier niveau (WP), avec repli sur website.title pour les dépôts pas
  # encore nettoyés, puis chaîne vide.
  site_title <- if (!is.null(yml$title) && nzchar(yml$title))
    yml$title
  else if (!is.null(yml$website$title) && nzchar(yml$website$title))
    yml$website$title
  else ""
  # URL cible : chemin absolu-serveur vers la version courante
  target <- paste0("/", sub("/?$", "/", site_path))

  redirect_html <- build_redirect_html(
    target     = target,
    title      = glue::glue("{site_title} \u2014 redirection"),
    link_label = glue::glue("la derni\u00e8re version ({version})")
  )

  # ---- Push vers site-redirect ----------------------------------------------
  branch <- "site-redirect"
  cli::cli_h1("Push de la redirection vers {.emph {branch}}")

  remotes    <- gert::git_remote_list(repo = root)
  origin_url <- remotes$url[remotes$name == "origin"]
  if (length(origin_url) == 0) {
    cli::cli_alert_warning("Pas de remote 'origin' — push ignoré.")
    return(invisible(NULL))
  }

  # Récupérer l'état FTP incrémental depuis la branche distante (silencieux
  # au premier run)
  state_file <- fs::path(root, ".ftp-redirect-sync-state.json")
  tryCatch({
    gert::git_fetch(remote = "origin", repo = root, verbose = FALSE)
    system2(
      "git",
      c("-C", shQuote(root), "show",
        glue::glue("origin/{branch}:.ftp-deploy-sync-state.json")),
      stdout = as.character(state_file)
    )
  }, error = function(e) NULL)

  maintenant <- format(Sys.time(), "%Y%m%d-%H%M%S")
  tmp <- fs::path(tempdir(), glue::glue("{branch}-{maintenant}"))
  fs::dir_create(tmp)
  writeLines(redirect_html, fs::path(tmp, "index.html"))

  dest_state <- fs::path(tmp, ".ftp-deploy-sync-state.json")
  if (fs::file_exists(state_file))
    fs::file_copy(state_file, dest_state, overwrite = TRUE)

  gert::git_init(path = tmp)
  gert::git_add(".", repo = tmp)
  gert::git_commit(
    message = glue::glue("redirect {version} ({maintenant})"),
    repo    = tmp,
    author  = gert::git_signature_default(repo = root)
  )

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
    cli::cli_warn("Credentials introuvables — tentative sans authentification.")
    https_url
  })

  existing_remotes <- gert::git_remote_list(repo = tmp)
  if ("origin" %in% existing_remotes$name) {
    gert::git_remote_set_url(name = "origin", url = push_url, repo = tmp)
  } else {
    gert::git_remote_add(url = push_url, name = "origin", repo = tmp)
  }

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

  fs::dir_delete(tmp)

  if (ret != 0L) {
    cli::cli_alert_warning(
      "git push a échoué (code {ret}) — redirection non déployée.")
    return(invisible(NULL))
  }

  cli::cli_alert_success(
    "Redirection {.val {version}} poussée vers la branche {.emph {branch}}.")

  if (trigger) {
    tryCatch(
      trigger_action(root = root, workflow = "ftp_redirect.yml"),
      error = function(e)
        cli::cli_warn("Déclenchement ftp_redirect.yml échoué : {e$message}")
    )
  }

  invisible(NULL)
}
