#' Détecte le type d'un dépôt et lance la bonne demande d'enregistrement
#'
#' Inspecte le dépôt situé à `path` (via [detect_repo_type()], la même
#' détection que [render()]/[publish()]/[deploy()]/[check()]) et appelle
#' automatiquement la fonction de demande de registre interne
#' correspondante.
#'
#' Seuls `wp` et `pb` ont un registre central (`ofce/wp-registry`)
#' aujourd'hui : `registry_request(type = "prev"|"ife"|"home"|"blog"|"site")`
#' (ou auto-détection dans l'un de ces dépôts) échoue avec un message
#' explicite plutôt que de tenter un accès réseau inadapté. Ajouter un futur
#' registre pour un autre type se fait en complétant la colonne `registry`
#' de la table de dispatch interne (`.ofce_repo_types()`), pas en ajoutant
#' une nouvelle fonction exportée.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param type Force le type de dépôt (`"wp"` ou `"pb"`, les deux seuls types
#'   avec un registre aujourd'hui) plutôt que de le détecter automatiquement.
#'   Défaut `NULL` (détection automatique).
#' @param ... Arguments supplémentaires transmis à la fonction de demande de
#'   registre choisie.
#'
#' @returns La valeur de retour de la fonction de registre appelée.
#' @seealso [render()], [publish()], [deploy()], [check()],
#'   [detect_repo_type()]
#' @export
registry_request <- function(path = ".", type = NULL, ...) {
  root <- fs::path_abs(path)
  detected <- type %||% detect_repo_type(root)
  validate_repo_name(detected, root)

  entry <- .ofce_repo_types()[[detected]]
  if (is.null(entry))
    cli::cli_abort("Type de d\u00e9p\u00f4t inconnu : {.val {detected}}")

  if (is.null(entry$registry))
    cli::cli_abort(c(
      "Le type {.val {detected}} n'a pas de registre central.",
      "i" = "Seuls {.val wp} et {.val pb} utilisent {.fn registry_request} aujourd'hui."
    ))

  cli::cli_alert_info(
    "D\u00e9p\u00f4t d\u00e9tect\u00e9 comme {.strong {detected}} \u2014 registry_request")

  entry$registry(path = path, ...)
}
