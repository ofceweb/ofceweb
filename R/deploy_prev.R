#' Déploie la prévision OFCE (staging ou publish)
#'
#' Pousse le répertoire de sortie déjà rendu vers la branche git appropriée
#' sans relancer le rendu Quarto. Pour staging, pousse `_site_staging/` vers
#' `site-staging` ; pour publish, pousse `_site_publish/` vers `site-publish`.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param profile `"staging"` (défaut) ou `"publish"`.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Logique. Déclenche le workflow GitHub Actions FTP après le
#'   push. Défaut `TRUE`.
#' @param full_deploy Logique. Si `TRUE`, force la ré-émission de tous les
#'   fichiers vers le FTP (ignore l'état incrémental). Défaut `FALSE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [stage_prev()], [publish_prev()], [site2staging()]
#' @importFrom cli cli_abort
#' @section Prévision Users:
#'
#' @export
deploy_prev <- function(
    path        = ".",
    profile      = "staging",
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE) {

  profile <- match.arg(profile, c("staging", "publish"))

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  if (profile == "staging") {
    site_dir <- fs::path(root, "_site_staging")
    if (!fs::dir_exists(site_dir))
      cli::cli_abort(
        "Pas de dossier {.path _site_staging} — lancer \\
         {.run ofceweb::render_prev(profile = 'staging')} d'abord.")
    site2staging(
      path        = root,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy
    )
  } else {
    site_dir <- fs::path(root, "_site_publish")
    if (!fs::dir_exists(site_dir))
      cli::cli_abort(
        "Pas de dossier {.path _site_publish} — lancer \\
         {.run ofceweb::render_prev(profile = 'publish')} d'abord.")
    site2publish(
      path        = root,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy
    )
  }

  invisible(NULL)
}


#' Pousse `_site_staging/` vers la branche `site-staging`
#'
#' Wrapper de [site2branch()] configuré pour le déploiement staging de la
#' prévision. Le contenu est poussé **en clair** ; le chiffrement est appliqué
#' en CI par `ftp_deploy_staging.yml` avant le transfert FTP.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Logique. Déclenche `ftp_deploy_staging.yml` après le push.
#'   Défaut `TRUE`.
#' @param full_deploy Logique. Si `TRUE`, force la ré-émission complète vers
#'   le FTP. Défaut `FALSE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [deploy_prev()], [stage_prev()], [site2branch()]
#' @section Prévision Users:
#'
#' @export
site2staging <- function(
    path        = ".",
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE) {

  site2branch(
    path        = path,
    branch      = "site-staging",
    source      = "_site_staging",
    progress    = progress,
    trigger     = trigger,
    workflow    = "ftp_deploy_staging.yml",
    full_deploy = full_deploy
  )
}
