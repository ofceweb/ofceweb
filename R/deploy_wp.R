#' Déploie un document de travail (WP) OFCE
#'
#' Route le déploiement selon l'état du WP :
#' \itemize{
#'   \item **Brouillon** (`wp: null` dans `_quarto.yml`) : publie sur GitHub
#'     Pages via `quarto publish gh-pages`.
#'   \item **Publié** (`wp: N`) : pousse `_site/` vers la branche `site-deploy`
#'     via [site2branch()], d'où le workflow FTP le transfère vers
#'     `www.ofce.fr/wp/{annee}/{N}/{version}/`.
#' }
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Passé à [site2branch()] (WP publié uniquement).
#'   Déclenche le workflow GitHub Actions FTP. Défaut `TRUE`.
#' @param full_deploy Passé à [site2branch()]. Défaut `FALSE`.
#' @param ... Arguments supplémentaires passés à [site2branch()].
#'
#' @returns Invisible `NULL`.
#' @seealso [render_wp()], [site2branch()], [wp_version_up()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_exists
#' @importFrom cli cli_h2 cli_abort cli_alert_success cli_alert_warning cli_text
#' @importFrom yaml read_yaml
#' @export
deploy_wp <- function(
    path = ".",
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE,
    ...) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort(
      "Pas de {.file _quarto.yml} dans {.path {root}}. Lancer {.run ofceweb::setup_wp()}.")

  yml <- yaml::read_yaml(yml_path)

  wp      <- yml$wp
  annee   <- yml$annee
  version <- as.character(yml$version %||% "v0")

  # URL finale pour le message de succès
  final_url <- if (!is.null(wp) && !is.null(annee)) {
    sprintf("https://www.ofce.fr/wp/%d/%03d/%s/index.html", annee, wp, version)
  } else {
    su <- yml$website$`site-url`
    if (!is.null(su) && nzchar(su)) paste0(sub("/?$", "/", su), "index.html") else NULL
  }

  if (!is.null(wp)) {
    # ---- WP publié : FTP via site-deploy ------------------------------------
    cli::cli_h2("Déploiement WP publié (site2branch → FTP)")
    cli::cli_text("WP {wp} / {annee} / {version} → {.url {final_url %||% 'www.ofce.fr'}}")

    if (!fs::dir_exists(fs::path(root, "_site")))
      cli::cli_alert_warning(
        "Pas de dossier {.path _site} — lancer {.run ofceweb::render_wp()} d'abord.")

    res <- site2branch(
      path        = root,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy,
      ...
    )

    # URL stable : redirection vers la version courante
    tryCatch(
      push_wp_redirect(root, progress = progress, trigger = trigger),
      error = function(e)
        cli::cli_alert_warning("Redirection stable non mise à jour : {e$message}")
    )

    if (!is.null(final_url))
      cli::cli_alert_success("WP disponible après déploiement FTP : {.url {final_url}}")

    return(invisible(res))
  }

  # ---- Brouillon : GitHub Pages --------------------------------------------
  cli::cli_h2("Déploiement brouillon (quarto publish gh-pages)")

  if (!fs::dir_exists(fs::path(root, "_site")))
    cli::cli_alert_warning(
      "Pas de dossier {.path _site} — Quarto va le générer.")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  status <- system2(
    "quarto",
    args = c("publish", "gh-pages", "--no-prompt", "--no-browser")
  )

  if (!identical(status, 0L))
    cli::cli_abort("Échec de {.code quarto publish gh-pages} (code {status}).")

  cli::cli_alert_success("WP brouillon publié sur gh-pages.")
  if (!is.null(final_url))
    cli::cli_alert_success("Disponible : {.url {final_url}}")

  invisible(NULL)
}
