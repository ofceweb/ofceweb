#' Initialise un dépôt de prévision OFCE
#'
#' Copie les gabarits embarqués dans le package (`inst/setup_prev/`) à la
#' racine du dépôt, crée la structure de dossiers attendue, et adapte les
#' fichiers de configuration Quarto (`_quarto.yml`, `_quarto-staging.yml`,
#' `_quarto-publish.yml`) avec l'identifiant de la prévision.
#'
#' La fonction est **non-destructive** pour les fichiers utilisateur (`.qmd`,
#' scripts `data_pays/`) : ils ne sont copiés que s'ils sont absents. En
#' revanche, `_extensions/`, `www/` et les **workflows GitHub Actions** sont
#' **toujours mis à jour** depuis la version de référence du package.
#'
#' @section Structure créée :
#' ```
#' <root>/
#' ├── _quarto.yml              # base commune (ofce_prev, prev, annee, mois)
#' ├── _quarto-staging.yml      # profil staging (site-path, version, encrypt_site)
#' ├── _quarto-publish.yml      # profil publish (site-path, pas de chiffrement)
#' ├── _extensions/             # extensions Quarto OFCE (toujours mis à jour)
#' ├── www/                     # assets statiques (logos, CSS — toujours mis à jour)
#' ├── france/data/             # données France (.gitkeep)
#' ├── inter/data/              # données International (.gitkeep)
#' ├── fiches/data/             # données Analyses Pays (.gitkeep)
#' ├── tableaux_comptes/        # tableaux de comptes nationaux
#' ├── data_pays/               # scripts de données agrégées (non-destructif)
#' └── .github/workflows/
#'     ├── ftp_deploy_staging.yml
#'     └── ftp_deploy_publish.yml
#' ```
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param prev Chaîne à 4 chiffres identifiant la prévision (ex. `"2609"` pour
#'   septembre 2026). Si `NULL` (défaut), déduit automatiquement du nom du
#'   dossier si celui-ci respecte le format `prev{YY}0{3|9}`.
#' @param annee Entier. Année de la prévision. Défaut = année courante. Déduit
#'   du nom du dossier si `prev` est aussi déduit.
#' @param mois Entier. Mois de la prévision : `3` (mars) ou `9` (septembre).
#'   Déduit du nom du dossier si `prev` est aussi déduit.
#' @param encrypt Logique. Si `TRUE` (défaut), positionne `encrypt_site: true`
#'   dans `_quarto-staging.yml` (le chiffrement a lieu en CI).
#' @param versionning Logique. Si `TRUE` (défaut), initialise la version
#'   staging à `"v0"`.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [check_prev()], [render_prev()], [prev_version_up()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists file_copy dir_copy dir_create dir_ls path_rel path_dir
#' @importFrom cli cli_h1 cli_h2 cli_li cli_abort cli_alert_success cli_alert_warning cli_alert_info cli_bullets
#' @importFrom yaml read_yaml write_yaml verbatim_logical
#' @importFrom gert git_remote_list
#' @section Prévision Users:
#'
#' @export
setup_prev <- function(
    path        = ".",
    encrypt     = TRUE,
    versionning = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  if (!fs::dir_exists(root))
    cli::cli_abort("Le dossier {.path {root}} n'existe pas.")

  cli::cli_h1("setup_prev dans {.path {fs::path_file(root)}}")

  # ---- 1. Résolution de l'identifiant prev ---------------------------------
  project <- fs::path_file(root) |> as.character()
  parsed  <- parse_prev_id(project)
  if (!is.null(parsed)) {
    prev  <- parsed$id
    annee <- parsed$annee
    mois  <- parsed$mois
    cli::cli_alert_info("Identifiant prev déduit du dossier : {.val {prev}}")
  } else {
    cli::cli_abort("Abort, impossible de déduire le prev depuis `{project}`. \\
         Préciser {.arg prev}, {.arg annee} et {.arg mois} explicitement.")
  }

  if (!is.null(prev)) {
    prev <- as.character(prev)
    if (!grepl("^[0-9]{4}$", prev))
      cli::cli_abort(
        "{.arg prev} doit être un code à 4 chiffres (ex. {.val '2609'}).")
  }

  annee <- suppressWarnings(as.integer(annee))
  if (is.na(annee))
    cli::cli_abort("{.arg annee} doit être un entier.")

  if (!is.null(mois)) {
    mois <- suppressWarnings(as.integer(mois))
    if (!mois %in% c(3L, 9L))
      cli::cli_abort("{.arg mois} doit être {.val 3} (mars) ou {.val 9} (septembre).")
  }

  # ---- 2. Localisation des gabarits ----------------------------------------
  pkg_setup_prev <- system.file("setup_prev", package = "ofceweb")
  if (!nzchar(pkg_setup_prev))
    pkg_setup_prev <- tryCatch(
      fs::path(find.package("ofceweb"), "inst", "setup_prev"),
      error = function(e) ""
    )
  if (!nzchar(pkg_setup_prev) || !fs::dir_exists(pkg_setup_prev))
    pkg_setup_prev <- fs::path(root, "inst", "setup_prev")  # dev fallback
  if (!fs::dir_exists(pkg_setup_prev))
    cli::cli_abort("Gabarits setup_prev introuvables. Réinstaller {.pkg ofceweb}.")

  pkg_share <- system.file("share", package = "ofceweb")
  if (!nzchar(pkg_share))
    pkg_share <- tryCatch(
      fs::path(find.package("ofceweb"), "inst", "share"),
      error = function(e) ""
    )
  if (!nzchar(pkg_share) || !fs::dir_exists(pkg_share))
    pkg_share <- fs::path(root, "inst", "share")            # dev fallback

  # ---- 3. Lecture des YAML existants ----------------------------------------
  dest_yaml <- fs::path(root, "_quarto.yml")
  dest_stg  <- fs::path(root, "_quarto-staging.yml")
  dest_pub  <- fs::path(root, "_quarto-publish.yml")

  yml <- if (fs::file_exists(dest_yaml))
    tryCatch(yaml::read_yaml(dest_yaml), error = function(e) list())
  else list()

  if (isTRUE(yml[["ofce_wp"]])) {
    cli::cli_abort(c(
      "Ce dépôt est un {.strong document de travail} ({.field ofce_wp: true} dans {.file _quarto.yml}).",
      "i" = "Utilisez {.fn setup_wp} pour initialiser un dépôt de document de travail.",
      "x" = "{.fn setup_prev} ne peut pas être appliqué à un dépôt de document de travail."
    ))
  }

  stg <- if (fs::file_exists(dest_stg))
    tryCatch(yaml::read_yaml(dest_stg), error = function(e) list())
  else list()

  pub <- if (fs::file_exists(dest_pub))
    tryCatch(yaml::read_yaml(dest_pub), error = function(e) list())
  else list()

  # ---- 4. Extensions et www (depuis inst/share/ — toujours mis à jour) -----
  # Les extensions prev spécifiques : ofce/ofce (ofce-html), ofce-website,
  # crossref-listings, social-share, mcanouil/iconify, pandoc-ext.
  # Toutes vivent dans inst/share/_extensions/ pour une mise à jour centralisée.
  if (fs::dir_exists(pkg_share)) {
    dest_ext <- fs::path(root, "_extensions")
    fs::dir_create(dest_ext, recurse = TRUE)

    for (ext_rel in c(
      "ofce-website",
      file.path("ofce", "ofce"),
      file.path("ofce", "social-share"),
      "crossref-listings",
      file.path("mcanouil", "iconify"),
      "social-share",
      file.path("pandoc-ext", "section-bibliographies")
    )) {
      src_e <- fs::path(pkg_share, "_extensions", ext_rel)
      if (fs::dir_exists(src_e)) {
        fs::dir_create(fs::path(dest_ext, fs::path_dir(ext_rel)), recurse = TRUE)
        fs::dir_copy(src_e, fs::path(dest_ext, ext_rel), overwrite = TRUE)
      }
    }
    cli::cli_alert_success("Mise à jour de {.path _extensions/} (depuis share)")

    src_www <- fs::path(pkg_share, "www")
    if (fs::dir_exists(src_www)) {
      dest_www <- fs::path(root, "www")
      fs::dir_create(dest_www, recurse = TRUE)
      for (f in fs::dir_ls(src_www, recurse = FALSE)) {
        if (fs::is_dir(f))
          fs::dir_copy(f, fs::path(dest_www, fs::path_file(f)), overwrite = TRUE)
        else
          fs::file_copy(f, fs::path(dest_www, fs::path_file(f)), overwrite = TRUE)
      }
      cli::cli_alert_success("Mise à jour de {.path www/} (depuis share)")
    }
  }

  # ---- 5. Copie des gabarits .qmd et data_pays/ (non-destructive) ----------
  # Exclut : YAML configs, workflows, _extensions/, www/ (gérés séparément)
  tmpl_files <- fs::dir_ls(pkg_setup_prev, recurse = TRUE, type = "file")
  for (f in tmpl_files) {
    rel  <- fs::path_rel(f, pkg_setup_prev) |> as.character()
    dest <- fs::path(root, rel)

    if (rel %in% c("_quarto.yml", "_quarto-staging.yml", "_quarto-publish.yml"))
      next
    if (grepl("^workflows/", rel))     next
    if (grepl("^_extensions/", rel))   next
    if (grepl("^www/", rel))           next

    if (!fs::file_exists(dest)) {
      fs::dir_create(fs::path_dir(dest), recurse = TRUE)
      fs::file_copy(f, dest)
      cli::cli_alert_success("Copie : {.file {rel}}")
    } else {
      cli::cli_alert_info("{.file {rel}} déjà présent \u2014 non écrasé.")
    }
  }

  # ---- 6. Sous-dossiers data/ + .gitkeep -----------------------------------
  for (sub in c("france", "inter", "fiches")) {
    data_dir <- fs::path(root, sub, "data")
    fs::dir_create(data_dir, recurse = TRUE)
    gk <- fs::path(data_dir, ".gitkeep")
    if (!fs::file_exists(gk)) fs::file_create(gk)
  }
  fs::dir_create(fs::path(root, "tableaux_comptes"), recurse = TRUE)
  dp_dir <- fs::path(root, "data_pays")
  fs::dir_create(dp_dir, recurse = TRUE)
  gk_pays <- fs::path(dp_dir, ".gitkeep")
  if (!fs::file_exists(gk_pays)) fs::file_create(gk_pays)
  cli::cli_alert_success("Sous-dossiers {.code data/} et {.path data_pays/} vérifiés.")

  # ---- 7. site-paths -------------------------------------------------------
  prev_id         <- prev %||% "YYMM"
  staging_version <- if (!is.null(stg$version)) as.character(stg$version)
  else "v0"
  staging_sitepath <- sprintf("staging/prev%s/%s", prev_id, staging_version)
  publish_sitepath <- sprintf("prev/prev%s", prev_id)

  # ---- 8. _quarto.yml (base) -----------------------------------------------
  if (!fs::file_exists(dest_yaml)) {
    fs::file_copy(fs::path(pkg_setup_prev, "_quarto.yml"), dest_yaml)
    yml <- yaml::read_yaml(dest_yaml)
    cli::cli_alert_success("Copie de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} déjà présent \u2014 mise à jour partielle.")
  }

  yml$ofce_prev <- TRUE
  if (!is.null(prev))  yml$prev  <- prev
  if (!is.na(annee))   yml$annee <- annee
  if (!is.null(mois))  yml$mois  <- mois
  yml$website$`site-url` <- "https://www.ofce.fr/"

  # repo-url : calculé depuis le remote git ; sinon construit depuis prev id
  remotes <- tryCatch(gert::git_remote_list(repo = root), error = function(e) NULL)
  if (!is.null(remotes) && nrow(remotes) > 0) {
    o          <- remotes[remotes$name == "origin", , drop = FALSE]
    origin_url <- if (nrow(o) > 0) o$url[[1L]] else remotes$url[[1L]]
    url2       <- sub("\\.git$", "", origin_url)
    m          <- if (grepl("^git@", url2))
      regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1L]]
    else
      regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1L]]
    if (length(m) >= 3L)
      yml$website$`repo-url` <- sprintf("https://github.com/%s/%s/", m[[2L]], m[[3L]])
  }
  if (!is.null(prev)) {
    yml$website$`repo-url` <- sprintf("https://github.com/ofce/prev%s/", prev)
  }

  # Migre project.type: website → ofce-website
  if (!is.null(yml$project$type) && yml$project$type == "website") {
    yml$project$type <- "ofce-website"
    cli::cli_alert_success(
      "{.file _quarto.yml} : {.code project.type} migré vers {.val ofce-website}")
  } else if (is.null(yml$project$type)) {
    yml$project$type <- "ofce-website"
  }

  yaml::write_yaml(yml, dest_yaml,
                   indent.mapping.sequence = TRUE,
                   handlers = list(logical = yaml::verbatim_logical))
  cli::cli_alert_success("Mise à jour de {.file _quarto.yml}")

  # ---- 9. _quarto-staging.yml ----------------------------------------------
  if (!fs::file_exists(dest_stg)) {
    fs::file_copy(fs::path(pkg_setup_prev, "_quarto-staging.yml"), dest_stg)
    stg <- yaml::read_yaml(dest_stg)
    cli::cli_alert_success("Copie de {.file _quarto-staging.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto-staging.yml} déjà présent \u2014 mise à jour.")
  }

  stg$website$`site-path` <- staging_sitepath
  stg$version             <- staging_version
  stg$comments            <- list(hypothesis = TRUE)
  stg$encrypt_site        <- isTRUE(encrypt)
  stg$project             <- list(`output-dir` = "_site_staging")

  yaml::write_yaml(stg, dest_stg,
                   indent.mapping.sequence = TRUE,
                   handlers = list(logical = yaml::verbatim_logical))
  cli::cli_alert_success("Mise à jour de {.file _quarto-staging.yml}")

  # ---- 10. _quarto-publish.yml ---------------------------------------------
  if (!fs::file_exists(dest_pub)) {
    fs::file_copy(fs::path(pkg_setup_prev, "_quarto-publish.yml"), dest_pub)
    pub <- yaml::read_yaml(dest_pub)
    cli::cli_alert_success("Copie de {.file _quarto-publish.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto-publish.yml} déjà présent \u2014 mise à jour.")
  }

  pub$website$`site-path` <- publish_sitepath
  pub$comments            <- list(hypothesis = FALSE)
  pub$encrypt_site        <- FALSE
  pub$project             <- list(`output-dir` = "_site_publish")

  yaml::write_yaml(pub, dest_pub,
                   indent.mapping.sequence = TRUE,
                   handlers = list(logical = yaml::verbatim_logical))
  cli::cli_alert_success("Mise à jour de {.file _quarto-publish.yml}")

  # ---- 11. Workflows (toujours mis à jour depuis le package) ---------------
  src_wf  <- fs::path(pkg_setup_prev, "workflows")
  dest_wf <- fs::path(root, ".github", "workflows")
  if (fs::dir_exists(src_wf)) {
    fs::dir_create(dest_wf, recurse = TRUE)
    for (f in fs::dir_ls(src_wf, type = "file")) {
      fname  <- fs::path_file(f)
      dest_f <- fs::path(dest_wf, fname)
      fs::file_copy(f, dest_f, overwrite = TRUE)
      cli::cli_alert_success("Mise à jour : {.file .github/workflows/{fname}}")
    }
  }

  # ---- 12. Variables GitHub ------------------------------------------------
  staging_dir <- paste0(staging_sitepath, "/") |>
    stringr::str_remove("^staging/")

  publish_dir <- paste0(publish_sitepath, "/") |>
    stringr::str_remove("^prev/")

  tryCatch(
    set_gh_var(root, "FTP_STAGING_DIR", staging_dir),
    error = function(e)
      cli::cli_alert_warning(
        "FTP_STAGING_DIR non définie : {conditionMessage(e)}")
  )
  tryCatch(
    set_gh_var(root, "FTP_PUBLISH_DIR", publish_dir),
    error = function(e)
      cli::cli_alert_warning(
        "FTP_PUBLISH_DIR non définie : {conditionMessage(e)}")
  )

  # ---- 13. .gitignore ------------------------------------------------------
  gi_path      <- fs::path(root, ".gitignore")
  gi_lines     <- if (fs::file_exists(gi_path))
    readLines(gi_path, warn = FALSE) else character()
  tmpl_path    <- system.file("setup_prev/.gitignore", package = "ofceweb")
  tmpl_entries <- readLines(tmpl_path, warn = FALSE)
  tmpl_entries <- tmpl_entries[nzchar(trimws(tmpl_entries))]
  changed      <- FALSE

  for (entry in tmpl_entries) {
    if (!any(trimws(gi_lines) == entry)) {
      gi_lines <- c(gi_lines, entry)
      changed  <- TRUE
    }
  }
  if (changed) {
    writeLines(gi_lines, gi_path)
    cli::cli_alert_success("Mise à jour de {.file .gitignore}")
  }

  # ---- Résumé --------------------------------------------------------------
  cli::cli_h2("Résumé")
  cli::cli_li("prev        : {yml$prev %||% '(non défini)'}")
  cli::cli_li("annee       : {yml$annee}")
  cli::cli_li("mois        : {yml$mois %||% '(non défini)'}")
  cli::cli_li("staging     : {staging_sitepath}")
  cli::cli_li("publish     : {publish_sitepath}")
  cli::cli_li("repo-url    : {yml$website$`repo-url` %||% '(non défini)'}")
  cli::cli_li("encrypt     : {isTRUE(encrypt)}")

  cli::cli_alert_info(
    "Définir le secret GitHub {.code STATICRYPT_PASSWORD} : \\
     {.code gh secret set STATICRYPT_PASSWORD}")
  cli::cli_bullets(c(
    ">" = "Commiter et pusher avant de lancer \\
           {.run ofceweb::render_prev()}."
  ))

  invisible(NULL)
}


# ---------------------------------------------------------------------------
# Helper interne : parse l'id prev depuis le nom du dossier
# Format attendu : prev{YY}0{3|9}  ex. prev2609, prev2603
# ---------------------------------------------------------------------------
parse_prev_id <- function(project_name) {
  m <- regmatches(
    project_name,
    regexec("^prev([0-9]{2})(0[39])$", project_name)
  )[[1L]]
  if (length(m) < 3L) return(NULL)
  list(
    id    = paste0(m[[2L]], m[[3L]]),          # "2609"
    annee = as.integer(paste0("20", m[[2L]])), # 2026
    mois  = as.integer(m[[3L]])                # 9
  )
}
