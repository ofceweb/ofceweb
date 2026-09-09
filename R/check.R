#' Détecte le type d'un dépôt et lance le bon diagnostic
#'
#' Inspecte le dépôt situé à `path` (via [detect_repo_type()], la même
#' détection que [render()]/[publish()]/[deploy()]) et appelle
#' automatiquement la fonction de diagnostic interne correspondante.
#'
#' Un diagnostic par dépôt n'existe aujourd'hui que pour `wp`, `prev` et
#' `pb` : `check(type = "ife"|"home"|"site"|"blog")` (ou auto-détection dans
#' un de ces dépôts) échoue avec un message explicite plutôt que d'inventer
#' un diagnostic qui n'existe pas.
#'
#' Cas particulier de `blog` : il existe bien un diagnostic pour le blog
#' (`check_blog()`), mais il porte sur un **post** (un fichier `.qmd`), pas
#' sur la racine du dépôt — il ne correspond donc pas au contrat `path =
#' <racine du dépôt>` partagé par `check()`. Pour vérifier un post de blog,
#' utiliser [submit_blog()] (qui appelle `check_blog()` en interne), pas
#' `check()`.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param type Force le type de dépôt (`"wp"`, `"site"`, `"prev"`, `"pb"`,
#'   `"ife"`, `"home"` ou `"blog"`) plutôt que de le détecter automatiquement.
#'   Défaut `NULL` (détection automatique).
#' @param ... Arguments supplémentaires transmis à la fonction de diagnostic
#'   choisie (typiquement `verbose`).
#'
#' @returns La valeur de retour de la fonction de diagnostic appelée
#'   (généralement un data frame de diagnostics).
#' @seealso [render()], [publish()], [deploy()], [registry_request()],
#'   [submit_blog()], [detect_repo_type()]
#' @export
check <- function(path = ".", type = NULL, ...) {
  .ofce_dispatch("check", path, type, ...)
}
