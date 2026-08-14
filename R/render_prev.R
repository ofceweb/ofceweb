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
#' @param check_repo Logique. Si `TRUE` (défaut), vérifie l'état du dépôt git
#'   via [check_repo_status()].
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
#' @importFrom future plan
#' @importFrom future.mirai mirai_multisession
#' @importFrom quarto quarto_render
#' @importFrom yaml read_yaml
#' @export
render_prev <- function(
    path     = ".",
    profile  = "staging",
    check_repo = TRUE,
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

  if (check_repo) check_repo_status()

  tictoc::tic()
  servr::daemon_stop()
  future::plan(future.mirai::mirai_multisession, workers = workers)

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
#' @inheritParams render_prev
#' @param site2branch Logique. Si `TRUE` (défaut), appelle [site2staging()]
#'   après le rendu.
#' @param trigger Passé à [site2staging()]. Défaut = valeur de `site2branch`.
#' @param full_deploy Passé à [site2staging()]. Défaut `FALSE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [render_prev()], [deploy_prev()], [publish_prev()]
#' @export
stage_prev <- function(
    path        = ".",
    check_repo  = TRUE,
    progress    = TRUE,
    site2branch = TRUE,
    trigger     = site2branch,
    full_deploy = FALSE,
    preview     = FALSE,
    workers     = 8L) {

  render_prev(
    path       = path,
    profile    = "staging",
    check_repo = check_repo,
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
#' @export
publish_prev <- function(
    path        = ".",
    check_repo  = TRUE,
    progress    = TRUE,
    site2branch = TRUE,
    trigger     = site2branch,
    full_deploy = FALSE,
    preview     = FALSE,
    workers     = 8L) {

  render_prev(
    path       = path,
    profile    = "publish",
    check_repo = check_repo,
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
    check_repo  = TRUE,
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
    check_repo  = check_repo,
    progress    = progress,
    site2branch = site2branch,
    trigger     = trigger,
    preview     = render_site
  )
}
