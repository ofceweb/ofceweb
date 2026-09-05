#' Détecte le type d'un dépôt et lance le bon rendu
#'
#' Inspecte le dépôt situé à `path` (via [detect_repo_type()]) et appelle
#' automatiquement [render_wp()], [render_site()], [render_prev()] ou
#' [render_blog()] selon ce qui est détecté, plutôt que de devoir se
#' souvenir de la bonne fonction à utiliser.
#'
#' La détection se fait, dans l'ordre :
#' \enumerate{
#'   \item `ofce_prev: true` dans `_quarto.yml` → prévision (`render_prev()`)
#'   \item `ofce_wp: true` dans `_quarto.yml` → document de travail (`render_wp()`)
#'   \item `ofce_pb: true` dans `_quarto.yml` → policy brief (`render_pb()`)
#'   \item présence d'un dossier `posts/` → blog (`render_blog()`)
#'   \item présence d'un `_quarto.yml` (sans marqueur ci-dessus) → site
#'     générique (`render_site()`)
#' }
#' Si rien de tout cela n'est détecté, la fonction s'arrête avec un message
#' invitant à lancer [setup_wp()] ou [setup_site()].
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param type Force le type de dépôt (`"wp"`, `"site"`, `"prev"`, `"pb"` ou
#'   `"blog"`) plutôt que de le détecter automatiquement. Défaut `NULL`
#'   (détection automatique).
#' @param ... Arguments supplémentaires transmis à la fonction de rendu
#'   choisie ([render_wp()], [render_site()], [render_prev()], [render_pb()]
#'   ou [render_blog()]). Ces fonctions n'ont pas toutes la même signature ;
#'   passer un argument non reconnu par la fonction cible provoquera une
#'   erreur R standard ("unused argument").
#'
#' @returns La valeur de retour de la fonction de rendu appelée.
#' @seealso [render_wp()], [render_site()], [render_prev()], [render_pb()],
#'   [render_blog()], [detect_repo_type()]
#' @export
render <- function(path = ".", type = NULL, ...) {
  root <- fs::path_abs(path)
  detected <- type %||% detect_repo_type(root)

  fn <- switch(
    detected,
    prev = render_prev,
    wp   = render_wp,
    pb   = render_pb,
    blog = render_blog,
    site = render_site,
    cli::cli_abort("Type de d\u00e9p\u00f4t inconnu : {.val {detected}}")
  )

  cli::cli_alert_info(
    "D\u00e9p\u00f4t d\u00e9tect\u00e9 comme {.strong {detected}} \u2014 appel de {.fn {paste0('render_', detected)}}")

  fn(path = path, ...)
}

#' Détecte le type d'un dépôt OFCE
#'
#' Examine `_quarto.yml` et la structure du dossier `root` pour déterminer
#' s'il s'agit d'un document de travail (`"wp"`), d'une prévision
#' (`"prev"`), d'un policy brief (`"pb"`), d'un blog (`"blog"`) ou d'un site
#' générique (`"site"`). Utilisée par [render()] pour choisir automatiquement
#' la fonction de rendu à appeler.
#'
#' @param root Chemin vers la racine du dépôt (déjà résolu en chemin absolu).
#'
#' @returns Une chaîne : `"wp"`, `"prev"`, `"pb"`, `"blog"` ou `"site"`. Si
#'   aucun marqueur n'est trouvé, la fonction s'arrête avec [cli::cli_abort()].
#' @keywords internal
detect_repo_type <- function(root) {
  yml_path <- fs::path(root, "_quarto.yml")
  yml <- NULL
  if(fs::file_exists(yml_path))
    yml <- tryCatch(yaml::read_yaml(yml_path), error = function(e) NULL)

  is_wp   <- isTRUE(yml$ofce_wp)
  is_prev <- isTRUE(yml$ofce_prev)
  is_pb   <- isTRUE(yml$ofce_pb)

  if(sum(is_wp, is_prev, is_pb) > 1)
    cli::cli_abort(
      "{.file _quarto.yml} d\u00e9clare plus d'un marqueur parmi {.code ofce_wp}, {.code ofce_prev} et {.code ofce_pb} \u2014 configuration incoh\u00e9rente.")

  if(is_prev) return("prev")
  if(is_wp) return("wp")
  if(is_pb) return("pb")
  if(fs::dir_exists(fs::path(root, "posts"))) return("blog")
  if(!is.null(yml)) return("site")

  cli::cli_abort(c(
    "Aucun type de d\u00e9p\u00f4t reconnu dans {.path {root}}.",
    "i" = "Ce dossier ne semble pas encore initialis\u00e9.",
    "i" = "Lancez {.run ofceweb::setup_wp()} pour un document de travail, ou {.run ofceweb::setup_site()} pour un site g\u00e9n\u00e9rique."
  ))
}
