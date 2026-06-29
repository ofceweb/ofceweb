#' Active le chiffrement statique d'un document de travail
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' Cette fonction est dépréciée. Voir [encrypt_site()] pour plus de détails.
#'
#' @inheritParams encrypt_site
#' @export
encrypt_wp <- function(path = ".", password = NULL) {
  .Deprecated(
    msg = paste0(
      "`encrypt_wp()` est dépréciée. ",
      "Le chiffrement est désormais géré en CI via le secret GitHub ",
      "`STATICRYPT_PASSWORD`. ",
      "Utilisez `gh secret set STATICRYPT_PASSWORD --repo owner/repo` directement."
    )
  )
  invisible(NULL)
}
