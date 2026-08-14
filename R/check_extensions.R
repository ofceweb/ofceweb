#' Détecte les extensions Quarto OFCE périmées dans `_extensions/`
#'
#' Depuis que les extensions Quarto OFCE sont installées et mises à jour via
#' [ofce::setup_quarto()] (qui les récupère depuis le dépôt GitHub
#' `OFCE/ofce-quarto-extensions`, sous `_extensions/ofce/...`), toute
#' extension OFCE trouvée ailleurs — à plat directement sous `_extensions/`
#' (ancienne convention), ou sous `_extensions/ofce/` mais absente du paquet
#' canonique (ex. `ofce/pb`, retiré du paquet) — est un résidu d'une
#' installation antérieure à cette migration.
#'
#' Cette fonction ne fait que **signaler** ces dossiers via
#' [cli::cli_alert_warning()] ; elle ne supprime jamais rien automatiquement.
#'
#' @param root Chemin vers la racine du dépôt. Défaut `"."`.
#' @return Invisible, le vecteur (éventuellement vide) des chemins repérés
#'   comme périmés.
#' @keywords internal
check_stray_ofce_extensions <- function(root = ".") {
  ext_dir <- fs::path(root, "_extensions")
  if (!fs::dir_exists(ext_dir)) return(invisible(character()))

  # Ancienne convention "à plat" (pré-`ofce::setup_quarto()`) : ces dossiers
  # vivaient directement sous `_extensions/`, alors que le paquet canonique
  # les installe sous `_extensions/ofce/`.
  legacy_flat <- c("wp", "ofce-website", "social-share", "quarto-ext",
                   "crossref-listings", "iconify", "section-bibliographies")
  # Sous `_extensions/ofce/`, mais absent du paquet canonique
  # `ofce/ofce-quarto-extensions` (ex. `pb`, retiré ; implémentation prévue
  # séparément).
  legacy_nested_ofce <- c("pb")

  stray <- character()

  top <- fs::dir_ls(ext_dir, type = "directory", recurse = FALSE, fail = FALSE)
  for (d in top) {
    if (fs::path_file(d) %in% legacy_flat &&
        fs::file_exists(fs::path(d, "_extension.yml"))) {
      stray <- c(stray, as.character(d))
    }
  }

  ofce_dir <- fs::path(ext_dir, "ofce")
  if (fs::dir_exists(ofce_dir)) {
    for (sub in fs::dir_ls(ofce_dir, type = "directory", recurse = FALSE, fail = FALSE)) {
      if (fs::path_file(sub) %in% legacy_nested_ofce &&
          fs::file_exists(fs::path(sub, "_extension.yml"))) {
        stray <- c(stray, as.character(sub))
      }
    }
  }

  for (s in stray) {
    cli::cli_alert_warning(
      "Extension p\u00e9rim\u00e9e d\u00e9tect\u00e9e : {.path {fs::path_rel(s, root)}} \\
       \u2014 non install\u00e9e par {.fn ofce::setup_quarto}. \u00c0 supprimer \\
       manuellement si elle n'est plus utilis\u00e9e."
    )
  }

  invisible(stray)
}
