#' Génère ou met à jour le manifeste JSON d'un document de travail
#'
#' Lit les métadonnées depuis `_quarto.yml` (et `index.qmd` pour l'abstract, le
#' titre et les listes éditoriales en repli), construit un `manifest.json`
#' normalisé et l'écrit à la racine du dépôt (pour être commité) et dans
#' `_site/` (pour être déployé).
#'
#' Le manifeste est collecté par `webhome` via la GitHub API pour construire
#' l'index des documents de travail OFCE.
#'
#' # Modèle de données v1
#'
#' Le manifeste suit le schéma v1 (`schema_version: "1.0"`, voir
#' `modele-donnees-v1.qmd`) :
#'
#' * `id` : `{institution}-wp-{annee}-{wp}-{lang}` (minuscules, sans
#'   zero-padding, ex. `"ofce-wp-2026-6-fr"`), stable d'une version à l'autre ;
#'   `NULL` tant que `wp`/`annee` ne sont pas enregistrés (brouillon).
#' * `institution` : lu dans `institution` de `_quarto.yml` uniquement
#'   (`ofce`, `cepii` ou `ife`) ; `"ofce"` si absent, avertissement et `"ofce"`
#'   si la valeur est inconnue. Le champ `institut` (logos Typst) n'est pas lu.
#' * `type = "working-paper"`, `media = "html"`, `auto_update = TRUE`.
#' * `translation_id` : champ optionnel `translation_id` de `_quarto.yml`,
#'   sinon `NULL`.
#' * `title` : `_quarto.yml`, sinon `index.qmd`.
#' * `authors` : liste de noms (chaînes) ; `affiliation`/`orcid` restent dans
#'   `_quarto.yml`.
#' * `categories`, `keywords`, `jel` : listes lues dans `_quarto.yml`, sinon
#'   dans le frontmatter de `index.qmd`, sinon `[]` ; codes JEL en majuscules.
#' * `date_published` (clé YAML `date`) et `date_modified`.
#' * `pdf` : URL absolue (`https://www.ofce.fr/{pdf-path}`) ou `NULL` tant que
#'   `pdf-path` est inconnu.
#'
#' Les champs historiques `wp`, `annee`, `version`, `stage`, `pdf-path`,
#' `source-repo` et `ofceweb-version` sont conservés (lus par `deploy_wp()` et
#' `ftp_deploy.yml`). Les manifestes de staging/brouillon ne sont pas
#' conformes v1 par construction : le schéma s'applique aux contenus publiés.
#'
#' Inclut un champ `source-repo` (`"owner/repo"`, résolu depuis le remote
#' `origin` local) utilisé par le workflow `ftp_deploy.yml` pour détecter
#' qu'un autre dépôt tente de publier sous le même numéro de WP (même
#' `annee`/`wp`) et bloquer ce déploiement avant d'écraser le WP existant.
#'
#' Inclut aussi un champ `pdf-path` : le chemin du fichier `output-file` du
#' format `wp-pdf`/`wp-typst` actif, relatif à la racine `www.ofce.fr` (ex.
#' `"wp/2026/5/OFCEWP2026-5.pdf"`). Calculé dès que `wp`/`annee` sont connus,
#' indépendamment de `stage`/`url` : c'est l'emplacement de publication final,
#' pas nécessairement celui où le fichier est déployé au moment de l'appel.
#' `NULL` si `wp`/`annee` ou le fichier PDF/Typst ne sont pas encore connus.
#'
#' Inclut aussi un champ `ofceweb-version` : la version du package
#' **ofceweb** ([utils::packageVersion()]) ayant généré le manifeste — utile
#' pour diagnostiquer un manifeste produit par une version antérieure du
#' package.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#'
#' @returns La liste du manifeste (invisible).
#' @seealso [render_wp()], [wp_version_up()]
#' @importFrom fs path_expand path_abs path_norm path file_exists dir_exists
#' @importFrom yaml read_yaml
#' @importFrom jsonlite toJSON
#' @importFrom cli cli_alert_success cli_alert_warning
#' @keywords internal
wp_manifest <- function(path = ".", stage = NULL) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  yml <- yaml::read_yaml(yml_path)

  # Champs de base (accès exact `[[` : `$` ferait de l'appariement partiel,
  # ex. `date` -> `date-modified`)
  wp      <- yml[["wp"]]       # NULL ou integer
  annee   <- if (!is.null(yml[["annee"]])) as.integer(yml[["annee"]]) else NULL
  version <- if (!is.null(yml[["version"]])) as.character(yml[["version"]]) else NULL
  lang    <- if (!is.null(yml[["lang"]]))    as.character(yml[["lang"]])    else "fr"

  date_val <- if (!is.null(yml[["date"]])) as.character(yml[["date"]]) else format(Sys.Date(), "%Y-%m-%d")
  date_mod <- format(Sys.Date(), "%Y-%m-%d")

  # Auteurs : liste de noms (chaînes) -- modèle de données v1
  authors <- manifest_authors(yml)

  # index.qmd : abstract, titre et listes éditoriales (replis de _quarto.yml)
  idx_path <- fs::path(root, "index.qmd")
  idx_yml  <- if (fs::file_exists(idx_path))
    tryCatch(get_yaml(idx_path), error = function(e) NULL) else NULL

  # Titre : _quarto.yml, sinon index.qmd (le titre vit souvent dans index.qmd)
  title <- manifest_chr1(yml[["title"]]) %||% manifest_chr1(idx_yml[["title"]]) %||% ""

  # Abstract : chercher dans index.qmd d'abord, puis _quarto.yml
  abstract <- idx_yml$abstract %||% yml$abstract
  if (!is.null(abstract)) abstract <- as.character(abstract)

  # Champs v1 : institution, listes éditoriales, identifiants
  institution    <- manifest_institution(yml)
  categories     <- manifest_list_field("categories", yml, idx_yml)
  keywords       <- manifest_list_field("keywords",   yml, idx_yml)
  jel            <- lapply(manifest_list_field("jel", yml, idx_yml), toupper)
  translation_id <- manifest_chr1(yml[["translation_id"]])
  id             <- manifest_id(institution, "wp", lang, list(annee, wp))

  # Dépôt source (owner/repo) — utilisé par ftp_deploy.yml pour vérifier
  # qu'un déploiement ne s'apprête pas à écraser un WP publié par un autre
  # dépôt réutilisant le même numéro. Même format que le contexte
  # `github.repository` des workflows GitHub Actions.
  source_repo <- gh_slug_from_remote(root)
  if (is.na(source_repo)) source_repo <- NULL

  # URL de déploiement
  ver_seg <- if (!is.null(version)) paste0(version, "/") else ""
  url <- if (isFALSE(stage) && !is.null(wp) && !is.null(annee)) {
    # Publié : URL FTP production numérotée
    sprintf("https://www.ofce.fr/wp/%d/%d/%s", annee, wp, ver_seg)
  } else if (isTRUE(stage)) {
    # Staging FTP : URL de pré-publication (avant enregistrement dans le registre)
    repo_slug <- if (!is.null(source_repo) && !is.na(source_repo))
      basename(source_repo) else fs::path_file(root)
    sprintf("https://staging.ofce.fr/%s/%s", repo_slug, ver_seg)
  } else if (!is.null(wp) && !is.null(annee)) {
    # Compatibilité : stage NULL mais wp renseigné (appels antérieurs sans stage)
    sprintf("https://www.ofce.fr/wp/%d/%d/%s", annee, wp, ver_seg)
  } else {
    # Brouillon initial : GitHub Pages
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

  # Chemin du PDF relatif à www.ofce.fr (ex. "wp/2026/5/OFCEWP2026-5.pdf") --
  # emplacement de publication final, calculé indépendamment de `stage`/`url`
  # dès que `wp`/`annee` sont connus (même si le WP n'est pas encore déployé
  # à cet emplacement).
  pdf_path <- if (!is.null(pdf_file) && !is.null(wp) && !is.null(annee)) {
    sprintf("wp/%d/%d/%s%s", annee, wp, ver_seg, pdf_file)
  } else {
    NULL
  }

  # URL absolue du PDF (v1) : `null` tant que l'emplacement final est inconnu
  # (le nom de fichier seul est inutilisable sans son chemin).
  pdf_url <- if (!is.null(pdf_path)) paste0("https://www.ofce.fr/", pdf_path) else NULL

  # Assemblage : champs v1, puis champs historiques conservés (consommés par
  # deploy_wp() et ftp_deploy.yml)
  manifest <- list(
    schema_version = "1.0",
    id             = id,
    translation_id = translation_id,
    institution    = institution,
    type           = "working-paper",
    media          = "html",
    lang           = lang,
    title          = title,
    authors        = authors,
    abstract       = abstract,
    categories     = categories,
    keywords       = keywords,
    jel            = jel,
    date_published = date_val,
    date_modified  = date_mod,
    url            = url,
    pdf            = pdf_url,
    repo           = repo_url,
    auto_update    = TRUE,
    # --- champs historiques (hors v1) ---
    wp            = wp,
    annee         = annee,
    version       = version,
    stage         = stage,
    `pdf-path`    = pdf_path,
    `source-repo` = source_repo,
    `ofceweb-version` = as.character(utils::packageVersion("ofceweb"))
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
