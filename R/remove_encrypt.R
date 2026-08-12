#' Désactive le chiffrement statique du site
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' Cette fonction est dépréciée. Le chiffrement étant désormais piloté
#' **exclusivement par le secret GitHub `STATICRYPT_PASSWORD`**, pour désactiver
#' le chiffrement il suffit de supprimer ce secret :
#'
#' ```
#' gh secret delete STATICRYPT_PASSWORD --repo owner/repo
#' ```
#'
#' Si le secret est absent, le déploiement s'effectue sans chiffrement.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param delete_secret Ignoré.
#'
#' @returns Invisible `NULL`.
#' @seealso [encrypt_site()]
#' @section Site Users:
#'
#' @importFrom lifecycle deprecate_soft
#' @export
remove_encrypt <- function(path = ".", delete_secret = TRUE) {
  lifecycle::deprecate_soft(
    when    = "0.5.5",
    what    = "remove_encrypt()",
    details = paste0(
      "Pour désactiver le chiffrement, supprimer le secret GitHub : ",
      "`gh secret delete STATICRYPT_PASSWORD --repo owner/repo`."
    )
  )
  invisible(NULL)
}
