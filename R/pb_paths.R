#' Paramètres d'une série PB
#'
#' Extrait de l'index des séries ([fetch_pb_series_index()]) les paramètres
#' de la série `series`. Aucune série n'est codée en dur dans ofceweb : tout
#' vient de `pb/index.json` dans le registre central.
#'
#' @param series Identifiant de série (voir [pb_series()]).
#' @param index Index des séries, ou `NULL` (registre inaccessible).
#' @return Liste `list(label, path_prefix, pdf_prefix, draft_prefix,
#'   container_title)`, ou `NULL` si l'index est absent ou ne connaît pas la
#'   série.
#' @keywords internal
#' @noRd
pb_series_params <- function(series, index) {
  p <- if (!is.null(index)) index[[series]] else NULL
  if (is.null(p)) return(NULL)
  list(
    label           = p[["label"]] %||% series,
    path_prefix     = p[["path-prefix"]] %||% "",
    pdf_prefix      = p[["pdf-prefix"]],
    draft_prefix    = p[["draft-prefix"]],
    container_title = p[["container-title"]]
  )
}

#' `site-path` d'un PB publié
#'
#' Un PB publié n'est plus versionné : son `site-path` est
#' `{path-prefix}{pb}` (ex. `"ife/12"`, ou `"158"` pour une série sans
#' préfixe), relatif à `www.ofce.fr/pb/`. Seuls les brouillons (sans numéro)
#' portent une version, dans leur URL de staging.
#'
#' @param params Paramètres de série ([pb_series_params()]).
#' @param pb Numéro du PB dans sa série.
#' @return Chaîne.
#' @keywords internal
#' @noRd
pb_site_path <- function(params, pb) {
  paste0(params$path_prefix, as.integer(pb))
}

#' URL publique d'un PB publié
#'
#' @param site_path `site-path` du PB ([pb_site_path()]).
#' @return `https://www.ofce.fr/pb/{site_path}/`.
#' @keywords internal
#' @noRd
pb_public_url <- function(site_path) {
  sprintf("https://www.ofce.fr/pb/%s/", sub("/$", "", as.character(site_path)))
}

#' Nom du PDF d'un PB
#'
#' Publié (`pb` connu) : `{pdf-prefix}{pb}.pdf` (ex. `IFEPB12.pdf`).
#' Brouillon : `{draft-prefix}-{repo}-{version}.pdf` (ex.
#' `ife-draft-pb-csskvv-chn-v1.pdf`), sans segment de version si `version`
#' n'est pas encore renseignée.
#'
#' @param params Paramètres de série ([pb_series_params()]).
#' @param pb Numéro du PB, ou `NULL` pour un brouillon.
#' @param repo Nom du dépôt (brouillon uniquement).
#' @param version Version de revue courante (brouillon uniquement), ou `NULL`.
#' @return Chaîne.
#' @keywords internal
#' @noRd
pb_pdf_name <- function(params, pb = NULL, repo = NULL, version = NULL) {
  if (!is.null(pb))
    return(sprintf("%s%d.pdf", params$pdf_prefix, as.integer(pb)))
  if (!is.null(version) && nzchar(as.character(version)))
    sprintf("%s-%s-%s.pdf", params$draft_prefix, repo, version)
  else
    sprintf("%s-%s.pdf", params$draft_prefix, repo)
}
