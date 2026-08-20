#' Détecte le type d'un dépôt et lance la bonne publication
#'
#' Inspecte le dépôt situé à `path` (via [detect_repo_type()], la même
#' détection que celle utilisée par [render()]) et appelle automatiquement
#' [publish_wp()], [publish_prev()], [publish_blog()] ou [stage_site()]
#' selon ce qui est détecté.
#'
#' La détection se fait, dans l'ordre :
#' \enumerate{
#'   \item `ofce_prev: true` dans `_quarto.yml` → prévision ([publish_prev()])
#'   \item `ofce_wp: true` dans `_quarto.yml` → document de travail ([publish_wp()])
#'   \item présence d'un dossier `posts/` → blog ([publish_blog()])
#'   \item présence d'un `_quarto.yml` (sans marqueur ci-dessus) → site
#'     générique ([stage_site()])
#' }
#' Si rien de tout cela n'est détecté, la fonction s'arrête avec un message
#' invitant à lancer [setup_wp()] ou [setup_site()].
#'
#' Pour un site générique, il n'existe pas de fonction `publish_site()`
#' dédiée : les sites génériques n'ont pas de distinction staging/publish
#' comme les prévisions, donc [stage_site()] (rendu + déploiement) en tient
#' lieu.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param type Force le type de dépôt (`"wp"`, `"site"`, `"prev"` ou
#'   `"blog"`) plutôt que de le détecter automatiquement. Défaut `NULL`
#'   (détection automatique).
#' @param ... Arguments supplémentaires transmis à la fonction de
#'   publication choisie ([publish_wp()], [publish_prev()],
#'   [publish_blog()] ou [stage_site()]). Ces fonctions n'ont pas toutes la
#'   même signature ; passer un argument non reconnu par la fonction cible
#'   provoquera une erreur R standard ("unused argument").
#'
#' @returns La valeur de retour de la fonction de publication appelée.
#' @seealso [publish_wp()], [publish_prev()], [publish_blog()],
#'   [stage_site()], [render()], [detect_repo_type()]
#' @export
publish <- function(path = ".", type = NULL, ...) {
  root <- fs::path_abs(path)
  detected <- type %||% detect_repo_type(root)

  target <- switch(
    detected,
    prev = list(fn = publish_prev, name = "publish_prev"),
    wp   = list(fn = publish_wp,   name = "publish_wp"),
    blog = list(fn = publish_blog, name = "publish_blog"),
    site = list(fn = stage_site,   name = "stage_site"),
    cli::cli_abort("Type de d\u00e9p\u00f4t inconnu : {.val {detected}}")
  )

  cli::cli_alert_info(
    "D\u00e9p\u00f4t d\u00e9tect\u00e9 comme {.strong {detected}} \u2014 appel de {.fn {target$name}}")

  target$fn(path = path, ...)
}
