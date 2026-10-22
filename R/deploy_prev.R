#' Déploie la prévision OFCE (staging ou publish)
#'
#' Pousse le répertoire de sortie déjà rendu vers la branche git appropriée
#' sans relancer le rendu Quarto. Pour staging, pousse `_site_staging/` vers
#' `site-staging` ; pour publish, pousse `_site_publish/` vers `site-publish`.
#'
#' Pour les profils `"staging"`/`"publish"`, la variable GitHub Actions FTP
#' correspondante (`FTP_STAGING_DIR`/`FTP_PUBLISH_DIR`) est resynchronisée
#' depuis `_quarto-staging.yml`/`_quarto-publish.yml` juste avant de
#' déclencher le workflow (voir [sync_ftp_dir_var()]), pour rester correcte
#' même si leur `site-path` a été modifié en dehors de [prev_version_up()]/
#' [setup_prev()] depuis le dernier déploiement. Un profil personnalisé n'a
#' aucune variable à resynchroniser : `ftp_deploy_profile.yml` calcule le
#' répertoire cible directement à partir du nom du dépôt et du profil.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param profile `"staging"` (défaut), `"publish"`, ou tout autre profil
#'   Quarto déclaré dans `_quarto.yml`. Les profils personnalisés sont déployés
#'   vers `staging/{repo}/{profile}/` sans numéro de version.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Logique. Déclenche le workflow GitHub Actions FTP après le
#'   push. Défaut `TRUE`.
#' @param full_deploy Logique. Si `TRUE`, force la ré-émission de tous les
#'   fichiers vers le FTP (ignore l'état incrémental). Défaut `FALSE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [stage_prev()], [publish_prev()], [site2staging()]
#' @importFrom cli cli_abort
#' @importFrom yaml read_yaml
#' @keywords internal
deploy_prev <- function(
    path        = ".",
    profile      = "staging",
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE) {

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

    # Resynchronise FTP_STAGING_DIR depuis le site-path actuel de
    # _quarto-staging.yml -- au cas où il aurait été modifié (édition
    # manuelle, merge, ...) sans repasser par prev_version_up()/setup_prev()
    # depuis le dernier déploiement.
    stg_yml_path <- fs::path(root, "_quarto-staging.yml")
    if (fs::file_exists(stg_yml_path)) {
      stg <- tryCatch(yaml::read_yaml(stg_yml_path), error = function(e) NULL)
      sync_ftp_dir_var(root, "FTP_STAGING_DIR", stg$website$`site-path`)
    }

    site2staging(
      path        = root,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy
    )
  } else if (profile == "publish") {
    site_dir <- fs::path(root, "_site_publish")
    if (!fs::dir_exists(site_dir))
      cli::cli_abort(
        "Pas de dossier {.path _site_publish} — lancer \\
         {.run ofceweb::render_prev(profile = 'publish')} d'abord.")

    # Resynchronise FTP_PUBLISH_DIR depuis le site-path actuel de
    # _quarto-publish.yml -- même garde-fou que ci-dessus pour le profil
    # staging.
    pub_yml_path <- fs::path(root, "_quarto-publish.yml")
    if (fs::file_exists(pub_yml_path)) {
      pub <- tryCatch(yaml::read_yaml(pub_yml_path), error = function(e) NULL)
      sync_ftp_dir_var(root, "FTP_PUBLISH_DIR", pub$website$`site-path`)
    }

    site2publish(
      path        = root,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy
    )
  } else {
    site_dir <- fs::path(root, paste0("_site_", profile))
    if (!fs::dir_exists(site_dir))
      cli::cli_abort(
        "Pas de dossier {.path _site_{profile}} — lancer \\
         {.run ofceweb::render_prev(profile = '{profile}')} d'abord.")
    # Pas de variable GitHub à resynchroniser ici : ftp_deploy_profile.yml
    # calcule server-dir directement depuis le nom du dépôt et l'entrée
    # `profile` passée au déclenchement du workflow (cf. site2profile()).
    site2profile(
      path        = root,
      profile     = profile,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy
    )
  }

  invisible(NULL)
}


#' Déploie un profil personnalisé vers staging/{repo}/{profile}/
#'
#' Wrapper de [site2branch()] pour les profils Quarto qui ne sont ni
#' `"staging"` ni `"publish"`. Pousse `_site_{profile}/` vers la branche
#' `site-{profile}` et déclenche le workflow `ftp_deploy_profile.yml` en lui
#' passant le nom du profil en entrée. Le FTP cible est
#' `staging/{repo}/{profile}/` — sans numéro de version, le profil jouant ce
#' rôle.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param profile Nom du profil Quarto (doit correspondre à un fichier
#'   `_quarto-{profile}.yml` dans le dépôt).
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Logique. Déclenche `ftp_deploy_profile.yml` après le push.
#'   Défaut `TRUE`.
#' @param full_deploy Logique. Si `TRUE`, force la ré-émission complète vers
#'   le FTP. Défaut `FALSE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [deploy_prev()], [site2branch()], [site2staging()]
#' @keywords internal
site2profile <- function(
    path        = ".",
    profile,
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE) {

  site2branch(
    path        = path,
    branch      = paste0("site-", profile),
    source      = paste0("_site_", profile),
    progress    = progress,
    trigger     = trigger,
    workflow    = "ftp_deploy_profile.yml",
    inputs      = list(profile = profile),
    full_deploy = full_deploy
  )
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
#' @keywords internal
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
