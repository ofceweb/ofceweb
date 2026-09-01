#' Active le chiffrement statique du site
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' Cette fonction est dépréciée. Le chiffrement est désormais géré
#' **exclusivement en CI** (GitHub Actions), juste avant le transfert FTP, via
#' le secret `STATICRYPT_PASSWORD` défini sur le dépôt GitHub. Il n'est plus
#' nécessaire de configurer quoi que ce soit localement.
#'
#' Pour activer le chiffrement sur un dépôt, définir le secret GitHub
#' directement :
#'
#' ```
#' gh secret set STATICRYPT_PASSWORD --repo owner/repo
#' ```
#'
#' Si le secret est absent, le déploiement s'effectue sans chiffrement.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param password Ignoré.
#'
#' @returns Invisible `NULL`.
#' @seealso [remove_encrypt()]
#' @importFrom lifecycle deprecate_soft
#' @keywords internal
encrypt_site <- function(path = ".", password = NULL) {
  lifecycle::deprecate_soft(
    when    = "0.5.5",
    what    = "encrypt_site()",
    details = paste0(
      "Le chiffrement est désormais géré en CI via le secret GitHub ",
      "`STATICRYPT_PASSWORD`. ",
      "Utilisez `gh secret set STATICRYPT_PASSWORD --repo owner/repo` directement."
    )
  )
  invisible(NULL)
}
