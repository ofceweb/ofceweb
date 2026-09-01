#' Active le chiffrement statique d'un document de travail
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' Cette fonction est dépréciée. Voir [encrypt_site()] pour plus de détails.
#'
#' @inheritParams encrypt_site
#' @importFrom lifecycle deprecate_soft
#' @keywords internal
encrypt_wp <- function(path = ".", password = NULL) {
  lifecycle::deprecate_soft(
    when    = "0.5.5",
    what    = "encrypt_wp()",
    details = paste0(
      "Le chiffrement est désormais géré en CI via le secret GitHub ",
      "`STATICRYPT_PASSWORD`. ",
      "Utilisez `gh secret set STATICRYPT_PASSWORD --repo owner/repo` directement."
    )
  )
  invisible(NULL)
}
