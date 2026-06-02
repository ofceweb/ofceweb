#' Génère ou met à jour le manifeste JSON d'un document de travail
#'
#' Lit les métadonnées depuis `_quarto.yml` (et `index.qmd` pour l'abstract),
#' construit un `manifest.json` normalisé et l'écrit à la racine du dépôt
#' (pour être commité) et dans `_site/` (pour être déployé).
#'
#' Le manifeste est collecté par `webhome` via la GitHub API pour construire
#' l'index des documents de travail OFCE.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#'
#' @returns La liste du manifeste (invisible).
#' @seealso [render_wp()], [wp_version_up()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_exists
#' @importFrom yaml read_yaml
#' @importFrom jsonlite toJSON
#' @importFrom cli cli_alert_success cli_alert_warning
#' @export
wp_manifest <- function(path = ".") {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  yml <- yaml::read_yaml(yml_path)

  # Champs de base
  wp      <- yml$wp       # NULL ou integer
  annee   <- if (!is.null(yml$annee)) as.integer(yml$annee) else NULL
  version <- if (!is.null(yml$version)) as.character(yml$version) else "v0"
  lang    <- if (!is.null(yml$lang))    as.character(yml$lang)    else "fr"
  title   <- if (!is.null(yml$title))   as.character(yml$title)   else ""

  date_val <- if (!is.null(yml$date)) as.character(yml$date) else format(Sys.Date(), "%Y-%m-%d")
  date_mod <- format(Sys.Date(), "%Y-%m-%d")

  # Auteurs
  raw_authors <- yml$author
  if (is.null(raw_authors)) raw_authors <- yml$authors
  authors <- lapply(
    if (is.list(raw_authors) && !is.null(raw_authors$name)) list(raw_authors) else raw_authors,
    function(a) {
      entry <- list(name = as.character(a$name %||% ""))
      if (!is.null(a$affiliation)) entry$affiliation <- as.character(a$affiliation)
      if (!is.null(a$orcid))       entry$orcid       <- as.character(a$orcid)
      entry
    }
  )

  # Abstract : chercher dans index.qmd d'abord, puis _quarto.yml
  abstract <- NULL
  idx_path <- fs::path(root, "index.qmd")
  if (fs::file_exists(idx_path)) {
    idx_yml  <- tryCatch(get_yaml(idx_path), error = function(e) NULL)
    abstract <- idx_yml$abstract %||% yml$abstract
  } else {
    abstract <- yml$abstract
  }
  if (!is.null(abstract)) abstract <- as.character(abstract)

  # URL de déploiement
  url <- if (!is.null(wp) && !is.null(annee)) {
    sprintf("https://www.ofce.fr/wp/%d/%d/%s/", annee, wp, version)
  } else {
    # brouillon : GitHub Pages
    su <- yml$website$`site-url`
    if (!is.null(su) && nzchar(su)) su else NULL
  }

  # URL du dépôt
  repo_url <- yml$website$`repo-url`

  # Fichier PDF (cherche wp-pdf puis wp-typst)
  pdf_file <- NULL
  for (fmt in c("wp-pdf", "wp-typst")) {
    of <- yml$format[[fmt]]$`output-file`
    if (!is.null(of) && nzchar(of)) { pdf_file <- of; break }
  }
  # Aussi dans index.qmd
  if (is.null(pdf_file) && fs::file_exists(idx_path)) {
    idx_yml <- tryCatch(get_yaml(idx_path), error = function(e) NULL)
    for (fmt in c("wp-pdf", "wp-typst")) {
      of <- idx_yml$format[[fmt]]$`output-file`
      if (!is.null(of) && nzchar(of)) { pdf_file <- of; break }
    }
  }

  # Assemblage
  manifest <- list(
    title         = title,
    authors       = authors,
    abstract      = abstract,
    wp            = wp,
    annee         = annee,
    version       = version,
    date          = date_val,
    date_modified = date_mod,
    url           = url,
    pdf           = pdf_file,
    repo          = repo_url,
    lang          = lang
  )

  json_str <- jsonlite::toJSON(
    manifest,
    auto_unbox = TRUE,
    pretty     = TRUE,
    null       = "null"
  )

  # Écriture à la racine du dépôt
  out_root <- fs::path(root, "manifest.json")
  writeLines(json_str, out_root)
  cli::cli_alert_success("manifest.json écrit dans {.path {root}}")

  # Écriture dans _site/ si présent
  site_dir <- fs::path(root, "_site")
  if (fs::dir_exists(site_dir)) {
    writeLines(json_str, fs::path(site_dir, "manifest.json"))
    cli::cli_alert_success("manifest.json écrit dans {.path {site_dir}}")
  }

  invisible(manifest)
}

# Opérateur null-coalescing interne
`%||%` <- function(x, y) if (is.null(x)) y else x
