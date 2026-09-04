#' Rescanne les pages d'un policy brief
#'
#' Wrapper autour de [rescan_site()] pour les dépôts PB. Équivalent PB de
#' [rescan_wp()]. Le comportement est identique.
#'
#' Défini comme un appel explicite (plutôt qu'un alias `rescan_pb <-
#' rescan_site`, comme pour [rescan_wp()]) : l'ordre de chargement
#' alphabétique des fichiers place `rescan_pb.R` avant `rescan_site.R`, où
#' `rescan_site()` n'existe pas encore au moment de l'évaluation.
#'
#' @inheritParams rescan_site
#' @export
rescan_pb <- function(...) rescan_site(...)
