#' Déploie un document de travail (WP) OFCE
#'
#' Route le déploiement selon le champ `stage` du manifeste
#' (`manifest.json`, écrit par [render_wp()]) :
#' \itemize{
#'   \item **Brouillon initial** (pas de manifeste ou champ `stage` absent) :
#'     publie sur GitHub Pages via `quarto publish gh-pages`.
#'     État avant tout appel à [wp_registry_request()].
#'   \item **Staged** (`stage: true`) : pousse vers la branche `site-staging`
#'     et déclenche `ftp_stage.yml`, qui dépose dans
#'     `stage/wp/{repo}/{version}/` avec les secrets de staging (chroot `stage/`).
#'   \item **Publié** (`stage: false`) : pousse vers la branche `site-deploy`
#'     et déclenche `ftp_deploy.yml` vers
#'     `www.ofce.fr/wp/{annee}/{N}/{version}/`.
#' }
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Passé à [site2branch()] (WP staged ou publié uniquement).
#'   Déclenche le workflow GitHub Actions FTP. Défaut `TRUE`.
#' @param full_deploy Passé à [site2branch()]. Défaut `FALSE`.
#' @param ... Arguments supplémentaires passés à [site2branch()].
#'
#' @returns Invisible `NULL`.
#' @seealso [render_wp()], [site2branch()], [wp_version_up()], [wp_registry_request()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_exists path_file
#' @importFrom cli cli_h2 cli_abort cli_alert_success cli_alert_warning cli_text
#' @importFrom yaml read_yaml
#' @importFrom jsonlite read_json
#' @section Working Paper (WP) Users:
#'
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

  # Manifeste écrit par render_wp() — source de vérité pour l'état registry
  manifest_path <- fs::path(root, "manifest.json")
  manifest <- if (fs::file_exists(manifest_path)) {
    tryCatch(jsonlite::read_json(manifest_path), error = function(e) NULL)
  } else {
    NULL
  }

  # stage: FALSE = publié, TRUE = staging FTP, NULL = brouillon initial (GitHub Pages)
  stage   <- manifest$stage
  annee   <- manifest$annee   %||% yml$annee
  wp      <- manifest$wp      %||% yml$wp
  version <- if (!is.null(yml$version)) as.character(yml$version) else NULL

  if (!fs::dir_exists(fs::path(root, "_site")))
    cli::cli_alert_warning(
      "Pas de dossier {.path _site} — lancer {.run ofceweb::render_wp()} d'abord.")

  # ---- Publié : FTP production ---------------------------------------------
  if (isFALSE(stage)) {
    stable_url <- sprintf("https://www.ofce.fr/wp/%d/%03d", annee, wp)
    ver_seg    <- if (!is.null(version)) paste0(version, "/") else ""
    final_url  <- sprintf("https://www.ofce.fr/wp/%d/%03d/%sindex.html", annee, wp, ver_seg)

    cli::cli_h2("D\u00e9ploiement WP publi\u00e9 (site2branch \u2192 FTP production)")
    cli::cli_text(
      "WP {wp}/{annee}{if (!is.null(version)) paste0(' / ', version) else ''} \u2192 {.url {stable_url}}")

    res <- site2branch(
      path        = root,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy,
      workflow    = "ftp_deploy.yml",
      ...
    )

    tryCatch(
      push_wp_redirect(root, progress = progress, trigger = trigger),
      error = function(e)
        cli::cli_alert_warning("Redirection stable non mise \u00e0 jour : {e$message}")
    )

    cli::cli_alert_success(
      "WP disponible apr\u00e8s d\u00e9ploiement FTP : {.url {final_url}}")
    return(invisible(res))
  }

  # ---- Staged : FTP staging ------------------------------------------------
  if (isTRUE(stage)) {
    # Slug du dépôt : partie repo de source-repo (ex. "ofce/wp-2026-15-...") ou nom local
    source_repo <- manifest[["source-repo"]]
    repo_slug <- if (!is.null(source_repo) && nzchar(source_repo)) {
      basename(source_repo)
    } else {
      fs::path_file(root)
    }
    ver_seg   <- if (!is.null(version)) paste0(version, "/") else ""
    final_url <- sprintf(
      "https://www.ofce.fr/stage/wp/%s/%sindex.html", repo_slug, ver_seg)

    cli::cli_h2("D\u00e9ploiement WP staging (site2branch \u2192 FTP staging)")
    cli::cli_text(
      "En attente d'enregistrement{if (!is.null(version)) paste0(' / ', version) else ''} \u2192 {.url {final_url}}")

    res <- site2branch(
      path        = root,
      branch      = "site-staging",
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy,
      workflow    = "ftp_stage.yml",
      ...
    )

    cli::cli_alert_success(
      "WP staging disponible apr\u00e8s d\u00e9ploiement FTP : {.url {final_url}}")
    return(invisible(res))
  }

  # ---- Brouillon initial : GitHub Pages ------------------------------------
  # Aucun champ stage dans le manifeste = avant wp_registry_request()
  cli::cli_h2("D\u00e9ploiement brouillon initial (quarto publish gh-pages)")

  if (!is.null(manifest) && is.null(stage))
    cli::cli_text(
      "Manifeste pr\u00e9sent mais sans champ {.code stage} \u2014 ",
      "lancer {.run ofceweb::wp_registry_request()} pour demander un num\u00e9ro.")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  status <- system2(
    "quarto",
    args = c("publish", "gh-pages", "--no-prompt", "--no-browser")
  )

  if (!identical(status, 0L))
    cli::cli_abort("\u00c9chec de {.code quarto publish gh-pages} (code {status}).")

  cli::cli_alert_success("WP brouillon publi\u00e9 sur gh-pages.")

  gh_url <- yml$website$`site-url`
  if (!is.null(gh_url) && nzchar(gh_url))
    cli::cli_alert_success(
      "Disponible : {.url {paste0(sub('/?$', '/', gh_url), 'index.html')}}")

  invisible(NULL)
}
