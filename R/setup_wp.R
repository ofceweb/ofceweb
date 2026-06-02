#' Initialise un dépôt de document de travail (WP) OFCE
#'
#' Copie les gabarits embarqués dans le package (`inst/setup_wp/`) à la racine
#' du dépôt, initialise la branche `gh-pages` pour la pré-publication, et
#' adapte le `_quarto.yml` avec les métadonnées du WP (titre, numéro, année,
#' langue, URLs).
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param website_title Chaîne ou `NULL`. Titre du WP. Si `NULL`, utilise le
#'   nom du dépôt GitHub.
#' @param wp Entier ou `NULL`. Numéro du WP. `NULL` = brouillon (pré-publication
#'   GitHub Pages) ; entier = WP publié (hébergement OFCE FTP).
#' @param annee Entier. Année de publication. Défaut = année courante.
#' @param lang Chaîne. Langue principale : `"fr"` (défaut) ou `"en"`.
#' @param hypothesis Logique. Active les commentaires Hypothesis. Défaut `FALSE`.
#' @param versionning Logique. Si `TRUE` (défaut) et WP publié (`wp` non `NULL`),
#'   ajoute `/v0` au `site-path`.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [render_wp()], [deploy_wp()], [wp_version_up()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists file_copy dir_copy dir_create dir_ls path_ext path_ext_remove
#' @importFrom cli cli_h1 cli_h2 cli_li cli_abort cli_alert_success cli_alert_warning cli_alert_info
#' @importFrom yaml read_yaml write_yaml verbatim_logical
#' @importFrom gert git_remote_list
#' @export
setup_wp <- function(
    path = ".",
    website_title = NULL,
    wp = NULL,
    annee = as.integer(format(Sys.Date(), "%Y")),
    lang = "fr",
    hypothesis = FALSE,
    versionning = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  if (!fs::dir_exists(root))
    cli::cli_abort("Le dossier {.path {root}} n'existe pas.")

  cli::cli_h1("setup_wp dans {.path {fs::path_file(root)}}")

  # ---- 0. validation des arguments -----------------------------------------
  if (!is.null(wp)) {
    wp <- suppressWarnings(as.integer(wp))
    if (is.na(wp))
      cli::cli_abort("{.arg wp} doit être un entier ou NULL.")
  }

  annee <- suppressWarnings(as.integer(annee))
  if (is.na(annee))
    cli::cli_abort("{.arg annee} doit être un entier.")

  if (!lang %in% c("fr", "en")) {
    cli::cli_alert_warning("{.arg lang} doit être {.val fr} ou {.val en}. Utilisation de {.val fr}.")
    lang <- "fr"
  }

  # ---- 1. branche gh-pages (toujours pour les WPs) -------------------------
  init_gh_pages_branch(root)

  # ---- 2. infos dépôt git --------------------------------------------------
  remotes <- tryCatch(gert::git_remote_list(repo = root),
                      error = function(e) NULL)
  origin_url <- NULL
  if (!is.null(remotes) && nrow(remotes) > 0) {
    o <- remotes[remotes$name == "origin", , drop = FALSE]
    if (nrow(o) > 0) origin_url <- o$url[[1]]
    else origin_url <- remotes$url[[1]]
  }

  parse_remote_wp <- function(url) {
    if (is.null(url)) return(list(host = NA_character_, repo = NA_character_))
    url2 <- sub("\\.git$", "", url)
    if (grepl("^git@", url2)) {
      m <- regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
    } else {
      m <- regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
    }
    if (length(m) < 3) return(list(host = NA_character_, repo = NA_character_))
    list(host = m[[2]], repo = m[[3]])
  }

  gh     <- parse_remote_wp(origin_url)
  repo_name <- if (is.na(gh$repo)) fs::path_file(root) else gh$repo
  gh_org    <- if (is.na(gh$host)) "ofce" else gh$host

  # ---- 3. titre du WP -------------------------------------------------------
  final_title <- if (!is.null(website_title) && nzchar(website_title)) {
    website_title
  } else {
    repo_name
  }

  # ---- 4. localisation des gabarits -----------------------------------------
  pkg_setup_wp   <- system.file("setup_wp",   package = "ofceweb")
  pkg_setup_site <- system.file("setup_site", package = "ofceweb")
  if (!nzchar(pkg_setup_wp))
    pkg_setup_wp <- fs::path(find.package("ofceweb"), "inst", "setup_wp")
  if (!nzchar(pkg_setup_wp))
    pkg_setup_wp <- fs::path(root, "inst", "setup_wp")   # dev fallback
  if (!nzchar(pkg_setup_site))
    pkg_setup_site <- fs::path(root, "inst", "setup_site")

  # ---- 5. copie _quarto.yml (toujours) --------------------------------------
  src_yaml  <- fs::path(pkg_setup_wp, "_quarto.yml")
  dest_yaml <- fs::path(root, "_quarto.yml")
  fs::file_copy(src_yaml, dest_yaml, overwrite = TRUE)
  cli::cli_alert_success("Copie de {.file _quarto.yml}")

  # ---- 6. copie index.qmd (si absent) ---------------------------------------
  src_index    <- fs::path(pkg_setup_wp, "index.qmd")
  dest_index   <- fs::path(root, "index.qmd")
  created_index <- !fs::file_exists(dest_index)
  if (created_index) {
    fs::file_copy(src_index, dest_index, overwrite = FALSE)
    cli::cli_alert_success("Copie de {.file index.qmd}")
  } else {
    cli::cli_alert_info("{.file index.qmd} déjà présent — non écrasé.")
  }

  # ---- 7. copie annexes.qmd et news.qmd (si absents) -----------------------
  for (qmd in c("annexes.qmd", "news.qmd")) {
    dest_qmd <- fs::path(root, qmd)
    if (!fs::file_exists(dest_qmd)) {
      fs::file_copy(fs::path(pkg_setup_wp, qmd), dest_qmd, overwrite = FALSE)
      cli::cli_alert_success("Copie de {.file {qmd}}")
    } else {
      cli::cli_alert_info("{.file {qmd}} déjà présent — non écrasé.")
    }
  }

  # ---- 8. copie www/ depuis setup_site/ ------------------------------------
  src_www <- fs::path(pkg_setup_site, "www")
  if (fs::dir_exists(src_www)) {
    dest_www <- fs::path(root, "www")
    fs::dir_create(dest_www)
    for (f in fs::dir_ls(src_www, recurse = FALSE)) {
      if (fs::dir_exists(f))
        fs::dir_copy(f, fs::path(dest_www, fs::path_file(f)), overwrite = TRUE)
      else
        fs::file_copy(f, fs::path(dest_www, fs::path_file(f)), overwrite = TRUE)
    }
    cli::cli_alert_success("Copie du dossier {.path www/}")
  }

  # ---- 9. copie _extensions/wp/ depuis setup_site/ -------------------------
  src_ext_wp <- fs::path(pkg_setup_site, "_extensions", "wp")
  if (fs::dir_exists(src_ext_wp)) {
    dest_ext <- fs::path(root, "_extensions")
    dest_ext_wp <- fs::path(dest_ext, "wp")
    fs::dir_create(dest_ext)
    fs::dir_copy(src_ext_wp, dest_ext_wp, overwrite = TRUE)
    cli::cli_alert_success("Copie de {.path _extensions/wp/}")
  }

  # ---- 10. copie des workflows ----------------------------------------------
  src_wf  <- fs::path(pkg_setup_wp, "workflows")
  dest_wf <- fs::path(root, ".github", "workflows")
  if (fs::dir_exists(src_wf)) {
    fs::dir_create(dest_wf, recurse = TRUE)
    for (f in fs::dir_ls(src_wf, type = "file")) {
      fname <- fs::path_file(f)
      if (fs::path_ext(fname) == "html") fname <- fs::path_ext_remove(fname)
      fs::file_copy(f, fs::path(dest_wf, fname), overwrite = TRUE)
    }
    cli::cli_alert_success("Copie des workflows vers {.path .github/workflows/}")
  }

  # ---- 11. édition du _quarto.yml ------------------------------------------
  yml <- yaml::read_yaml(dest_yaml)

  yml$wp     <- wp
  yml$annee  <- annee
  yml$version <- "v0"
  yml$title  <- final_title
  yml$lang   <- lang

  # URLs
  if (!is.na(gh$host) && !is.na(gh$repo)) {
    yml$website$`repo-url` <- sprintf("https://github.com/%s/%s/", gh$host, gh$repo)
  }

  if (!is.null(wp)) {
    # WP publié : hébergement OFCE
    yml$website$`site-url`  <- "https://www.ofce.fr/"
    site_path <- paste0("wp/", annee, "/", wp)
    if (isTRUE(versionning)) site_path <- paste0(site_path, "/v0")
    yml$website$`site-path` <- site_path
  } else {
    # Brouillon : GitHub Pages
    yml$website$`site-url`  <- sprintf("https://%s.github.io/%s/", gh_org, repo_name)
    yml$website$`site-path` <- NULL
  }

  # Hypothesis
  yml$comments <- list(hypothesis = isTRUE(hypothesis))

  # output-file du PDF
  pdf_output <- if (!is.null(wp)) {
    sprintf("OFCEWP%d-%d.pdf", annee, wp)
  } else {
    "OFCEWP-draft.pdf"
  }
  if (is.null(yml$format)) yml$format <- list()
  if (is.null(yml$format$`wp-pdf`)) yml$format$`wp-pdf` <- list()
  yml$format$`wp-pdf`$`output-file` <- pdf_output

  yaml::write_yaml(
    yml, dest_yaml,
    indent.mapping.sequence = TRUE,
    handlers = list(logical = yaml::verbatim_logical)
  )
  cli::cli_alert_success("Mise à jour de {.file _quarto.yml}")

  # Met aussi à jour l'output-file dans index.qmd si on vient de le créer
  if (created_index) {
    tryCatch({
      idx_yml <- get_yaml(dest_index)
      if (is.null(idx_yml)) idx_yml <- list()
      if (is.null(idx_yml$format)) idx_yml$format <- list()
      if (is.null(idx_yml$format$`wp-pdf`)) idx_yml$format$`wp-pdf` <- list()
      idx_yml$format$`wp-pdf`$`output-file` <- pdf_output
      put_yaml(idx_yml, dest_index)
      cli::cli_alert_success("output-file mis à jour dans {.file index.qmd}")
    }, error = function(e) {
      cli::cli_alert_warning("Impossible de patcher index.qmd : {conditionMessage(e)}")
    })
  }

  # ---- 12. server-dir dans le workflow FTP ----------------------------------
  if (!is.null(wp)) {
    wf_ftp <- fs::path(root, ".github", "workflows", "ftp_deploy.yml")
    if (fs::file_exists(wf_ftp)) {
      server_dir <- paste0("wp/", annee, "/", wp)
      if (isTRUE(versionning)) server_dir <- paste0(server_dir, "/v0")
      set_ftp_server_dir(root, server_dir)
    }
  }

  # ---- 13. .gitignore -------------------------------------------------------
  gi_path <- fs::path(root, ".gitignore")
  gi_lines <- if (fs::file_exists(gi_path)) readLines(gi_path, warn = FALSE) else character()
  changed <- FALSE

  if (!any(trimws(gi_lines) %in% c("_site", "/_site", "_site/"))) {
    gi_lines <- c(gi_lines, "_site")
    changed <- TRUE
  }
  if (!any(grepl("^\\*\\.pdf$", trimws(gi_lines)))) {
    gi_lines <- c(gi_lines, "*.pdf")
    changed <- TRUE
  }
  if (changed) {
    writeLines(gi_lines, gi_path)
    cli::cli_alert_success("Mise à jour de {.file .gitignore} ({.code _site}, {.code *.pdf})")
  }

  # ---- Résumé ---------------------------------------------------------------
  cli::cli_h2("Résumé")
  cli::cli_li("titre       : {final_title}")
  cli::cli_li("wp          : {if (is.null(wp)) 'brouillon (null)' else wp}")
  cli::cli_li("annee       : {annee}")
  cli::cli_li("version     : v0")
  cli::cli_li("lang        : {lang}")
  cli::cli_li("site-url    : {yml$website$`site-url`}")
  if (!is.null(yml$website$`site-path`))
    cli::cli_li("site-path   : {yml$website$`site-path`}")
  cli::cli_li("hypothesis  : {hypothesis}")
  cli::cli_li("pdf         : {pdf_output}")

  cli::cli_alert_warning(
    "Pensez à {.strong commiter et pousser} les changements avant de \\
     lancer {.run ofceweb::render_wp()}."
  )

  invisible(NULL)
}
