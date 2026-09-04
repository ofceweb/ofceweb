#' Complète les champs manquants dans `_quarto.yml` pour un PB
#'
#' Équivalent PB de `complete_wp()`. Remplit les champs obligatoires dans le
#' `_quarto.yml` d'un PB (comme vérifiés par [check_pb()]) en utilisant des
#' valeurs par défaut raisonnables. Cette fonction n'est **jamais destructive** :
#' elle ne modifie aucun champ existant et ne crée que les champs qui manquent.
#'
#' Champs complétés si absents :
#' \itemize{
#'   \item `date` : date du jour (format `YYYY-MM-DD`)
#'   \item `annee` : extraite depuis `date` ou année courante
#'   \item `author` : structure minimale si `author` et `authors` sont absents
#'   \item `citation` : structure minimale (`type: article-journal`,
#'     `container-title: "Policy Brief de l'OFCE"`)
#'   \item `ofce_pb` : positionné à `TRUE` pour signaler un PB OFCE
#' }
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param verbose Logique. Si `TRUE` (défaut), affiche les champs ajoutés.
#'
#' @returns Invisible. Modifie le fichier `_quarto.yml` sur disque.
#' @seealso [check_pb()], [setup_pb()]
#' @importFrom fs path_expand path_abs path_norm path
#' @importFrom yaml read_yaml
#' @importFrom cli cli_h1 cli_alert_info cli_rule
#' @keywords internal
complete_pb_yaml <- function(path = ".", verbose = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")

  if (!fs::file_exists(yml_path)) {
    if (verbose) {
      cli::cli_alert_danger(
        "Fichier {.path _quarto.yml} absent. Lancer {.fn setup_pb} d'abord.")
    }
    return(invisible(NULL))
  }

  yml <- tryCatch(
    yaml::read_yaml(yml_path),
    error = function(e) {
      if (verbose) {
        cli::cli_alert_danger(
          "Impossible de lire {.path _quarto.yml} : {conditionMessage(e)}")
      }
      NULL
    }
  )

  if (is.null(yml)) {
    return(invisible(NULL))
  }

  completed_fields <- character()

  # ---- date ----
  if (is.null(yml$date)) {
    yml$date <- format(Sys.Date(), "%Y-%m-%d")
    completed_fields <- c(completed_fields, "date")
  }

  # ---- annee ----
  if (is.null(yml$annee)) {
    if (!is.null(yml$date)) {
      annee_from_date <- suppressWarnings(
        as.integer(substr(as.character(yml$date), 1, 4))
      )
      if (!is.na(annee_from_date) && annee_from_date > 1990) {
        yml$annee <- annee_from_date
      } else {
        yml$annee <- as.integer(format(Sys.Date(), "%Y"))
      }
    } else {
      yml$annee <- as.integer(format(Sys.Date(), "%Y"))
    }
    completed_fields <- c(completed_fields, "annee")
  }

  # ---- author ----
  if (is.null(yml$author) && is.null(yml$authors)) {
    yml$author <- list(
      list(
        name = "Auteur",
        affiliation = "OFCE, Sciences Po Paris",
        `affiliation-url` = "https://www.ofce.fr"
      )
    )
    completed_fields <- c(completed_fields, "author")
  }

  # ---- citation ----
  if (is.null(yml$citation)) {
    yml$citation <- list(
      type = "article-journal",
      `container-title` = "Policy Brief de l'OFCE"
    )
    completed_fields <- c(completed_fields, "citation")
  }

  # ---- ofce_pb ----
  if (is.null(yml$ofce_pb)) {
    yml$ofce_pb <- TRUE
    completed_fields <- c(completed_fields, "ofce_pb")
  }

  put_yaml(yml, yml_path)

  if (verbose) {
    cli::cli_h1("complete_pb_yaml : {fs::path_file(root)}")
    if (length(completed_fields) > 0) {
      cli::cli_alert_info("Champs ajoutés : {.field {completed_fields}}")
      cli::cli_rule()
      cli::cli_alert_info(
        "Veuillez éditer {.path _quarto.yml} pour renseigner les valeurs définitives.")
    } else {
      cli::cli_alert_info("Aucun champ manquant détecté.")
    }
  }

  invisible(NULL)
}
