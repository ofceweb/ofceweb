#' Rend le site de prévision OFCE (staging ou publish)
#'
#' Lance un build Quarto du dépôt de prévision courant avec le profil indiqué.
#' Nettoie le répertoire de sortie avant le rendu. Le chiffrement n'a **pas**
#' lieu en local — il est appliqué en CI par le workflow `ftp_deploy_staging.yml`
#' avant le transfert FTP.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param profile `"staging"` (défaut), `"publish"`, ou tout autre profil
#'   Quarto déclaré dans `_quarto.yml`. Détermine le répertoire de sortie
#'   (`_site_staging`, `_site_publish`, ou `_site_{profile}` pour tout autre
#'   profil).
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param preview Logique. Si `TRUE`, lance un serveur HTTP local via
#'   [servr::httw()] sur le répertoire de sortie après le rendu. Défaut `TRUE`
#' @param workers Entier. Nombre de workers parallèles. Défaut `8L`.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [stage_prev()], [publish_prev()], [setup_prev()], [check_prev()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists dir_delete dir_ls file_delete
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_alert_warning
#' @importFrom tictoc tic toc
#' @importFrom servr daemon_stop httw
#' @importFrom quarto quarto_render
#' @importFrom yaml read_yaml
#' @export
render_prev <- function(
    path     = ".",
    profile  = "staging",
    progress   = TRUE,
    preview    = TRUE,
    workers    = 8L) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  project <- fs::path_file(root) |> as.character()
  cli::cli_h1("render_prev [{profile}] : {project}")

  if (!fs::file_exists(fs::path(root, "_quarto.yml")))
    cli::cli_abort(
      "Pas de {.file _quarto.yml} dans {.path {root}}. \\
       Lancer {.run ofceweb::setup_prev()}.")

  yml_top <- tryCatch(yaml::read_yaml(fs::path(root, "_quarto.yml")),
                      error = function(e) NULL)
  if (!is.null(yml_top) && !isTRUE(yml_top$ofce_prev))
    cli::cli_alert_warning(
      "Le {.file _quarto.yml} ne contient pas {.code ofce_prev: true}. \\
       Dépôt initialisé via {.run ofceweb::setup_prev()} ?")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  tictoc::tic()
  servr::daemon_stop()

  site_dir <- paste0("_site_", profile)

  # Vider le répertoire de sortie
  if (fs::dir_exists(site_dir))
    tryCatch(
      fs::dir_delete(site_dir),
      error = function(e) { Sys.sleep(1); fs::dir_delete(site_dir) }
    )

  cli::cli_h2("Rendu Quarto (profil : {.emph {profile}})")
  quarto::quarto_render(profile = profile, as_job = FALSE)

  # Nettoyer les DS_Store
  if (fs::dir_exists(site_dir))
    fs::dir_ls(site_dir, recurse = TRUE, regexp = "DS_Store$",
               type = "file", all = TRUE) |>
      fs::file_delete()

  tictoc::toc()

  cli::cli_text(
    "Rendu dans {.path {site_dir}}. \\
     Pour déployer, lancer {.run ofceweb::deploy_prev(profile='{profile}')}")

  if (preview) {
    cli::cli_h2("Prévisualisation locale ({site_dir})")
    servr::httw(site_dir, daemon = TRUE)
  }

  invisible(NULL)
}


#' Rend et déploie la prévision en staging
#'
#' Enchaîne [render_prev()] avec le profil `"staging"` puis pousse
#' `_site_staging/` (en clair) vers la branche `site-staging` via
#' [site2staging()]. Le chiffrement est appliqué **en CI** par le workflow
#' `ftp_deploy_staging.yml` avant le transfert FTP.
#'
#' Après déploiement, met automatiquement à jour la redirection stable vers la
#' dernière version en staging (via [push_prev_staging_redirect()]), sauf si
#' `trigger_staging_redirect = FALSE`.
#'
#' @inheritParams render_prev
#' @param site2branch Logique. Si `TRUE` (défaut), appelle [site2staging()]
#'   après le rendu.
#' @param trigger Passé à [site2staging()]. Défaut = valeur de `site2branch`.
#' @param full_deploy Passé à [site2staging()]. Défaut `FALSE`.
#' @param trigger_staging_redirect Logique. Si `TRUE` (défaut), appelle
#'   [push_prev_staging_redirect()] après [site2staging()]. Défaut `TRUE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [render_prev()], [deploy_prev()], [publish_prev()], [push_prev_staging_redirect()]
#' @importFrom gh gh
#' @export
stage_prev <- function(
    path        = ".",
    progress    = TRUE,
    site2branch = TRUE,
    trigger     = site2branch,
    full_deploy = FALSE,
    preview     = FALSE,
    workers     = 8L,
    trigger_staging_redirect = TRUE) {

  check_gh_login()

  render_prev(
    path       = path,
    profile    = "staging",
    progress   = progress,
    preview    = preview,
    workers    = workers
  )

  if (site2branch) {
    site2staging(
      path        = path,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy
    )

    root <- path |>
      fs::path_expand() |>
      fs::path_abs() |>
      fs::path_norm()

    stg <- tryCatch(
      yaml::read_yaml(fs::path(root, "_quarto-staging.yml")),
      error = function(e) NULL
    )
    site_path <- stg$website$`site-path`
    if (!is.null(site_path) && nzchar(site_path)) {
      # Compat : dépôts non re-migrés depuis le renommage du domaine de
      # staging (site-path portait auparavant un préfixe "staging/", absorbé
      # depuis par le sous-domaine staging.ofce.fr).
      if (grepl("^staging/", site_path)) {
        cli::cli_alert_warning(
          "{.code site-path} ({.val {site_path}}) dans {.file _quarto-staging.yml} \\
           porte encore un préfixe {.val staging/} périmé — relancer \\
           {.run ofceweb::setup_prev()} pour corriger le fichier.")
        site_path <- sub("^staging/", "", site_path)
      }
      staging_url <- sprintf("https://staging.ofce.fr/%s/", site_path)
      cli::cli_alert_success(
        "Pr\u00e9vision en staging \u2014 disponible (apr\u00e8s d\u00e9ploiement FTP) \\
         sur {.url {staging_url}}")
    }

    # Mettre à jour la redirection stable vers la dernière version en staging
    if (trigger_staging_redirect && !is.null(site_path) && nzchar(site_path)) {
      tryCatch(
        push_prev_staging_redirect(path = path, progress = progress, trigger = trigger),
        error = function(e)
          cli::cli_alert_warning(
            "Mise à jour de la redirection staging échouée : {conditionMessage(e)}")
      )
    }
  } else {
    cli::cli_text(
      "Pour déployer en staging, lancer \\
       {.run ofceweb::deploy_prev('staging')}")
  }

  invisible(NULL)
}


#' Rend et publie la prévision (publish)
#'
#' Enchaîne [render_prev()] avec le profil `"publish"` puis pousse
#' `_site_publish/` vers la branche `site-publish` via [site2publish()].
#'
#' @inheritParams stage_prev
#'
#' @returns Invisible `NULL`.
#' @seealso [render_prev()], [deploy_prev()], [stage_prev()]
#' @importFrom gh gh
#' @export
publish_prev <- function(
    path        = ".",
    progress    = TRUE,
    site2branch = TRUE,
    trigger     = site2branch,
    full_deploy = FALSE,
    preview     = FALSE,
    workers     = 8L) {

  check_gh_login()

  render_prev(
    path       = path,
    profile    = "publish",
    progress   = progress,
    preview    = preview,
    workers    = workers
  )

  if (site2branch) {
    site2publish(
      path        = path,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy
    )
  } else {
    cli::cli_text(
      "Pour publier, lancer {.run ofceweb::deploy_prev(profile = 'publish')}")
  }

  invisible(NULL)
}


#' Génère le site de la prévision (déprécié)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' Cette fonction est remplacée par [publish_prev()].
#'
#' @inheritParams render_prev
#' @param render_site Logique. Passé à `preview` de [publish_prev()].
#' @param site2branch Logique. Passé à `site2branch` de [publish_prev()].
#' @param trigger Passé à [publish_prev()].
#'
#' @returns Invisible `NULL`.
#' @seealso [publish_prev()]
#' @export
render_prev_publish <- function(
    path        = ".",
    progress    = TRUE,
    render_site = TRUE,
    site2branch = TRUE,
    trigger     = site2branch) {

  .Deprecated("publish_prev",
              msg = paste0(
                "`render_prev_publish()` est dépréciée. ",
                "Utiliser `publish_prev()` à la place."))

  publish_prev(
    path        = path,
    progress    = progress,
    site2branch = site2branch,
    trigger     = trigger,
    preview     = render_site
  )
}
