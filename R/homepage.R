#' Génère la homepage
#'
#' @returns
#' @export
#'
#' @examples
#'
render_home <- function(
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
  project <- fs::path_file(root)
  cli::cli_h1("repo {project}")

  if(!dir.exists(fs::path_join(c(root, "ofce")))) {
    cli::cli_abort("Le projet ne contient pas de dossier ofce")
  }

  project <- fs::path_file(root) |> as.character()
  cli::cli_h1("repo {project}")
  if(project != "webhome") {
    cli::cli_alert_danger(
      "Ce n'est pas le repo {.emph webhome}, mais {.emph {project}}")
    answer <- readline("Etes vous sûr.e de vouloir continuer ? [o/N] ")
    if (!tolower(answer) %in% c("o", "oui"))
      cli::cli_abort("ABORT")
  }
  oldwd <- getwd()
  on.exit({
    setwd(oldwd)
  }
  )
  setwd(root)

  if (check_repo)
    check_repo_status()

  cli::cli_h2("Génération de la homepage")

  tictoc::tic()
  quarto::quarto_render(as_job = FALSE, quiet = !progress)
  tictoc::toc()

  if(site2branch) {
    site2branch(
      root = ".",
      branch = "site-deploy",
      source = "_site",
      progress = progress,
      trigger=trigger)
  } else {
    cli::cli_text(
      "Pour publier _site, lancer {.run ofceweb::site2branch()} dans le même répertoire"
    )
  }

  if(render_site) {
    cli::cli_h2("Render du site")
    servr::httw("_site", daemon = TRUE)
  }

}
