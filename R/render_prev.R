#' Génère le site de la prévision
#'
#' Orchestre le rendu complet de la prévision
#' appel à [quarto::quarto_render()] avec le profil `publish`, puis optionnellement déploiement du répertoire
#' `_site_publish` vers une branche git et/ou prévisualisation locale via un serveur HTTP.
#'
#' @param path Chemin vers la racine du projet (dossier `prevxx[3|9]`). Par défaut
#'   `"."` (répertoire de travail courant).
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
#' @export
render_prev_publish <- function(
    path = ".",
    check_repo = TRUE,
    progress = TRUE,
    render_site = TRUE,
    site2branch = TRUE,
    trigger = site2branch) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  project <- fs::path_file(root)
  cli::cli_h1("repo {project}")

  if(!dir.exists(fs::path_join(c(root, "france"))) |
     !dir.exists(fs::path_join(c(root, "inter" ))) |
     !dir.exists(fs::path_join(c(root, "fiches"))) )  {
    cli::cli_abort("Le projet ne contient pas les dossiers france/inter/fiches")
  }

  if(!stringr::str_detect(project,"^prev[0-9]{2}0[39]")) {
    cli::cli_alert_danger(
      "Ce n'est pas un dépôt de prévision {.emph prev2x0x}, mais {.emph {project}}")
    answer <- readline("Etes vous sûr.e de vouloir continuer ? [o/N] ")
    if (!tolower(answer) %in% c("o", "oui"))
      cli::cli_abort("ABORT")
  }

  oldwd <- getwd()
  quarto_yml_path <- "_quarto.yml"
  quarto_yml_bak  <- "_quarto.yml.bak"

  on.exit({
    # fs::file_copy(quarto_yml_bak, quarto_yml_path, overwrite = TRUE)
    # fs::file_delete(quarto_yml_bak)
    setwd(oldwd)
  })

  setwd(root)

  if (check_repo)
    check_repo_status()

  tictoc::tic()

  cli::cli_h2("Génération du site {.emph publish} de {project}")

  quarto::quarto_render(
    profile="publish",
    as_job = FALSE)

  fs::dir_ls("_site_publish", recurse=TRUE, regexp = "DS_Store$",  type = "file", all = TRUE) |>
    fs::file_delete()

  tictoc::toc()

  if (site2branch)
    site2publish(
      progress = TRUE,
      trigger = trigger)
  else {
    cli::cli_text(
      "Pour publier _site_publish, lancer {.run ofceweb::site2publish(trigger = TRUE)}"
    )
  }

  if(render_site) {
    cli::cli_h2("Render du site {.emph publish}")
    servr::httw("_site_publish", daemon = TRUE)
  }

}
