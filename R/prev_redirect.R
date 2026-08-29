#' Pousse la page de redirection stable /prev/derniere/ d'une prévision OFCE
#'
#' Génère un `index.html` de redirection pointant vers la prévision publiée
#' courante (`/prev/prevYYMM/`, lue depuis le `site-path` de
#' `_quarto-publish.yml`), le pousse sur la branche `site-redirect` du dépôt
#' de prévision, puis déclenche le workflow `ftp_redirect.yml` pour publier
#' la page à l'URL stable `www.ofce.fr/prev/derniere/`.
#'
#' Met à jour la variable GitHub Actions `FTP_REDIRECT_DIR` avec `derniere/`
#' (chemin relatif au répertoire `/prev/` du compte FTP `PREV_USER`, même
#' convention que `FTP_PUBLISH_DIR`).
#'
#' **Non appelée automatiquement** : la publication d'une prévision
#' ([publish_prev()] ou [deploy_prev()]`(profile = "publish")`) peut aussi
#' servir à corriger une prévision ancienne, auquel cas `/prev/derniere/` ne
#' doit **pas** être re-pointée. Appeler cette fonction manuellement, depuis
#' la racine du dépôt de la prévision qui devient la prévision courante,
#' juste après sa première publication.
#'
#' @param path Chemin vers la racine du dépôt de prévision. Défaut `"."`.
#' @param progress Logique. Affichage de la progression git. Défaut `TRUE`.
#' @param trigger Logique. Si `TRUE` (défaut), déclenche `ftp_redirect.yml`
#'   après le push via [trigger_action()].
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [publish_prev()], [deploy_prev()], [push_site_redirect()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_create dir_delete
#' @importFrom cli cli_h1 cli_alert_success cli_alert_warning cli_abort cli_warn
#' @importFrom yaml read_yaml
#' @importFrom gert git_remote_list git_fetch git_init git_add git_commit git_signature_default git_remote_add git_remote_set_url
#' @importFrom glue glue
#' @export
push_prev_redirect <- function(path = ".", progress = TRUE, trigger = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  yml <- yaml::read_yaml(yml_path)
  if (!isTRUE(yml$ofce_prev))
    cli::cli_abort(
      "{.fn push_prev_redirect} ne fonctionne que sur un dépôt de prévision \\
       ({.code ofce_prev: true} absent du {.file _quarto.yml}).")

  pub_path <- fs::path(root, "_quarto-publish.yml")
  if (!fs::file_exists(pub_path))
    cli::cli_abort(
      "Pas de {.file _quarto-publish.yml} dans {.path {root}}. \\
       Lancer {.run ofceweb::setup_prev()} d'abord.")

  pub <- yaml::read_yaml(pub_path)

  site_path <- pub$website$`site-path`
  if (is.null(site_path) || !nzchar(site_path)) {
    cli::cli_alert_warning(
      "{.code site-path} absent de {.file _quarto-publish.yml} \\
       — redirection ignorée.")
    return(invisible(NULL))
  }

  # ex. "prev/prev2603" -> cible "/prev/prev2603/", id "prev2603"
  segments <- strsplit(site_path, "/", fixed = TRUE)[[1]]
  prev_id  <- segments[length(segments)]
  target   <- paste0("/", sub("/?$", "/", site_path))

  # ---- Variable GitHub FTP_REDIRECT_DIR -------------------------------------
  # Chemin relatif au répertoire /prev/ du compte FTP (même convention que
  # FTP_PUBLISH_DIR, cf. setup_prev()).
  redirect_dir <- "derniere/"
  set_gh_var(root, "FTP_REDIRECT_DIR", redirect_dir)

  # ---- Génération du HTML de redirection ------------------------------------
  redirect_html <- build_redirect_html(
    target     = target,
    title      = glue::glue("Prévision OFCE — redirection"),
    link_label = glue::glue("la dernière prévision ({prev_id})")
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
    message = glue::glue("redirect {prev_id} ({maintenant})"),
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
    "Redirection {.val {prev_id}} poussée vers la branche {.emph {branch}}.")

  if (trigger) {
    tryCatch(
      trigger_action(root = root, workflow = "ftp_redirect.yml"),
      error = function(e)
        cli::cli_warn("Déclenchement ftp_redirect.yml échoué : {e$message}")
    )
  }

  invisible(NULL)
}


#' Pousse la page de redirection stable pour la prévision en staging
#'
#' Génère un `index.html` de redirection pointant vers la version courante de la
#' prévision en staging (lue depuis `_quarto-staging.yml`), le pousse sur la
#' branche `site-staging-redirect` du dépôt de prévision, puis déclenche le
#' workflow `ftp_redirect_staging.yml` pour publier la page à l'URL stable
#' `staging.ofce.fr/{prev_id}/`.
#'
#' Met à jour la variable GitHub Actions `FTP_STAGING_REDIRECT_DIR` avec le
#' chemin parent (sans segment de version).
#'
#' **Appelée automatiquement** par [stage_prev()] après le déploiement de la
#' version courante, afin que l'URL stable pointe toujours vers la dernière
#' version en staging. Peut aussi être appelée manuellement pour rafraîchir
#' la redirection sans refaire un build complet.
#'
#' @param path Chemin vers la racine du dépôt de prévision. Défaut `"."`.
#' @param progress Logique. Affichage de la progression git. Défaut `TRUE`.
#' @param trigger Logique. Si `TRUE` (défaut), déclenche `ftp_redirect_staging.yml`
#'   après le push via [trigger_action()].
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [stage_prev()], [push_prev_redirect()], [push_site_redirect()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_create dir_delete
#' @importFrom cli cli_h1 cli_alert_success cli_alert_warning cli_alert_info cli_abort cli_warn
#' @importFrom yaml read_yaml
#' @importFrom gert git_remote_list git_fetch git_init git_add git_commit git_signature_default git_remote_add git_remote_set_url
#' @importFrom glue glue
#' @export
push_prev_staging_redirect <- function(path = ".", progress = TRUE, trigger = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  yml <- yaml::read_yaml(yml_path)
  if (!isTRUE(yml$ofce_prev))
    cli::cli_abort(
      "{.fn push_prev_staging_redirect} ne fonctionne que sur un dépôt de prévision \\
       ({.code ofce_prev: true} absent du {.file _quarto.yml}).")

  stg_path <- fs::path(root, "_quarto-staging.yml")
  if (!fs::file_exists(stg_path))
    cli::cli_abort(
      "Pas de {.file _quarto-staging.yml} dans {.path {root}}. \\
       Lancer {.run ofceweb::setup_prev()} d'abord.")

  stg <- yaml::read_yaml(stg_path)

  site_path <- stg$website$`site-path`
  if (is.null(site_path) || !nzchar(site_path)) {
    cli::cli_alert_warning(
      "{.code site-path} absent de {.file _quarto-staging.yml} \\
       — redirection ignorée.")
    return(invisible(NULL))
  }

  # ex. "prev2609/v0" -> redirect_dir "prev2609/", version "v0"
  segments <- strsplit(site_path, "/", fixed = TRUE)[[1]]
  if (length(segments) < 2L) {
    cli::cli_alert_info(
      "{.code site-path} ({.val {site_path}}) sans segment de version \\
       — redirection non nécessaire.")
    return(invisible(NULL))
  }

  # Vérifier si le dernier segment est un version segment (vN)
  if (!grepl("^v\\d+$", segments[length(segments)])) {
    cli::cli_alert_info(
      "{.code site-path} ({.val {site_path}}) ne se termine pas par un segment de version \\
       — redirection non nécessaire.")
    return(invisible(NULL))
  }

  prev_id <- segments[length(segments) - 1L]
  version <- segments[length(segments)]
  redirect_dir <- paste(segments[-length(segments)], collapse = "/")
  target <- paste0("/", redirect_dir, "/")

  # ---- Variable GitHub FTP_STAGING_REDIRECT_DIR ---------------------------------
  # Chemin relatif au répertoire www/staging/ du compte FTP (même convention que
  # FTP_STAGING_DIR, cf. setup_prev()).
  set_gh_var(root, "FTP_STAGING_REDIRECT_DIR", paste0(redirect_dir, "/"))

  # ---- Génération du HTML de redirection -----------------------------------------
  redirect_html <- build_redirect_html(
    target     = target,
    title      = glue::glue("Prévision {prev_id} — redirection"),
    link_label = glue::glue("la dernière version ({version})")
  )

  # ---- Push vers site-staging-redirect ------------------------------------------
  branch <- "site-staging-redirect"
  cli::cli_h1("Push de la redirection vers {.emph {branch}}")

  remotes    <- gert::git_remote_list(repo = root)
  origin_url <- remotes$url[remotes$name == "origin"]
  if (length(origin_url) == 0) {
    cli::cli_alert_warning("Pas de remote 'origin' — push ignoré.")
    return(invisible(NULL))
  }

  # Récupérer l'état FTP incrémental depuis la branche distante (silencieux
  # au premier run)
  state_file <- fs::path(root, ".ftp-staging-redirect-sync-state.json")
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
    message = glue::glue("redirect-staging {prev_id}/{version} ({maintenant})"),
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
      "git push a échoué (code {ret}) — redirection staging non déployée.")
    return(invisible(NULL))
  }

  cli::cli_alert_success(
    "Redirection staging {.val {prev_id}/{version}} poussée vers la branche {.emph {branch}}.")

  if (trigger) {
    tryCatch(
      trigger_action(root = root, workflow = "ftp_redirect_staging.yml"),
      error = function(e)
        cli::cli_warn("Déclenchement ftp_redirect_staging.yml échoué : {e$message}")
    )
  }

  invisible(NULL)
}


#' Génère le HTML d'une page de redirection meta-refresh + canonical
#'
#' Helper commun à [push_site_redirect()] et [push_prev_redirect()].
#'
#' @param target URL cible de la redirection (chemin absolu-serveur, avec `/`
#'   final).
#' @param title Contenu de la balise `<title>`.
#' @param link_label Texte du lien affiché dans le corps de la page.
#' @param lang Attribut `lang` du document. Défaut `"fr"`.
#'
#' @returns Chaîne de caractères : le document HTML complet.
#' @noRd
build_redirect_html <- function(target, title, link_label, lang = "fr") {
  sprintf(
'<!DOCTYPE html>
<html lang="%s">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=%s">
  <link rel="canonical" href="%s">
  <title>%s</title>
</head>
<body>
  <p>Redirection vers <a href="%s">%s</a>\u2026</p>
  <script>window.location.replace("%s");</script>
</body>
</html>',
    lang, target, target, title, target, link_label, target
  )
}
