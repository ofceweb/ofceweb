#' Vérifie que la CLI Quarto installée satisfait la version minimale requise
#'
#' Les gabarits et extensions OFCE (voir [ofce::setup_quarto()]) supposent une
#' CLI Quarto récente. Cette fonction se contente de **signaler** — jamais
#' d'interrompre — un écart de version via [cli::cli_alert_warning()], pour
#' laisser les fonctions `setup_*()` continuer au mieux.
#'
#' @param min Version minimale requise (chaîne comparable, ex. `"1.9.38"`).
#' @return Invisible, `TRUE` si la version installée satisfait `min` (ou
#'   `FALSE` sinon, y compris si la CLI Quarto est introuvable).
#' @keywords internal
check_quarto_version <- function(min = "1.9.38") {
  ok <- tryCatch(
    quarto::quarto_available(min = min),
    error = function(e) NA
  )

  if (isTRUE(ok)) return(invisible(TRUE))

  current <- tryCatch(
    as.character(quarto::quarto_version()),
    error = function(e) NA_character_
  )

  if (is.na(current)) {
    cli::cli_alert_warning(
      "Impossible de d\u00e9terminer la version de Quarto install\u00e9e \\
       (CLI introuvable ?). Version {.val {min}} ou sup\u00e9rieure requise."
    )
  } else {
    cli::cli_alert_warning(
      "Version de Quarto install\u00e9e ({.val {current}}) insuffisante \\
       \u2014 {.val {min}} ou sup\u00e9rieure requise. \\
       T\u00e9l\u00e9charger la derni\u00e8re version : \\
       {.url https://quarto.org/docs/get-started/}"
    )
  }

  invisible(FALSE)
}
