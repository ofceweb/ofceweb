#' Vérifie que le package ofce installé satisfait la version minimale requise
#'
#' Les extensions Quarto OFCE posées par [ofce::setup_quarto()] dépendent de
#' la version du package **ofce** lui-même (gabarits, logique d'installation).
#' Contrairement à [check_quarto_version()] (qui se contente d'avertir), cette
#' vérification est **bloquante** : à la différence de la CLI Quarto, un
#' package ofce trop ancien ou absent fait typiquement échouer ou corrompre
#' silencieusement l'installation des extensions, il est donc préférable
#' d'interrompre immédiatement plutôt que de laisser `setup_*()` continuer
#' dans un état incohérent.
#'
#' @param min Version minimale requise (chaîne comparable, ex. `"1.3.39"`).
#' @return Invisible `TRUE` si la version installée satisfait `min`. N'a
#'   jamais d'autre retour : soit la condition est remplie, soit la fonction
#'   interrompt l'exécution via [cli::cli_abort()].
#' @keywords internal
check_ofce_version <- function(min = "1.3.39") {
  installed <- tryCatch(
    as.character(utils::packageVersion("ofce")),
    error = function(e) NA_character_
  )

  if (is.na(installed))
    cli::cli_abort(c(
      "Le package {.pkg ofce} n'est pas install\u00e9.",
      "i" = "Version {.val {min}} ou sup\u00e9rieure requise \u2014 installer avec \\
             {.code remotes::install_github(\"ofce/ofce\")}."
    ))

  if (utils::compareVersion(installed, min) < 0)
    cli::cli_abort(c(
      "Version du package {.pkg ofce} install\u00e9e ({.val {installed}}) \\
       insuffisante \u2014 {.val {min}} ou sup\u00e9rieure requise.",
      "i" = "Mettre \u00e0 jour avec {.code remotes::install_github(\"ofce/ofce\")}."
    ))

  invisible(TRUE)
}
