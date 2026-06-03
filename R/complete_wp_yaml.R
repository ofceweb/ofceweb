#' Complète les champs manquants dans `_quarto.yml` pour un WP
#'
#' Remplit les champs obligatoires dans le `_quarto.yml` d'un WP (comme vérifiés par
#' `check_wp()`) en utilisant des valeurs par défaut raisonnables. Cette fonction n'est
#' **jamais destructive** : elle ne modifie aucun champ existant et ne crée que les
#' champs qui manquent.
#'
#' Champs complétés si absents :
#' \itemize{
#'   \item `date` : utilise la date du jour (format `YYYY-MM-DD`)
#'   \item `annee` : extrait depuis `date` ou utilise l'année courante
#'   \item `author` : structure minimale si `author` et `authors` sont tous deux absents
#'   \item `citation` : structure minimale (`type: article-journal`, `container-title` standard)
#'   \item `ofce_wp` : positionné à `TRUE` pour signaler un WP OFCE
#' }
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param verbose Logique. Si `TRUE` (défaut), affiche les champs ajoutés avec [cli::cli_alert_info()].
#'
#' @returns Invisible. Modifie le fichier `_quarto.yml` sur disque.
#'
#' @seealso [check_wp()], [setup_wp()]
#'
#' @importFrom fs path_expand path_abs path_norm path
#' @importFrom yaml read_yaml
#' @importFrom cli cli_h1 cli_alert_info cli_rule
#' @export
complete_wp <- function(path = ".", verbose = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")

  # Vérifier que le fichier existe
  if (!fs::file_exists(yml_path)) {
    if (verbose) {
      cli::cli_alert_danger(
        "Fichier {.path _quarto.yml} absent. Lancer {.fn setup_wp()} d'abord.")
    }
    return(invisible(NULL))
  }

  # Lire le YAML existant
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
    # Essayer d'extraire depuis la date s'il y en a une
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
  # Ne remplir que si ni `author` ni `authors` ne sont présents
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
      `container-title` = "Document de travail de l'OFCE"
    )
    completed_fields <- c(completed_fields, "citation")
  }

  # ---- ofce_wp ----
  if (is.null(yml$ofce_wp)) {
    yml$ofce_wp <- TRUE
    completed_fields <- c(completed_fields, "ofce_wp")
  }

  # Écrire le YAML mis à jour
  put_yaml(yml, yml_path)

  if (verbose) {
    cli::cli_h1("complete_wp : {fs::path_file(root)}")
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
