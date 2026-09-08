#' Rendu du site IFE (ife_webhome)
#'
#' Orchestre le rendu du site one-page de l'IFE : vérification du dépôt git,
#' vérification que `_quarto.yml` déclare bien `project: type: ife-website`,
#' nettoyage de `_site/`, rendu via [quarto::quarto_render()] (le script
#' `scripts/sitemap.R` tourne automatiquement en post-render, déjà déclaré
#' dans `_quarto.yml`), puis optionnellement déploiement du répertoire
#' `_site` vers une branche git et/ou prévisualisation locale via un serveur
#' HTTP.
#'
#' Contrairement à [render_site()], cette fonction ne reconstruit pas le
#' sitemap elle-même : le projet `ife-website` s'appuie sur son propre
#' `scripts/sitemap.R`, déjà déclaré en `post-render` dans `_quarto.yml`.
#'
#' @param path Chemin vers la racine du projet (dossier `ife_webhome`). Par
#'   défaut `"."` (répertoire de travail courant).
#' @param check_repo Logique. Si `TRUE` (défaut), vérifie l'état du dépôt git
#'   avant le rendu via [check_repo_status()].
#' @param progress Logique. Si `TRUE` (défaut), affiche la progression lors du
#'   rendu Quarto et du déploiement.
#' @param render_site Logique. Si `TRUE` (défaut), lance un serveur HTTP local
#'   ([servr::httw()]) sur `_site` après le rendu pour prévisualiser le résultat.
#' @param site2branch Logique. Si `TRUE`, appelle [site2branch()] pour pousser
#'   `_site` vers la branche git `site-deploy`. Par défaut `FALSE`.
#' @param trigger Valeur passée à l'argument `trigger` de [site2branch()].
#'   Par défaut égale à `site2branch`.
#'
#' @returns Appelée pour ses effets de bord. Retourne invisiblement `NULL`.
#' @seealso [publish_ife()], [site2branch()], [render_site()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists dir_delete
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_alert_danger cli_text
#' @importFrom tictoc tic toc
#' @importFrom servr daemon_stop httw
#' @importFrom quarto quarto_render
#' @export
render_ife <- function(
    path = ".",
    check_repo = TRUE,
    progress = TRUE,
    render_site = TRUE,
    site2branch = FALSE,
    trigger = site2branch) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  project <- fs::path_file(root) |> as.character()
  cli::cli_h1("repo {project}")

  yml_path <- fs::path(root, "_quarto.yml")
  if(!fs::file_exists(yml_path))
    cli::cli_abort(
      "Pas de {.file _quarto.yml} dans {.path {root}}.")

  yml <- yaml::read_yaml(yml_path)
  if(!identical(yml$project$type, "ife-website"))
    cli::cli_abort(c(
      "{.file _quarto.yml} ne d\u00e9clare pas {.code project: type: ife-website}.",
      "i" = "Ce dossier ne semble pas \u00eatre le d\u00e9p\u00f4t {.emph ife_webhome}."
    ))

  if(project != "ife_webhome") {
    cli::cli_alert_danger(
      "Ce n'est pas le repo {.emph ife_webhome}, mais {.emph {project}}")
    answer <- readline("Etes vous s\u00fbr.e de vouloir continuer ? [o/N] ")
    if(!tolower(answer) %in% c("o", "oui"))
      cli::cli_abort("ABORT")
  }

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  if(check_repo)
    check_repo_status()

  cli::cli_h2("Rendu Quarto")

  servr::daemon_stop()

  if(fs::dir_exists("_site"))
    tryCatch(
      fs::dir_delete("_site"),
      error = function(e) { Sys.sleep(1); fs::dir_delete("_site") }
    )

  tictoc::tic()
  quarto::quarto_render(as_job = FALSE, quiet = !progress)
  tictoc::toc()

  if(site2branch) {
    site2branch(
      path = ".",
      branch = "site-deploy",
      source = "_site",
      progress = progress,
      trigger = trigger)
  } else {
    cli::cli_text(
      "Pour publier _site, lancer {.run ofceweb::site2branch()} dans le m\u00eame r\u00e9pertoire")
  }

  if(render_site) {
    cli::cli_h2("Pr\u00e9visualisation du site")
    servr::httw("_site", daemon = TRUE)
  }

  invisible(NULL)
}

#' Publie le site IFE (ife_webhome)
#'
#' Wrapper de convenance autour de [render_ife()] qui positionne
#' `site2branch = TRUE` pour déployer automatiquement `_site` vers la branche
#' git `site-deploy` après le rendu (le workflow `ftp_deploy.yml` prend le
#' relais côté FTP OVH).
#'
#' @inheritParams render_ife
#' @returns Appelée pour ses effets de bord. Retourne invisiblement `NULL`.
#' @seealso [render_ife()], [site2branch()]
#' @export
#'
#' @examples
#' \dontrun{
#' publish_ife()
#' }
publish_ife <- function(
    path = ".",
    check_repo = TRUE,
    progress = TRUE,
    render_site = FALSE,
    trigger = TRUE) {
  render_ife(
    path = path,
    check_repo = check_repo,
    progress = progress,
    render_site = render_site,
    site2branch = TRUE,
    trigger = trigger
  )
}
