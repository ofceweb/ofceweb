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

  if(project != "webhome") {
    cli::cli_alert_danger(
      "Ce n'est pas le repo {.emph webhome}, mais {.emph {project}}")
    answer <- readline("Etes vous sûr.e de vouloir continuer ? [o/N] ")
    if (!tolower(answer) %in% c("o", "oui"))
      cli::cli_abort("ABORT")
  }
  oldwd <- getwd()
  quarto_yml_path <- "_quarto.yml"
  quarto_yml_bak  <- "_quarto.yml.bak"

  on.exit({
    fs::file_copy(quarto_yml_bak, quarto_yml_path, overwrite = TRUE)
    fs::file_delete(quarto_yml_bak)
    setwd(oldwd)
  })
  setwd(root)

  if (check_repo)
    check_repo_status()

  cli::cli_h2("Génération de la homepage")

  # Backup _quarto.yml and strip pre/post-render hooks
  fs::file_copy(quarto_yml_path, quarto_yml_bak, overwrite = TRUE)

  qyaml <- get_yaml(quarto_yml_path)
  pre_render_scripts  <- qyaml$project[["pre-render"]]  %||% character(0)
  post_render_scripts <- qyaml$project[["post-render"]] %||% character(0)
  qyaml$project[["pre-render"]]  <- NULL
  qyaml$project[["post-render"]] <- NULL
  put_yaml(qyaml, quarto_yml_path)

  cli::cli_h3("Pre-render")
  run_render_scripts(pre_render_scripts)

  tictoc::tic()
  quarto::quarto_render(as_job = FALSE, quiet = !progress)
  tictoc::toc()

  cli::cli_h3("Post-render")
  run_render_scripts(post_render_scripts)

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

run_render_scripts <- function(scripts) {
  for (cmd in scripts) {
    if (grepl("^Rscript\\s+", cmd)) {
      script_path <- sub("^Rscript\\s+", "", cmd)
      cli::cli_alert_info("Sourcing {script_path}")
      source(script_path, local = FALSE)
    } else {
      cli::cli_alert_info("Running: {cmd}")
      system(cmd)
    }
  }
}
