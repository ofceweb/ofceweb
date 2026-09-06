#' Déploie un policy brief (PB) OFCE
#'
#' Équivalent PB de [deploy_wp()]. Route le déploiement selon l'état du registre
#' (`stage` dans `manifest.json`) et, avant publication, selon `stage-target`
#' dans `_quarto.yml` (positionné par [setup_pb()]) :
#' \itemize{
#'   \item **Publié** (`stage: FALSE`) : toujours vers FTP production
#'     (`ftp_deploy.yml`), quelle que soit la valeur de `stage-target`.
#'   \item **Non encore publié** (`stage: TRUE` ou `stage` absent) : destination
#'     lue depuis `stage-target` (`"auto"` réévalué à chaque appel selon le
#'     propriétaire GitHub actuel — `"ftp"` pour l'organisation `ofce`,
#'     `"gh-pages"` sinon ; `"ftp"` ou `"gh-pages"` forcent la destination).
#' }
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Passé à [site2branch()]. Déclenche le workflow GitHub Actions
#'   FTP. Défaut `TRUE`.
#' @param full_deploy Passé à [site2branch()]. Défaut `FALSE`.
#' @param ... Arguments supplémentaires passés à [site2branch()].
#'
#' @returns Invisible `NULL`.
#' @seealso [render_pb()], [site2branch()], [pb_version_up()], [pb_registry_request()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_exists path_file
#' @importFrom cli cli_h2 cli_abort cli_alert_success cli_alert_warning cli_text cli_alert_info
#' @importFrom yaml read_yaml
#' @importFrom jsonlite read_json
#' @export
deploy_pb <- function(
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
      "Pas de {.file _quarto.yml} dans {.path {root}}. Lancer {.run ofceweb::setup_pb()}.")

  yml <- yaml::read_yaml(yml_path)

  # Manifeste écrit par render_pb() — source de vérité pour l'état registry
  manifest_path <- fs::path(root, "manifest.json")
  manifest <- if (fs::file_exists(manifest_path)) {
    tryCatch(jsonlite::read_json(manifest_path), error = function(e) NULL)
  } else {
    NULL
  }

  stage   <- manifest$stage
  pb      <- manifest$pb    %||% yml$pb
  version <- if (!is.null(yml$version)) as.character(yml$version) else NULL

  if (!fs::dir_exists(fs::path(root, "_site")))
    cli::cli_alert_warning(
      "Pas de dossier {.path _site} — lancer {.run ofceweb::render_pb()} d'abord.")

  # ---- Publié : FTP production (toujours, target ignoré) -------------------
  if (isFALSE(stage)) {
    stable_url <- sprintf("https://www.ofce.fr/pb/%d", pb)
    ver_seg    <- if (!is.null(version)) paste0(version, "/") else ""
    final_url  <- sprintf("https://www.ofce.fr/pb/%d/%s", pb, ver_seg)

    cli::cli_h2("Déploiement PB publié (site2branch → FTP production)")
    cli::cli_text(
      "PB {pb}{if (!is.null(version)) paste0(' / ', version) else ''} → {.url {stable_url}}")

    res <- site2branch(
      path        = root,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy,
      workflow    = "ftp_deploy.yml",
      ...
    )

    tryCatch(
      push_pb_redirect(root, progress = progress, trigger = trigger),
      error = function(e)
        cli::cli_alert_warning("Redirection stable non mise à jour : {e$message}")
    )

    cli::cli_alert_success(
      "PB disponible après déploiement FTP : {.url {final_url}}")
    return(invisible(res))
  }

  # ---- Détermination de la cible effective (non-publié) ---------------------
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

    cli::cli_h2("Déploiement PB staging (site2branch → FTP staging)")
    cli::cli_text(
      "{if (isTRUE(stage)) 'En attente d’enregistrement' else 'Brouillon'} \\
       {if (!is.null(version)) paste0('/ ', version, ' ') else ''}→ {.url {final_url}}")

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
      "PB staging disponible après déploiement FTP : {.url {final_url}}")
    return(invisible(res))
  }

  # ---- GitHub Pages ---------------------------------------------------------
  cli::cli_h2("Déploiement PB (quarto publish gh-pages)")

  if (isTRUE(stage))
    cli::cli_alert_info(
      "Dépôt en attente d’enregistrement — GitHub Pages forcé par {.code target = \"gh-pages\"}. \\
       Utiliser {.code target = \"ftp\"} pour déposer sur le staging FTP.")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  status <- system2(
    "quarto",
    args = c("publish", "gh-pages", "--no-prompt", "--no-browser")
  )

  if (!identical(status, 0L))
    cli::cli_abort("Échec de {.code quarto publish gh-pages} (code {status}).")

  cli::cli_alert_success("PB publié sur gh-pages.")

  gh        <- detect_gh_owner(root)
  repo_name <- if (is.na(gh$repo)) fs::path_file(root) else gh$repo
  gh_url <- if (!is.na(gh$org)) {
    sprintf("https://%s.github.io/%s/", gh$org, repo_name)
  } else {
    NULL
  }
  if (!is.null(gh_url) && nzchar(gh_url))
    cli::cli_alert_success(
      "Disponible : {.url {sub('/$', '', gh_url)}}")

  invisible(NULL)
}
