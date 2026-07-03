#' Prévisualise le document `.qmd` actif dans RStudio
#'
#' Récupère le chemin du document actif dans l'éditeur RStudio, vérifie qu'il
#' s'agit d'un fichier `.qmd`, le rend via [quarto::quarto_render()] puis
#' lance un serveur HTTP local avec [servr::httd()] positionné directement sur
#' le fichier HTML produit.
#'
#' Le répertoire servi et le chemin initial sont déduits automatiquement via
#' [quarto::quarto_inspect()] :
#' \enumerate{
#'   \item `quarto inspect` est appelé sur le fichier avec le `profile` actif ;
#'     il retourne la racine du projet (`$project$dir`) et le `output-dir`
#'     résolu (`$project$config$project[["output-dir"]]`).
#'   \item Si `quarto inspect` échoue (ex. type de projet non reconnu par
#'     l'installation locale), on bascule sur la lecture manuelle de
#'     `_quarto.yml` et `_quarto-{profile}.yml`.
#'   \item Sans projet détecté ou sans `output-dir` configuré, le serveur
#'     pointe sur le dossier du `.qmd` lui-même.
#' }
#'
#' @param profile `[character(1)]` ou `NULL`.\cr
#'   Profil Quarto à utiliser pour le rendu (ex. `"staging"`, `"publish"`).
#'   Passé à [quarto::quarto_render()] et utilisé pour lire le bon
#'   `_quarto-{profile}.yml`. `NULL` (défaut) = rendu sans profil.
#' @param daemon Logique. Si `TRUE` (défaut), le serveur HTTP tourne en
#'   arrière-plan sans bloquer la console.
#' @param ... Arguments supplémentaires passés à [quarto::quarto_render()].
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @importFrom fs path_ext path_ext_set path_dir path_file path_norm path_abs path_rel
#' @importFrom cli cli_abort cli_h1 cli_h2 cli_alert_success cli_alert_info cli_alert_warning
#' @importFrom quarto quarto_render quarto_inspect
#' @importFrom servr daemon_stop httd
#' @importFrom yaml read_yaml
#' @section Prévision Users:
#'
#' @export
preview_qmd <- function(profile = NULL,
                        daemon = TRUE,
                        use_freezer = FALSE,
                        as_job = FALSE,
                        ...) {

  oldwd <- getwd()
  on.exit(setwd(oldwd))

  if (!rstudioapi::isAvailable())
    cli::cli_abort(
      "{.fn preview_qmd} requiert RStudio (rstudioapi non disponible).")

  ctx  <- rstudioapi::getSourceEditorContext()

  project <- rstudioapi::getActiveProject() |> fs::path_file()
  setwd(project)

  if(is.null(project))
    cli::cli_abort("{.fn preview_qmd} requiet un project RStudio ouvert")

  path <- ctx$path |> stringr::str_extract(".+/{project}/(.+)" |> glue::glue(), group = 1)

  if (!nzchar(path))
    cli::cli_abort(
      "Aucun fichier sauvegardé n'est ouvert dans RStudio. \\
       Enregistrer le document avant de lancer {.fn preview_qmd}.")

  if (!identical(tolower(fs::path_ext(path)), "qmd"))
    cli::cli_abort(
      "Le document actif ({.file {fs::path_file(path)}}) n'est pas un \\
       fichier {.code .qmd}.")

  qmd_abs  <- fs::path_norm(fs::path_abs(path))
  qmd_name <- fs::path_file(qmd_abs)

  cli::cli_h1("preview_qmd : {qmd_name}")

  # ---- Détection du répertoire de sortie via quarto_inspect ----------------
  html_rel <- fs::path_ext_set(qmd_name, "html")  # fallback (fichier seul)
  root <- output_dir <- render_dir <- NULL

  # quarto_inspect est la source autoritaire : il tient compte du profil et
  # des extensions de projet. On bascule sur l'analyse manuelle des YAML si
  # la commande échoue (ex. type de projet inconnu de l'installation locale).
  inspect <- tryCatch(
    quarto::quarto_inspect(input = qmd_abs, profile = profile, quiet = TRUE),
    error = function(e) {
      cli::cli_alert_warning(
        "quarto inspect a échoué ({conditionMessage(e)}). \\
         Repli sur la lecture des fichiers YAML.")
      NULL
    }
  )

  if (!is.null(inspect) && !is.null(inspect$project)) {
    root           <- inspect$project$dir |> fs::path_norm()
    output_dir_rel <- inspect$project$config$project[["output-dir"]] |> fs::path_norm()
    if (!is.null(output_dir_rel))
      output_dir <- fs::path_join(c(root, output_dir_rel)) |> as.character()
  } else {
    # Repli : remontée de l'arborescence + lecture manuelle des YAML
    root <- tryCatch(
      rprojroot::find_root(rprojroot::is_quarto_project),
      error = function(e) {
        cli::cli_abort("ce n'est pas un projet quarto ({conditionMessage(e)}).")
      }
    )
    if (!is.null(root))
      output_dir <- .detect_output_dir(root, profile)
  }

  if (!is.null(output_dir)) {
    render_dir <- output_dir
    # Chemin HTML relatif à output_dir = chemin du .qmd relatif à la racine,
    # avec l'extension .html
    qmd_rel  <- fs::path_rel(qmd_abs |> fs::path_expand(), root) |> as.character()
    html_rel <- fs::path_ext_set(qmd_rel, "html") |> as.character()
    cli::cli_alert_info(
      "Projet Quarto détecté ({.path {fs::path_file(root)}}), \\
       sortie : {.path {fs::path_file(output_dir)}/}")
  } else if (!is.null(root)) {
    render_dir <- fs::path_dir(qmd_abs)
    cli::cli_alert_info(
      "Projet Quarto détecté — pas d'output-dir configuré, \\
       rendu dans le dossier du fichier.")
  } else {
    render_dir <- fs::path_dir(qmd_abs)
    cli::cli_alert_info("Aucun projet Quarto détecté — rendu dans le dossier du fichier.")
  }

  # ---- Rendu ----------------------------------------------------------------
  cli::cli_h2("Rendu Quarto{if (!is.null(profile)) paste0(' [', profile, ']') else ''}")
  render_args <- list(input = qmd_abs, as_job = as_job, use_freezer = use_freezer, ...)
  if (!is.null(profile)) render_args$profile <- profile
  do.call(quarto::quarto_render, render_args)

  # ---- Prévisualisation -----------------------------------------------------
  cli::cli_h2("Prévisualisation locale")
  servr::daemon_stop()
  servr::httd(output_dir, initpath = html_rel, daemon = daemon)

  cli::cli_alert_success(
    "Serveur lancé \u2192 {.path {fs::path_file(render_dir)}/{html_rel}}")

  invisible(NULL)
}


#' @describeIn preview_qmd Raccourci pour `preview_qmd(profile = "staging")`.
#'   Lance la prévisualisation du document `.qmd` actif avec le profil Quarto
#'   `"staging"`, sans autre paramètre à préciser.
#' @export
preview_qmd_staging <- function(daemon = TRUE, ...) {
  preview_qmd(profile = "staging", daemon = daemon, ...)
}


# Remonte l'arborescence depuis le dossier du fichier à la recherche d'un
# _quarto.yml. Renvoie le chemin absolu de la racine ou NULL si introuvable.
.find_quarto_root <- function(file_path) {
  dir <- fs::path_dir(file_path)
  repeat {
    if (fs::file_exists(fs::path(dir, "_quarto.yml"))) return(dir)
    parent <- fs::path_dir(dir)
    if (identical(as.character(parent), as.character(dir))) return(NULL)
    dir <- parent
  }
}


# Lit project.output-dir dans _quarto.yml puis (si profile non-NULL) dans
# _quarto-{profile}.yml. Le profil a priorité. Renvoie le chemin absolu ou NULL.
.detect_output_dir <- function(root, profile = NULL) {
  base_yml <- tryCatch(
    yaml::read_yaml(fs::path(root, "_quarto.yml")),
    error = function(e) list()
  )
  output_dir <- base_yml$project$`output-dir`

  if (!is.null(profile)) {
    profile_path <- fs::path(root, paste0("_quarto-", profile, ".yml"))
    if (fs::file_exists(profile_path)) {
      profile_yml <- tryCatch(
        yaml::read_yaml(profile_path),
        error = function(e) list()
      )
      if (!is.null(profile_yml$project$`output-dir`))
        output_dir <- profile_yml$project$`output-dir`
    }
  }

  if (is.null(output_dir)) return(NULL)
  fs::path_norm(fs::path_abs(fs::path(root, output_dir)))
}
