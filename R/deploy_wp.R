#' Déploie un document de travail (WP) OFCE
#'
#' Route le déploiement selon l'\u00e9tat du registre (`stage` dans
#' `manifest.json`) et, avant publication, selon `stage-target` dans
#' `_quarto.yml` (positionn\u00e9 par [setup_wp()]) :
#' \itemize{
#'   \item **Publi\u00e9** (`stage: FALSE`) : toujours vers FTP production
#'     (`ftp_deploy.yml`), quelle que soit la valeur de `stage-target`.
#'   \item **Non encore publi\u00e9** (`stage: TRUE` ou `stage` absent) :
#'     destination lue depuis `stage-target` :
#'     \itemize{
#'       \item `"auto"` : r\u00e9\u00e9valu\u00e9 \u00e0 **chaque appel** de
#'         `deploy_wp()`, selon le propri\u00e9taire GitHub *actuel* du
#'         d\u00e9p\u00f4t -- `"ftp"` (staging OFCE, `ftp_stage.yml`, branche
#'         `site-staging`) pour l'organisation `ofce`, `"gh-pages"`
#'         (`quarto publish gh-pages`) sinon. `"auto"` est conserv\u00e9
#'         litt\u00e9ralement dans `_quarto.yml` par [setup_wp()] -- un
#'         transfert de propri\u00e9t\u00e9 du d\u00e9p\u00f4t vers (ou hors de)
#'         `ofce` change donc la destination d\u00e8s le prochain
#'         `deploy_wp()`, sans repasser par [setup_wp()].
#'       \item `"ftp"` : FTP staging (`ftp_stage.yml`, branche `site-staging`)
#'         ind\u00e9pendamment du propri\u00e9taire actuel du d\u00e9p\u00f4t.
#'       \item `"gh-pages"` : GitHub Pages (`quarto publish gh-pages`)
#'         ind\u00e9pendamment du propri\u00e9taire actuel du d\u00e9p\u00f4t.
#'     }
#' }
#'
#' @param path Chemin vers la racine du d\u00e9p\u00f4t. D\u00e9faut `"."`.
#' @param progress Logique. Affichage de la progression. D\u00e9faut `TRUE`.
#' @param trigger Pass\u00e9 \u00e0 [site2branch()] (WP staged ou publi\u00e9 uniquement).
#'   D\u00e9clenche le workflow GitHub Actions FTP. D\u00e9faut `TRUE`.
#' @param full_deploy Pass\u00e9 \u00e0 [site2branch()]. D\u00e9faut `FALSE`.
#' @param ... Arguments suppl\u00e9mentaires pass\u00e9s \u00e0 [site2branch()].
#'
#' @returns Invisible `NULL`.
#' @seealso [render_wp()], [site2branch()], [wp_version_up()], [wp_registry_request()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_exists path_file
#' @importFrom cli cli_h2 cli_abort cli_alert_success cli_alert_warning cli_text cli_alert_info
#' @importFrom yaml read_yaml
#' @importFrom jsonlite read_json
#' @section Working Paper (WP) Users:
#'
#' @export
deploy_wp <- function(
    path        = ".",
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

  # Manifeste \u00e9crit par render_wp() \u2014 source de v\u00e9rit\u00e9 pour l'\u00e9tat registry
  manifest_path <- fs::path(root, "manifest.json")
  manifest <- if (fs::file_exists(manifest_path)) {
    tryCatch(jsonlite::read_json(manifest_path), error = function(e) NULL)
  } else {
    NULL
  }

  stage   <- manifest$stage
  annee   <- manifest$annee %||% yml$annee
  wp      <- manifest$wp    %||% yml$wp
  version <- if (!is.null(yml$version)) as.character(yml$version) else NULL

  if (!fs::dir_exists(fs::path(root, "_site")))
    cli::cli_alert_warning(
      "Pas de dossier {.path _site} \u2014 lancer {.run ofceweb::render_wp()} d'abord.")

  # ---- Publi\u00e9 : FTP production (tou jours, target ignor\u00e9) -------------------
  if (isFALSE(stage)) {
    stable_url <- sprintf("https://www.ofce.fr/wp/%d/%03d", annee, wp)
    ver_seg    <- if (!is.null(version)) paste0(version, "/") else ""
    final_url  <- sprintf("https://www.ofce.fr/wp/%d/%d/%s", annee, wp, ver_seg)

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

  # ---- D\u00e9termination de la cible effective (non-publi\u00e9) ---------------------
  # Source de v\u00e9rit\u00e9 : stage-target dans _quarto.yml. Peut valoir "auto"
  # (pr\u00e9serv\u00e9 litt\u00e9ralement par setup_wp()) -- il est alors r\u00e9\u00e9valu\u00e9 ici,
  # \u00e0 chaque d\u00e9ploiement, selon le propri\u00e9taire GitHub *actuel* du d\u00e9p\u00f4t
  # (detect_gh_owner(), partag\u00e9 avec setup_wp()) : "ftp" pour l'organisation
  # ofce, "gh-pages" sinon. Cela permet \u00e0 un transfert de propri\u00e9t\u00e9 vers
  # ofce de changer la destination sans repasser par setup_wp().
  # Ignor\u00e9 si le WP est confirm\u00e9 dans le registre (stage = FALSE, ci-dessus).
  raw_target <- yml[["stage-target"]] %||% "auto"
  effective_target <- resolve_stage_target(raw_target, org = detect_gh_owner(root)$org)

  # ---- FTP staging ----------------------------------------------------------
  if (effective_target == "ftp") {
    source_repo <- manifest[["source-repo"]]
    repo_slug <- if (!is.null(source_repo) && nzchar(source_repo)) {
      basename(source_repo)
    } else {
      fs::path_file(root)
    }
    ver_seg   <- if (!is.null(version)) paste0(version, "/") else ""
    final_url <- sprintf("https://staging.ofce.fr/%s/%s", repo_slug, ver_seg)

    cli::cli_h2("D\u00e9ploiement WP staging (site2branch \u2192 FTP staging)")
    cli::cli_text(
      "{if (isTRUE(stage)) 'En attente d\u2019enregistrement' else 'Brouillon'} \\
       {if (!is.null(version)) paste0('/ ', version, ' ') else ''}\u2192 {.url {final_url}}")

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

  # ---- GitHub Pages ---------------------------------------------------------
  cli::cli_h2("D\u00e9ploiement WP (quarto publish gh-pages)")

  if (isTRUE(stage))
    cli::cli_alert_info(
      "D\u00e9p\u00f4t en attente d\u2019enregistrement \u2014 GitHub Pages forc\u00e9 par {.code target = \"gh-pages\"}. \\
       Utiliser {.code target = \"ftp\"} pour d\u00e9poser sur le staging FTP.")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  status <- system2(
    "quarto",
    args = c("publish", "gh-pages", "--no-prompt", "--no-browser")
  )

  if (!identical(status, 0L))
    cli::cli_abort("\u00c9chec de {.code quarto publish gh-pages} (code {status}).")

  cli::cli_alert_success("WP publi\u00e9 sur gh-pages.")

  gh_url <- yml$website$`site-url`
  if (!is.null(gh_url) && nzchar(gh_url))
    cli::cli_alert_success(
      "Disponible : {.url {sub('/$', '', gh_url)}}")

  invisible(NULL)
}
