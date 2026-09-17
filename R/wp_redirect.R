#' Déploie la page de redirection vers la dernière version d'un WP OFCE
#'
#' Génère un `index.html` de redirection pointant vers la version courante du
#' WP (champ `version` de `_quarto.yml`), le pousse sur la branche
#' `site-redirect`, puis déclenche le workflow `ftp_redirect.yml` pour le
#' déployer à l'URL stable `www.ofce.fr/{site-path-sans-version}/`.
#'
#' Met également à jour la variable GitHub Actions `FTP_REDIRECT_DIR` avec le
#' répertoire parent du `site-path`.
#'
#' Ne fait rien pour les WPs brouillons (`wp: null`).
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param progress Logique. Affichage de la progression git. Défaut `TRUE`.
#' @param trigger Logique. Si `TRUE` (défaut), déclenche `ftp_redirect.yml`
#'   après le push.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [deploy_wp()], [publish_wp()], [wp_version_up()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_create dir_delete
#' @importFrom cli cli_h1 cli_alert_success cli_alert_warning cli_alert_info
#' @importFrom yaml read_yaml
#' @importFrom gert git_remote_list git_fetch git_init git_add git_commit git_signature_default git_remote_add git_remote_set_url git_remote_list
#' @importFrom glue glue
#' @keywords internal
push_wp_redirect <- function(path = ".", progress = TRUE, trigger = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  yml <- yaml::read_yaml(yml_path)

  if (is.null(yml$wp)) {
    cli::cli_alert_info("WP brouillon — pas de redirection stable à déployer.")
    return(invisible(NULL))
  }

  version   <- if (!is.null(yml$version)) as.character(yml$version) else NULL
  site_path <- yml$website$`site-path`

  if (is.null(version)) {
    cli::cli_alert_info("Pas de champ {.code version} — redirection stable ignorée.")
    return(invisible(NULL))
  }

  if (is.null(site_path) || !nzchar(site_path)) {
    cli::cli_alert_warning(
      "{.code site-path} absent du {.file _quarto.yml} — redirection ignorée.")
    return(invisible(NULL))
  }

  # Répertoire parent du site-path (sans le segment de version, si présent).
  # Le dernier segment de site-path est censé être `version` -- on le retire
  # par sa valeur connue (comparaison de chaîne, pas de regex numérique) car
  # une version personnalisée peut ne pas être purement numérique (ex.
  # "v2_corr", "v5_AS42").
  version_suffix <- paste0("/", version)
  redirect_dir <- if (endsWith(site_path, version_suffix)) {
    substr(site_path, 1L, nchar(site_path) - nchar(version_suffix))
  } else {
    site_path
  }
  if (!grepl("/$", redirect_dir)) redirect_dir <- paste0(redirect_dir, "/")

  # ---- Variable GitHub FTP_REDIRECT_DIR ------------------------------------
  set_gh_var(root, "FTP_REDIRECT_DIR", redirect_dir)

  # ---- Génération du HTML de redirection -----------------------------------
  lang     <- yml$lang %||% "fr"
  annee    <- yml$annee %||% ""
  wp_num   <- yml$wp
  site_url <- yml$website$`site-url` %||% ""
  if (!grepl("/$", site_url)) site_url <- paste0(site_url, "/")

  canonical <- sprintf("%s%s%s/", site_url, site_path, "")
  # canonical pointe vers la version versionnée complète
  canonical <- sprintf("%s%s/", site_url,
                       sub("/$", "", paste0(redirect_dir, version)))

  redirect_html <- sprintf(
'<!DOCTYPE html>
<html lang="%s">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=%s/">
  <link rel="canonical" href="%s">
  <title>WP %s-%s \u2014 redirection</title>
</head>
<body>
  <p>Redirection vers <a href="%s/">la derni\u00e8re version (%s)</a>\u2026</p>
  <script>window.location.replace("%s/");</script>
</body>
</html>',
    lang, version, canonical,
    annee, wp_num,
    version, version, version
  )

  # ---- Push vers site-redirect ---------------------------------------------
  branch <- "site-redirect"
  cli::cli_h1("Push de la redirection vers {.emph {branch}}")

  remotes <- gert::git_remote_list(repo = root)
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

  # Transférer l'état FTP si disponible
  dest_state <- fs::path(tmp, ".ftp-deploy-sync-state.json")
  if (fs::file_exists(state_file))
    fs::file_copy(state_file, dest_state, overwrite = TRUE)

  # Init repo temporaire, commit unique, force-push
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
    cli::cli_alert_warning("git push a échoué (code {ret}) — redirection non déployée.")
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

#' Déploie la page de redirection stable pour le WP en staging
#'
#' Génère un `index.html` de redirection pointant vers la version courante
#' d'un WP en staging FTP (lue depuis `website.site-url` de `_quarto.yml`,
#' de la forme `https://staging.ofce.fr/{repo}/{version}/`), le pousse sur la
#' branche `site-staging-redirect`, puis déclenche le workflow
#' `ftp_redirect_staging.yml` pour publier la page à l'URL stable
#' `staging.ofce.fr/{repo}/`.
#'
#' Met à jour la variable GitHub Actions `FTP_STAGING_REDIRECT_DIR` avec
#' `{repo}/` -- chemin relatif à la racine chroot `www/staging/` du compte
#' FTP `STAGING_USER` (même convention que `FTP_STAGING_DIR`, cf.
#' [setup_wp()]).
#'
#' Ne fait rien si `website.site-url` n'a pas la forme attendue (WP publié,
#' brouillon GitHub Pages, ou brouillon sans version encore attribuée).
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param progress Logique. Affichage de la progression git. Défaut `TRUE`.
#' @param trigger Logique. Si `TRUE` (défaut), déclenche
#'   `ftp_redirect_staging.yml` après le push.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [deploy_wp()], [push_wp_redirect()], [wp_version_up()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_create dir_delete
#' @importFrom cli cli_h1 cli_alert_success cli_alert_warning cli_alert_info cli_abort
#' @importFrom yaml read_yaml
#' @importFrom gert git_remote_list git_fetch git_init git_add git_commit git_signature_default git_remote_add git_remote_set_url
#' @importFrom glue glue
#' @keywords internal
push_wp_staging_redirect <- function(path = ".", progress = TRUE, trigger = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  yml <- yaml::read_yaml(yml_path)
  if (!isTRUE(yml$ofce_wp))
    cli::cli_abort(
      "{.fn push_wp_staging_redirect} ne fonctionne que sur un dépôt WP \\
       ({.code ofce_wp: true} absent du {.file _quarto.yml}).")

  site_url <- yml$website$`site-url`
  if (is.null(site_url) || !nzchar(site_url)) {
    cli::cli_alert_warning(
      "{.code website.site-url} absent du {.file _quarto.yml} \\
       — redirection staging ignorée.")
    return(invisible(NULL))
  }

  # site-url attendue pour un brouillon en staging FTP :
  # "https://staging.ofce.fr/{repo}/{version}/". Rien à faire si elle n'a pas
  # cette forme (WP publié -> "https://www.ofce.fr/", brouillon GitHub Pages
  # -> "https://{org}.github.io/{repo}/", ou brouillon sans version encore
  # attribuée).
  m <- regmatches(
    site_url,
    regexec("^https://staging\\.ofce\\.fr/([^/]+)/([^/]+)/?$", site_url)
  )[[1]]
  if (length(m) < 3L) {
    cli::cli_alert_info(
      "{.code website.site-url} ({.val {site_url}}) sans forme \\
       {.val staging.ofce.fr/<repo>/<version>/} — redirection staging non \\
       nécessaire.")
    return(invisible(NULL))
  }

  repo_id <- m[[2]]
  version <- m[[3]]

  # ---- Variable GitHub FTP_STAGING_REDIRECT_DIR -----------------------------
  redirect_dir <- paste0(repo_id, "/")
  set_gh_var(root, "FTP_STAGING_REDIRECT_DIR", redirect_dir)

  # ---- Génération du HTML de redirection -------------------------------------
  # Cible relative (méta-refresh/lien/JS) : le sous-dossier de version, dans
  # le même répertoire que la page de redirection elle-même (v1/, pas
  # /repo/ qui pointerait vers la page de redirection elle-même). L'URL
  # canonique (SEO), elle, reste absolue.
  relative_target <- paste0(version, "/")
  canonical <- sprintf("https://staging.ofce.fr/%s/%s/", repo_id, version)

  redirect_html <- sprintf(
'<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=%s">
  <link rel="canonical" href="%s">
  <title>WP %s \u2014 redirection</title>
</head>
<body>
  <p>Redirection vers <a href="%s">la derni\u00e8re version (%s)</a>\u2026</p>
  <script>window.location.replace("%s");</script>
</body>
</html>',
    relative_target, canonical, repo_id,
    relative_target, version,
    relative_target
  )

  # ---- Push vers site-staging-redirect ---------------------------------------
  branch <- "site-staging-redirect"
  cli::cli_h1("Push de la redirection vers {.emph {branch}}")

  remotes <- gert::git_remote_list(repo = root)
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

  # Transférer l'état FTP si disponible
  dest_state <- fs::path(tmp, ".ftp-deploy-sync-state.json")
  if (fs::file_exists(state_file))
    fs::file_copy(state_file, dest_state, overwrite = TRUE)

  # Init repo temporaire, commit unique, force-push
  gert::git_init(path = tmp)
  gert::git_add(".", repo = tmp)
  gert::git_commit(
    message = glue::glue("redirect-staging {repo_id}/{version} ({maintenant})"),
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
    cli::cli_alert_warning("git push a échoué (code {ret}) — redirection staging non déployée.")
    return(invisible(NULL))
  }

  cli::cli_alert_success(
    "Redirection staging {.val {repo_id}/{version}} poussée vers la branche {.emph {branch}}.")

  if (trigger) {
    tryCatch(
      trigger_action(root = root, workflow = "ftp_redirect_staging.yml"),
      error = function(e)
        cli::cli_warn("Déclenchement ftp_redirect_staging.yml échoué : {e$message}")
    )
  }

  invisible(NULL)
}
