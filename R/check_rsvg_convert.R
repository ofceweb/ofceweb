#' Vérifie que `rsvg-convert` (paquet `librsvg`) est installé
#'
#' `rsvg-convert` est utilisé par la chaîne LaTeX de Quarto (format
#' `wp-pdf`) pour rastériser les figures vectorielles SVG (notamment les
#' graphiques ggplot2 exportés en SVG, ou les diagrammes Mermaid/Graphviz)
#' lors du rendu PDF. Sans ce binaire, Quarto/pandoc reste fonctionnel mais
#' bascule sur une conversion de secours qui peut produire des PDF nettement
#' plus volumineux. Cette fonction se contente de **signaler** l'absence de
#' l'outil — jamais d'interrompre.
#'
#' Non pertinent pour le format `wp-typst` : Typst gère nativement les SVG
#' (dépendance de conversion auto-suffisante, sans binaire externe), d'où
#' l'appel conditionnel à cette fonction uniquement quand `wp-pdf` (LaTeX)
#' est le moteur PDF actif (voir [setup_wp()] et [check_wp()]).
#'
#' @param verbose Logique. Si `TRUE` (défaut), affiche le résultat via
#'   [cli::cli_alert_success()] / [cli::cli_alert_warning()] (avec des
#'   instructions d'installation par OS). Si `FALSE`, reste silencieux —
#'   utilisé par [setup_wp()] et [check_wp()], qui composent leur propre
#'   message.
#' @return Invisible, `TRUE` si `rsvg-convert` est trouvé sur le `PATH`,
#'   `FALSE` sinon.
#' @keywords internal
check_rsvg_convert <- function(verbose = TRUE) {
  found <- nzchar(Sys.which("rsvg-convert")[[1]])

  if (found) {
    if (verbose) cli::cli_alert_success("{.code rsvg-convert} d\u00e9tect\u00e9 sur le PATH.")
    return(invisible(TRUE))
  }

  if (verbose) {
    sysname <- Sys.info()[["sysname"]]
    install_hint <- if (identical(sysname, "Darwin")) {
      "{.code brew install librsvg}"
    } else if (.Platform$OS.type == "windows") {
      "{.code scoop install rsvg-convert} ou {.code choco install rsvg-convert}"
    } else {
      "{.code apt install librsvg2-bin} (ou l'\u00e9quivalent de votre distribution)"
    }
    cli::cli_alert_warning(c(
      "{.code rsvg-convert} introuvable sur le PATH.",
      "i" = "Installer via {install_hint}.",
      "i" = "Sans cet outil, les figures SVG converties pour le PDF LaTeX \\
             ({.field wp-pdf}) peuvent produire des fichiers plus volumineux."
    ))
  }

  invisible(FALSE)
}
