#' Initialise un dépôt de document de travail (WP) OFCE
#'
#' Copie les gabarits embarqués dans le package (`inst/setup_wp/`) à la racine
#' du dépôt, initialise la branche `gh-pages` pour la pré-publication, et
#' adapte le `_quarto.yml` avec les métadonnées du WP (titre, numéro, année,
#' langue, URLs).
#'
#' La fonction est **non-destructive** : sur un dépôt existant, les fichiers
#' gabarits (dont `_quarto.yml`) ne sont pas écrasés, et les champs YAML ne
#' sont mis à jour que si l'argument correspondant a été fourni explicitement.
#' Les champs déjà absents ne sont pas injectés. Seuls `repo-url` et
#' `ofce_wp: true` sont toujours positionnés (valeurs dérivées sans ambiguïté).
#'
#' Pour les WPs publiés (`wp` non nul), la fonction met à jour la variable
#' GitHub Actions `FTP_SERVER_DIR` (publique, visible dans Settings → Variables)
#' à partir du `site-path` du `_quarto.yml`. Le workflow `ftp_deploy.yml` est
#' aussi migré automatiquement si `server-dir` y est encore codé en dur.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param website_title Chaîne ou `NULL`. Titre du WP. Si `NULL`, utilise le
#'   nom du dépôt GitHub.
#' @param wp Entier ou `NULL`. Numéro du WP. `NULL` = brouillon (pré-publication
#'   GitHub Pages) ; entier = WP publié (hébergement OFCE FTP).
#' @param annee Entier. Année de publication. Défaut = année courante.
#' @param lang Chaîne. Langue principale : `"fr"` (défaut) ou `"en"`.
#' @param hypothesis Logique. Active les commentaires Hypothesis. Défaut `FALSE`.
#' @param versionning Logique. Si `TRUE` et WP publié (`wp` non `NULL`),
#'   ajoute `/v0` au `site-path`.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [render_wp()], [deploy_wp()], [wp_version_up()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists file_copy dir_copy dir_create dir_ls path_ext path_ext_remove
#' @importFrom cli cli_h1 cli_h2 cli_li cli_abort cli_alert_success cli_alert_warning cli_alert_info
#' @importFrom yaml read_yaml write_yaml verbatim_logical
#' @importFrom gert git_remote_list
#' @section Working Paper (WP) Users:
#'
#' @export
setup_wp <- function(
    path = ".",
    website_title = NULL,
    wp = NULL,
    annee = as.integer(format(Sys.Date(), "%Y")),
    lang = "fr",
    hypothesis = NULL,
    versionning = NULL) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  if (!fs::dir_exists(root))
    cli::cli_abort("Le dossier {.path {root}} n'existe pas.")

  cli::cli_h1("setup_wp dans {.path {fs::path_file(root)}}")

  # Détecter les arguments fournis explicitement (avant toute modification)
  wp_provided         <- !missing(wp)
  annee_provided      <- !missing(annee)
  lang_provided       <- !missing(lang)
  title_provided      <- !missing(website_title)
  hypothesis_provided <- !missing(hypothesis)
  version_provided    <- !missing(versionning)

  # Vérifier si les arguments ne sont pas dans un yml
  dest_yaml <- fs::path(root, "_quarto.yml")
  dest_index <- fs::path(root, "index.qmd")
  yml <- yaml::read_yaml(dest_yaml)

  if (isTRUE(yml[["ofce_prev"]])) {
    cli::cli_abort(c(
      "Ce dépôt est une {.strong prévision} ({.field ofce_prev: true} dans {.file _quarto.yml}).",
      "i" = "Utilisez {.fn setup_prev} pour initialiser un dépôt de prévision.",
      "x" = "{.fn setup_wp} ne peut pas être appliqué à un dépôt de prévision."
    ))
  }

  if(file.exists(dest_index))
    index_yml <- get_yaml(dest_index) else
      index_yml <- list()
  yml_before <- yml  # snapshot pour détecter les changements réels

  if(!is.null(yml[["wp"]])&&!wp_provided) {
    wp <- yml[["wp"]]
    wp_provided <- TRUE
  }
  if(!is.null(yml[["annee"]])&&!annee_provided) {
    annee <- yml[["annee"]]
    annee_provided <- TRUE
  }
  if(!is.null(yml[["lang"]])&&!lang_provided) {
    lang <- yml[["lang"]]
    lang_provided <- TRUE
  }
  if(is.null(yml[["lang"]])&&!lang_provided) {
    lang <- "fr"
    lang_provided <- TRUE
  }
  if(!is.null(yml[["website"]][["title"]])&&!title_provided) {
    title_provided <- TRUE
    website_title <- yml[["website"]][["title"]]
  } else {
    if(!is.null(index_yml[["title"]])){
      title_provided <- TRUE
      website_title <- index_yml[["title"]]
    }
  }
  if(!is.null(yml[["comment"]][["hypothesis"]])&&!hypothesis_provided) {
    hypothesis_provided <- TRUE
    hypothesis <- yml[["comment"]][["hypothesis"]]
  }
  if(is.null(yml[["comment"]][["hypothesis"]])&&!hypothesis_provided) {
    hypothesis_provided <- TRUE
    hypothesis <- is.null(wp)
  }
  if(hypothesis_provided){
      hypothesis <- isTRUE(hypothesis)
    }
  version <- yml[["version"]]
  if(version_provided & is.null(yml[["version"]]) & isTRUE(versionning))
    version <- "v0"

  if(!version_provided & !is.null(yml[["version"]])) {
    version_provided <- TRUE
    versionning <- TRUE
  }

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
    if (is.null(url)) return(list(owner = NA_character_, repo = NA_character_))
    url2 <- sub("\\.git$", "", url)
    if (grepl("^git@", url2)) {
      m <- regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
    } else {
      m <- regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
    }
    if (length(m) < 3) return(list(owner = NA_character_, repo = NA_character_))
    list(owner = m[[2]], repo = m[[3]])
  }

  gh     <- parse_remote_wp(origin_url)
  repo_name <- if (is.na(gh$repo)) fs::path_file(root) else gh$repo
  gh_org    <- if (is.na(gh$owner)) "ofce" else gh$owner

  # ---- 3. titre du WP -------------------------------------------------------
  final_title <- if (!is.null(website_title) && nzchar(website_title)) {
    website_title
  } else {
    repo_name
  }

  # ---- 4. localisation des gabarits -----------------------------------------
  pkg_setup_wp   <- system.file("setup_wp",   package = "ofceweb")
  pkg_share <- system.file("share", package = "ofceweb")
  if (!nzchar(pkg_setup_wp))
    pkg_setup_wp <- fs::path(find.package("ofceweb"), "inst", "setup_wp")
  if (!nzchar(pkg_setup_wp))
    pkg_setup_wp <- fs::path(root, "inst", "setup_wp")   # dev fallback
  if (!nzchar(pkg_share))
    pkg_share <- fs::path(root, "inst", "share")

  # ---- 5. copie _quarto.yml (seulement si absent) ---------------------------
  src_yaml  <- fs::path(pkg_setup_wp, "_quarto.yml")
  if (!fs::file_exists(dest_yaml)) {
    fs::file_copy(src_yaml, dest_yaml, overwrite = FALSE)

    cli::cli_alert_success("Copie de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} déjà présent — non écrasé.")
  }

  # ---- 6. copie index.qmd (si absent) ---------------------------------------
  src_index    <- fs::path(pkg_setup_wp, "index.qmd")
  dest_index   <- fs::path(root, "index.qmd")
  created_index <- !fs::file_exists(dest_index)
  if (created_index) {
    fs::file_copy(src_index, dest_index, overwrite = FALSE)
    index_yml <- get_yaml(dest_index)
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

  # ---- 8. copie www/ depuis share/ ------------------------------------
  src_www <- fs::path(pkg_share, "www")
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
  src_ext_wp <- fs::path(pkg_share, "_extensions", "wp")
  if (fs::dir_exists(src_ext_wp)) {
    dest_ext <- fs::path(root, "_extensions")
    dest_ext_wp <- fs::path(dest_ext, "wp")
    fs::dir_create(dest_ext)
    fs::dir_copy(src_ext_wp, dest_ext_wp, overwrite = TRUE)
    cli::cli_alert_success("Copie de {.path _extensions/wp/}")
  }

  # ---- 10. copie des workflows (seulement si absents) -----------------------
  src_wf  <- fs::path(pkg_setup_wp, "workflows")
  dest_wf <- fs::path(root, ".github", "workflows")
  if (fs::dir_exists(src_wf)) {
    fs::dir_create(dest_wf, recurse = TRUE)
    n_copied <- 0L
    for (f in fs::dir_ls(src_wf, type = "file")) {
      fname <- fs::path_file(f)
      if (fs::path_ext(fname) == "html") fname <- fs::path_ext_remove(fname)
      dest_f <- fs::path(dest_wf, fname)
      if (!fs::file_exists(dest_f)) {
        fs::file_copy(f, dest_f, overwrite = FALSE)
        n_copied <- n_copied + 1L
      } else {
        cli::cli_alert_info("{.file .github/workflows/{fname}} déjà présent — non écrasé.")
      }
    }
    if (n_copied > 0L)
      cli::cli_alert_success("Copie de {n_copied} workflow{?s} vers {.path .github/workflows/}")
  }

  # ---- 10b. migration server-dir → ${{ vars.FTP_SERVER_DIR }} ---------------
  # Idempotent : remplace la ligne codée en dur dans les workflows existants
  # par la référence à la variable GitHub. N'écrase pas un fichier déjà migré.
  ftp_wf <- fs::path(dest_wf, "ftp_deploy.yml")
  if (fs::file_exists(ftp_wf)) {
    wf_lines <- readLines(ftp_wf, warn = FALSE)
    needs_migration <- any(grepl("server-dir:", wf_lines)) &&
      !any(grepl("vars\\.FTP_SERVER_DIR", wf_lines))
    if (needs_migration) {
      wf_lines <- sub(
        "^(\\s*)server-dir:.*$",
        "\\1server-dir: ${{ vars.FTP_SERVER_DIR }}",
        wf_lines
      )
      writeLines(wf_lines, ftp_wf)
      cli::cli_alert_success(
        "{.file .github/workflows/ftp_deploy.yml} migré vers {.code {{vars.FTP_SERVER_DIR}}}"
      )
    }
  }

  # ---- 11. édition du _quarto.yml ------------------------------------------

  # Champs-arguments : écrire UNIQUEMENT si l'argument a été fourni explicitement.
  # Pour un nouveau WP, le gabarit contient déjà les valeurs par défaut.
  # Pour un WP existant, l'absence d'un champ est intentionnelle.
  if (wp_provided)    yml$wp    <- wp
  if (annee_provided) yml$annee <- annee
  if (lang_provided)  yml$lang  <- lang
  if (title_provided) yml[["website"]][["title"]] <- final_title
  if (hypothesis_provided) yml[["comments"]][["hypothesis"]] <- hypothesis
  # version : le gabarit le fournit pour les nouveaux WPs — jamais injecté
  # dans un fichier existant.

  # ofce_wp : marqueur de dépôt WP OFCE — toujours positionné
  yml$ofce_wp <- TRUE

  # repo-url : toujours calculé depuis le remote git (valeur dérivée, sans
  # ambiguïté et sans risque pour l'utilisateur)
  if (!is.na(gh$owner) && !is.na(gh$repo)) {
    yml$website$`repo-url` <- sprintf("https://github.com/%s/%s/", gh$owner, gh$repo)
  }

  # site-url / site-path : uniquement si wp a été fourni explicitement
  if (wp_provided) {
    if (!is.null(wp)) {
      # Année effective : yml$annee est déjà à jour (mis à jour ligne 233 si
      # annee_provided, sinon valeur existante du YAML, sinon argument par défaut).
      effective_annee_sp <- suppressWarnings(as.integer(yml$annee %||% annee))
      if (is.na(effective_annee_sp)) effective_annee_sp <- annee
      yml$website$`site-url`  <- "https://www.ofce.fr/"
      site_path_base <- sprintf("%d/%03d", effective_annee_sp, wp)
      if (isTRUE(versionning))
        site_path <- paste0(site_path_base, "/", version)
      else
        site_path <- site_path_base
      yml$version <- version
      yml$website$`site-path` <- site_path
    } else {
      yml$version <- NULL
      yml$website$`site-url`  <- sprintf("https://%s.github.io/%s/", gh_org, repo_name)
      yml$website$`site-path` <- NULL
    }
  }

  # citation.url : URL stable (sans version) — valeur dérivée, toujours mise
  # à jour pour les WPs publiés afin que les citations ne se brisent pas lors
  # des mises à jour de version.
  if (!is.null(yml$wp)) {
    sp <- yml$website$`site-path`
    su <- yml$website$`site-url` %||% ""
    if (!is.null(sp) && nzchar(sp)) {
      # Strip version segment only if present (e.g. /v0, /v1)
      stable_path <- if (grepl("/v\\d+$", sp)) sub("/v\\d+$", "", sp) else sp
      if (!grepl("/$", su)) su <- paste0(su, "/")
      stable_url <- paste0(su, stable_path, "/")
      if (is.null(yml$citation)) yml$citation <- list()
      yml$citation$url <- stable_url
    }
  }

  # hypothesis : uniquement si fourni explicitement
  if (hypothesis_provided) {
    yml$comments <- list(hypothesis = isTRUE(hypothesis))
  }

  # output-file PDF : uniquement si wp ou annee fournis explicitement ET si le
  # format wp-pdf ou wp-typst est déjà déclaré dans le YAML (ne pas injecter
  # un format que le WP n'utilise pas)
  uses_wp_pdf <- is.list(index_yml$format) &&
    (is.list(index_yml$format$`wp-pdf`) || is.list(index_yml$format$`wp-typst`))
  if ((wp_provided || annee_provided) && uses_wp_pdf) {
    effective_wp    <- if (wp_provided)    wp    else yml$wp
    effective_annee <- if (annee_provided) annee else as.integer(yml$annee)
    pdf_output <- if (!is.null(effective_wp)) {
      sprintf("OFCEWP%d-%d.pdf", effective_annee, effective_wp)
    } else {
      "OFCEWP-draft.pdf"
    }
    target_fmt <- if (is.list(index_yml$format$`wp-pdf`)) "wp-pdf" else "wp-typst"
    index_yml$format[[target_fmt]]$`output-file` <- pdf_output
  } else {
    pdf_output <- index_yml$format$`wp-pdf`$`output-file` %||%
      index_yml$format$`wp-typst`$`output-file` %||% NA_character_
  }

  # N'écrire le fichier que si le YAML a réellement changé — évite le
  # reformatage parasite (dates, order des clés, etc.)
  if (!identical(yml_before, yml)) {
    yaml::write_yaml(
      yml, dest_yaml,
      indent.mapping.sequence = TRUE,
      handlers = list(logical = yaml::verbatim_logical)
    )
    cli::cli_alert_success("Mise à jour de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} — aucun changement nécessaire.")
  }

  # Met aussi à jour l'output-file dans index.qmd
  if (TRUE) {
    tryCatch({
      if (is.null(index_yml)) index_yml <- list()
      if (is.null(index_yml$format)) index_yml$format <- list()
      if (is.null(index_yml$format$`wp-pdf`)) index_yml$format$`wp-pdf` <- list()
      index_yml$format$`wp-pdf`$`output-file` <- pdf_output
      put_yaml(index_yml, dest_index)
      cli::cli_alert_success("output-file mis à jour dans {.file index.qmd}")
    }, error = function(e) {
      cli::cli_alert_warning("Impossible de patcher index.qmd : {conditionMessage(e)}")
    })
  }

  # ---- 12. server-dir dans le workflow FTP ----------------------------------
  # yml$wp est la valeur effective : argument fourni (mis à jour en section 11)
  # ou valeur déjà présente dans le YAML. NULL uniquement pour les brouillons.
  if (!is.null(yml$wp)) {
    yml_after  <- tryCatch(yaml::read_yaml(dest_yaml), error = function(e) NULL)
    server_dir <- yml_after$website$`site-path`
    if (!is.null(server_dir) && nzchar(server_dir)) {
      if (!grepl("/$", server_dir)) server_dir <- paste0(server_dir, "/")
      set_gh_var(root, "FTP_SERVER_DIR", server_dir)
      # URL stable : répertoire parent du site-path (sans le segment de version)
      server_dir_clean <- sub("/$", "", server_dir)
      redirect_dir <- if (grepl("/v\\d+$", server_dir_clean)) {
        paste0(sub("/v\\d+$", "", server_dir_clean), "/")
      } else {
        paste0(server_dir_clean, "/")
      }
      set_gh_var(root, "FTP_REDIRECT_DIR", redirect_dir)
    }
  }

  # ---- 13. .gitignore -------------------------------------------------------
  gi_path      <- fs::path(root, ".gitignore")
  gi_lines     <- if (fs::file_exists(gi_path)) readLines(gi_path, warn = FALSE) else character()
  tmpl_path    <- system.file("setup_wp/.gitignore", package = "ofceweb")
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

  # ---- Résumé ---------------------------------------------------------------
  cli::cli_h2("Résumé")
  cli::cli_li("titre       : {yml$website$title}")
  cli::cli_li("wp          : {if (is.null(yml$wp)) 'brouillon (null)' else yml$wp}")
  cli::cli_li("annee       : {yml$annee}")
  cli::cli_li("version     : {yml$version}")
  cli::cli_li("lang        : {yml[['lang']]}")
  cli::cli_li("site-url    : {yml$website$`site-url`}")
  if (!is.null(yml$website$`site-path`))
    cli::cli_li("site-path   : {yml$website$`site-path`}")
  if (!is.null(yml$citation$url))
    cli::cli_li("citation url: {yml$citation$url}")
  cli::cli_li("hypothesis  : {isTRUE(yml$comments$hypothesis)}")
  cli::cli_li("pdf         : {if (is.na(pdf_output)) '(non applicable)' else pdf_output}")

  cli::cli_bullets(
    c(
      ">" = "{.emph commiter} et {.emph pusher} les changements avant de lancer {.run ofceweb::render_wp()}."
  ))

  invisible(NULL)
}
