#' Détecte le type d'un dépôt et lance le bon rendu
#'
#' Inspecte le dépôt situé à `path` (via [detect_repo_type()]) et appelle
#' automatiquement la fonction de rendu interne correspondante (WP, site
#' générique, prévision, policy brief, site IFE, homepage ou blog) selon ce
#' qui est détecté, plutôt que de devoir se souvenir de la bonne fonction à
#' utiliser.
#'
#' La détection se fait, dans l'ordre :
#' \enumerate{
#'   \item `ofce_prev: true` dans `_quarto.yml` → prévision
#'   \item `ofce_wp: true` dans `_quarto.yml` → document de travail
#'   \item `ofce_pb: true` dans `_quarto.yml` → policy brief
#'   \item `ofce_home: true` dans `_quarto.yml` → homepage OFCE
#'   \item `project: type: ife-website` dans `_quarto.yml` → site IFE
#'   \item présence d'un dossier `posts/` → blog ([render_blog()])
#'   \item présence d'un `_quarto.yml` (sans marqueur ci-dessus) → site
#'     générique
#' }
#' Si rien de tout cela n'est détecté, la fonction s'arrête avec un message
#' invitant à lancer [setup_wp()] ou [setup_site()].
#'
#' Pour `blog`/`ife`/`home`, le nom du dossier local est vérifié
#' (`webblog`/`ife_webhome`/`webhome` respectivement) : un dépôt mal nommé
#' provoque un arrêt explicite plutôt qu'un rendu silencieux au mauvais
#' endroit.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param type Force le type de dépôt (`"wp"`, `"site"`, `"prev"`, `"pb"`,
#'   `"ife"`, `"home"` ou `"blog"`) plutôt que de le détecter automatiquement.
#'   Défaut `NULL` (détection automatique).
#' @param ... Arguments supplémentaires transmis à la fonction de rendu
#'   choisie. Ces fonctions n'ont pas toutes la même signature ; passer un
#'   argument non reconnu par la fonction cible provoquera une erreur R
#'   standard ("unused argument").
#'
#' @returns La valeur de retour de la fonction de rendu appelée.
#' @seealso [publish()], [deploy()], [check()], [registry_request()],
#'   [render_blog()], [detect_repo_type()]
#' @export
render <- function(path = ".", type = NULL, ...) {
  .ofce_dispatch("render", path, type, ...)
}

#' Détecte le type d'un dépôt OFCE
#'
#' Examine `_quarto.yml` et la structure du dossier `root` pour déterminer
#' s'il s'agit d'un document de travail (`"wp"`), d'une prévision
#' (`"prev"`), d'un policy brief (`"pb"`), de la homepage OFCE (`"home"`),
#' du site IFE (`"ife"`), d'un blog (`"blog"`) ou d'un site générique
#' (`"site"`). Utilisée par [render()]/[publish()]/[deploy()]/[check()] pour
#' choisir automatiquement la fonction à appeler.
#'
#' @param root Chemin vers la racine du dépôt (déjà résolu en chemin absolu).
#'
#' @returns Une chaîne : `"wp"`, `"prev"`, `"pb"`, `"home"`, `"ife"`, `"blog"`
#'   ou `"site"`. Si aucun marqueur n'est trouvé, la fonction s'arrête avec
#'   [cli::cli_abort()].
#' @keywords internal
detect_repo_type <- function(root) {
  yml_path <- fs::path(root, "_quarto.yml")
  yml <- NULL
  if(fs::file_exists(yml_path))
    yml <- tryCatch(yaml::read_yaml(yml_path), error = function(e) NULL)

  is_wp   <- isTRUE(yml$ofce_wp)
  is_prev <- isTRUE(yml$ofce_prev)
  is_pb   <- isTRUE(yml$ofce_pb)
  is_home <- isTRUE(yml$ofce_home)
  is_ife  <- identical(yml$project$type, "ife-website")

  if(sum(is_wp, is_prev, is_pb, is_home) > 1)
    cli::cli_abort(
      "{.file _quarto.yml} d\u00e9clare plus d'un marqueur parmi {.code ofce_wp}, {.code ofce_prev}, {.code ofce_pb} et {.code ofce_home} \u2014 configuration incoh\u00e9rente.")

  if(is_prev) return("prev")
  if(is_wp) return("wp")
  if(is_pb) return("pb")
  if(is_home) return("home")
  if(is_ife) return("ife")
  if(fs::dir_exists(fs::path(root, "posts"))) return("blog")
  if(!is.null(yml)) return("site")

  cli::cli_abort(c(
    "Aucun type de d\u00e9p\u00f4t reconnu dans {.path {root}}.",
    "i" = "Ce dossier ne semble pas encore initialis\u00e9.",
    "i" = "Lancez {.run ofceweb::setup_wp()} pour un document de travail, ou {.run ofceweb::setup_site()} pour un site g\u00e9n\u00e9rique."
  ))
}
