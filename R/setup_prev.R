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
#' Les extensions Quarto OFCE (`_extensions/`) sont installées/mises à jour
#' via [ofce::setup_quarto()], qui les récupère depuis le dépôt GitHub
#' `OFCE/ofce-quarto-extensions` — un accès réseau est donc nécessaire.
#' D'éventuelles extensions périmées (installées par une version antérieure
#' du package) sont signalées par un avertissement, jamais supprimées
#' automatiquement.
#'
#' @section Structure créée :
#' ```
#' <root>/
#' ├── _quarto.yml              # base commune (ofce_prev, prev, annee, mois)
#' ├── _quarto-staging.yml      # profil staging (site-path, version, encrypt_site)
#' ├── _quarto-publish.yml      # profil publish (site-path, pas de chiffrement)
#' ├── _extensions/             # extensions Quarto OFCE (via ofce::setup_quarto())
#' ├── www/                     # assets statiques (logos, CSS — toujours mis à jour)
#' ├── france/data/             # données France (.gitkeep)
#' ├── inter/data/              # données International (.gitkeep)
#' ├── fiches/data/             # données Analyses Pays (.gitkeep)
#' ├── tableaux_comptes/        # tableaux de comptes nationaux
#' ├── data_pays/               # scripts de données agrégées (non-destructif)
#' └── .github/workflows/
#'     ├── ftp_deploy_staging.yml
#'     ├── ftp_deploy_publish.yml
#'     └── ftp_deploy_profile.yml
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
#' @seealso [check_prev()], [render_prev()], [prev_version_up()], [update_navbar()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists file_copy dir_copy dir_create dir_ls path_rel path_dir
#' @importFrom cli cli_h1 cli_h2 cli_li cli_abort cli_alert_success cli_alert_warning cli_alert_info cli_bullets
#' @importFrom yaml read_yaml
#' @importFrom gert git_remote_list
#' @importFrom gh gh
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

  check_quarto_version()

  # ---- 0. connexion GitHub / DEPLOY_PAT / identite git ---------------------
  check_gh_setup(root)

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

  # ---- 3b. polices Google (thèmes OFCE) ------------------------------------
  tryCatch(
    check_fonts(quiet = TRUE),
    error = function(e)
      cli::cli_alert_warning("{.fn check_fonts} a \u00e9chou\u00e9 : {conditionMessage(e)}")
  )

  # ---- 4. Extensions Quarto OFCE (source de vérité : ofce::setup_quarto()) --
  tryCatch({
    ofce::setup_quarto(root, quiet = TRUE)
    # `ofce::setup_quarto()` peut réussir (exit code 0) sans avoir réellement
    # posé les fichiers attendus : on vérifie donc la présence effective du
    # dossier, plutôt que de se fier uniquement à l’absence d’erreur R.
    if (fs::dir_exists(fs::path(root, "_extensions", "ofce"))) {
      cli::cli_alert_success(
        "Extensions Quarto OFCE install\u00e9es/mises \u00e0 jour ({.fn ofce::setup_quarto})."
      )
    } else {
      cli::cli_alert_warning(
        "{.fn ofce::setup_quarto} n'a signal\u00e9 aucune erreur mais \
         {.path _extensions/ofce/} est absent \u2014 v\u00e9rifier la connexion \
         r\u00e9seau et l'installation de Quarto ({.code quarto check})."
      )
    }
  }, error = function(e) {
    cli::cli_alert_warning("{.fn ofce::setup_quarto} a \u00e9chou\u00e9 : {conditionMessage(e)}")
  })
  check_stray_ofce_extensions(root)

  # ---- 4b. www/ (depuis inst/share/ — toujours mis à jour) -----------------
  if (fs::dir_exists(pkg_share)) {
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
  staging_sitepath <- sprintf("prev%s/%s", prev_id, staging_version)
  publish_sitepath <- sprintf("prev/prev%s", prev_id)

  # ---- 8. _quarto.yml (base) -----------------------------------------------
  if (!fs::file_exists(dest_yaml)) {
    fs::file_copy(fs::path(pkg_setup_prev, "_quarto.yml"), dest_yaml)
    yml <- yaml::read_yaml(dest_yaml)
    cli::cli_alert_success("Copie de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} déjà présent \u2014 mise à jour partielle.")
  }

  # Patch textuel : préserve commentaires, indentation et mise en page du
  # reste du fichier.
  lines_before <- readLines(dest_yaml, warn = FALSE)
  lines <- lines_before

  yml$ofce_prev <- TRUE
  lines <- yaml_patch_scalar(lines, "ofce_prev", TRUE)

  # favicon : asset géré par le package — toujours resynchronisé, même sur
  # un _quarto.yml existant.
  yml$website$favicon <- "www/fofce-prev.png"
  lines <- yaml_patch_scalar(lines, "website.favicon", "www/fofce-prev.png")

  # draft-mode : toujours resynchronisé, même sur un _quarto.yml existant qui
  # aurait été créé avant l’introduction de cette clé.
  yml$website$`draft-mode` <- "visible"
  lines <- yaml_patch_scalar(lines, "website.draft-mode", "visible")

  if (!is.null(prev))  { yml$prev  <- prev;  lines <- yaml_patch_scalar(lines, "prev", prev) }
  if (!is.na(annee))   { yml$annee <- annee; lines <- yaml_patch_scalar(lines, "annee", annee) }
  if (!is.null(mois))  { yml$mois  <- mois;  lines <- yaml_patch_scalar(lines, "mois", mois) }
  yml$website$`site-url` <- "https://www.ofce.fr/"
  lines <- yaml_patch_scalar(lines, "website.site-url", "https://www.ofce.fr/")

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
  if (!is.null(yml$website$`repo-url`))
    lines <- yaml_patch_scalar(lines, "website.repo-url", yml$website$`repo-url`)

  # Migre project.type: website → ofce-website
  if (!is.null(yml$project$type) && yml$project$type == "website") {
    yml$project$type <- "ofce-website"
    lines <- yaml_patch_scalar(lines, "project.type", "ofce-website")
    cli::cli_alert_success(
      "{.file _quarto.yml} : {.code project.type} migré vers {.val ofce-website}")
  } else if (is.null(yml$project$type)) {
    yml$project$type <- "ofce-website"
    lines <- yaml_patch_scalar(lines, "project.type", "ofce-website")
  }

  if (!identical(lines_before, lines)) {
    writeLines(lines, dest_yaml)
    cli::cli_alert_success("Mise à jour de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} — aucun changement nécessaire.")
  }

  # ---- 8b. navbar (source centralisée du package) --------------------------
  tryCatch(
    update_navbar(root),
    error = function(e)
      cli::cli_alert_warning("update_navbar() a échoué : {conditionMessage(e)}")
  )

  # ---- 9. _quarto-staging.yml ----------------------------------------------
  if (!fs::file_exists(dest_stg)) {
    fs::file_copy(fs::path(pkg_setup_prev, "_quarto-staging.yml"), dest_stg)
    stg <- yaml::read_yaml(dest_stg)
    cli::cli_alert_success("Copie de {.file _quarto-staging.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto-staging.yml} déjà présent \u2014 mise à jour.")
  }

  stg$website$`site-url`  <- "https://staging.ofce.fr/"
  stg$website$`site-path` <- staging_sitepath
  stg$version             <- staging_version
  stg$comments            <- list(hypothesis = TRUE)
  stg$encrypt_site        <- isTRUE(encrypt)
  stg$project             <- list(`output-dir` = "_site_staging")

  stg_lines_before <- readLines(dest_stg, warn = FALSE)
  stg_lines <- stg_lines_before
  stg_lines <- yaml_patch_scalar(stg_lines, "website.site-url", "https://staging.ofce.fr/")
  stg_lines <- yaml_patch_scalar(stg_lines, "website.site-path", staging_sitepath)
  stg_lines <- yaml_patch_scalar(stg_lines, "version", staging_version)
  stg_lines <- yaml_patch_block(stg_lines, "comments", list(hypothesis = TRUE))
  stg_lines <- yaml_patch_scalar(stg_lines, "encrypt_site", isTRUE(encrypt))
  stg_lines <- yaml_patch_block(stg_lines, "project", list(`output-dir` = "_site_staging"))

  if (!identical(stg_lines_before, stg_lines)) {
    writeLines(stg_lines, dest_stg)
    cli::cli_alert_success("Mise à jour de {.file _quarto-staging.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto-staging.yml} — aucun changement nécessaire.")
  }

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

  pub_lines_before <- readLines(dest_pub, warn = FALSE)
  pub_lines <- pub_lines_before
  pub_lines <- yaml_patch_scalar(pub_lines, "website.site-path", publish_sitepath)
  pub_lines <- yaml_patch_block(pub_lines, "comments", list(hypothesis = FALSE))
  pub_lines <- yaml_patch_scalar(pub_lines, "encrypt_site", FALSE)
  pub_lines <- yaml_patch_block(pub_lines, "project", list(`output-dir` = "_site_publish"))

  if (!identical(pub_lines_before, pub_lines)) {
    writeLines(pub_lines, dest_pub)
    cli::cli_alert_success("Mise à jour de {.file _quarto-publish.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto-publish.yml} — aucun changement nécessaire.")
  }

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
  # staging_sitepath ne porte plus de préfixe "staging/" (segment absorbé par
  # le sous-domaine staging.ofce.fr) — correspond déjà au chemin FTP relatif
  # {repo}/{version}/ attendu par le chroot www/staging/ de l'utilisateur FTP.
  staging_dir <- paste0(staging_sitepath, "/")

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
