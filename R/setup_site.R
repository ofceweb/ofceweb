#' Initialise un site OFCE dans le dépôt courant
#'
#' Scanne les fichiers `.qmd` du dépôt, copie les gabarits embarqués dans le
#' package (`inst/setup_site/`) à la racine du dépôt, puis adapte le
#' `_quarto.yml` en fonction des arguments (hébergement OFCE ou GitHub Pages,
#' titre, code de site, commentaires hypothesis, etc.).
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param ofce_host Logique. Si `TRUE` (défaut), le site est hébergé sur les
#'   serveurs OFCE (`site-url = https://www.ofce.fr/`). Si `FALSE`, le site est
#'   publié via GitHub Pages et le `site-url` est dérivé du remote `origin`.
#' @param ofce_server_location Chaîne. Emplacement sur le serveur OFCE,
#'   utilisé comme préfixe du `site-path`. Défaut `"staging"`.
#' @param website_code Chaîne ou `NULL`. Code court du site (lettres, chiffres,
#'   underscores uniquement). Si invalide, retombe sur `NULL`. Si `NULL`, on
#'   utilise le nom du dépôt GitHub.
#' @param website_title Chaîne ou `NULL`. Titre du site. Si `NULL`, on prend le
#'   titre de `index.qmd` s'il existe, sinon le nom du dépôt.
#' @param hypothesis Logique. Active ou non les commentaires hypothesis dans le
#'   `_quarto.yml`. Défaut `TRUE`.
#' @param versionning Logique. Si `TRUE` (défaut) et `ofce_host = TRUE`, ajoute
#'   un segment `/v0` au `site-path`. Voir [site_version_up()] pour incrémenter.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @importFrom fs path_expand path_abs path_norm path_file path path_rel path_ext_set path_ext_remove path_ext file_exists dir_exists file_copy dir_copy dir_create dir_ls
#' @importFrom cli cli_h1 cli_h2 cli_li cli_abort cli_alert_success cli_alert_warning cli_alert_danger cli_alert_info cli_text
#' @importFrom yaml read_yaml write_yaml verbatim_logical
#' @importFrom gert git_remote_list
#' @export
setup_site <- function(
    path = ".",
    ofce_host = TRUE,
    ofce_server_location = "staging",
    website_code = NULL,
    website_title = NULL,
    hypothesis = TRUE,
    versionning = TRUE) {

  root <- getwd()

  if(!dir.exists(root))
    cli::cli_abort("Le dossier {.path {root}} n'existe pas.")

  cli::cli_h1("setup_site dans {.path {fs::path_file(root)}}")

  # ---- 0. branche gh-pages (ofce_host = FALSE) ----------------------------
  # Fait avant la copie des gabarits pour que le working tree soit propre.
  if(!isTRUE(ofce_host)) {
    init_gh_pages_branch(root)
  }

  # ---- 1. scan des qmds ---------------------------------------------------
  qmds <- fs::dir_ls(root, recurse = TRUE, glob = "*.qmd", type = "file")
  qmds <- qmds[!grepl("^_", fs::path_file(qmds))]
  qmds <- unname(qmds)

  if(length(qmds) == 0)
    cli::cli_alert_warning("Aucun fichier .qmd trouvé dans le dépôt.")

  qmd_info <- lapply(qmds, function(p) {
    title <- tryCatch({
      y <- get_yaml(p)
      if(is.list(y) && !is.null(y$title)) as.character(y$title) else NA_character_
    }, error = function(e) NA_character_)
    if(is.na(title) || !nzchar(title))
      title <- fs::path_ext_remove(fs::path_file(p))
    rel <- fs::path_rel(p, root)
    list(
      path = unname(p),
      rel  = unname(rel),
      href = unname(as.character(fs::path_ext_set(rel, "html"))),
      title = unname(title),
      file = unname(fs::path_file(p))
    )
  })

  has_index <- any(vapply(qmd_info, function(x) tolower(x$file) == "index.qmd",
                          logical(1)))

  # ---- 2. copie des gabarits ---------------------------------------------
  pkg_root <- system.file("setup_site", package = "ofceweb")
  if(!nzchar(pkg_root))
    pkg_root <- fs::path(root, "inst", "setup_site") # dev fallback

  src_yaml       <- fs::path(pkg_root, "_quarto.yml")
  src_index      <- fs::path(pkg_root, "index.qmd")
  src_www        <- fs::path(pkg_root, "www")
  src_workflows  <- fs::path(pkg_root, "workflows")
  src_extensions <- fs::path(pkg_root, "_extensions")

  dest_yaml <- fs::path(root, "_quarto.yml")
  fs::file_copy(src_yaml, dest_yaml, overwrite = TRUE)
  cli::cli_alert_success("Copie de {.file _quarto.yml}")

  if(!has_index) {
    fs::file_copy(src_index, fs::path(root, "index.qmd"), overwrite = TRUE)
    cli::cli_alert_success("Copie de {.file index.qmd} (aucun index existant)")
    qmd_info <- c(qmd_info, list(list(
      path = unname(fs::path(root, "index.qmd")),
      rel  = "index.qmd",
      href = "index.html",
      title = "Page d'accueil",
      file = "index.qmd"
    )))
  }

  if(fs::dir_exists(src_www)) {
    dest_www <- fs::path(root, "www")
    fs::dir_create(dest_www)
    src_www_files <- fs::dir_ls(src_www, recurse = FALSE)
    for(f in src_www_files) {
      if(fs::dir_exists(f)) {
        fs::dir_copy(f, fs::path(dest_www, fs::path_file(f)), overwrite = TRUE)
      } else {
        fs::file_copy(f, fs::path(dest_www, fs::path_file(f)), overwrite = TRUE)
      }
    }
    cli::cli_alert_success("Copie du dossier {.path www/}")
  }

  if(fs::dir_exists(src_extensions)) {
    dest_extensions <- fs::path(root, "_extensions")
    fs::dir_create(dest_extensions)
    src_ext_files <- fs::dir_ls(src_extensions, recurse = FALSE)
    for(f in src_ext_files) {
      if(fs::dir_exists(f)) {
        fs::dir_copy(f, fs::path(dest_extensions, fs::path_file(f)),
                     overwrite = TRUE)
      } else {
        fs::file_copy(f, fs::path(dest_extensions, fs::path_file(f)),
                      overwrite = TRUE)
      }
    }
    cli::cli_alert_success("Copie du dossier {.path _extensions/}")
  }

  if(fs::dir_exists(src_workflows)) {
    dest_workflows <- fs::path(root, ".github", "workflows")
    fs::dir_create(dest_workflows, recurse = TRUE)
    wf_files <- fs::dir_ls(src_workflows, type = "file")
    for(f in wf_files) {
      target_name <- fs::path_file(f)
      # strip .html suffix used to keep files in the package source
      if(fs::path_ext(target_name) == "html")
        target_name <- fs::path_ext_remove(target_name)
      fs::file_copy(f, fs::path(dest_workflows, target_name),
                    overwrite = TRUE)
    }
    cli::cli_alert_success("Copie des workflows vers {.path .github/workflows/}")
  }

  # ---- 3. infos dépôt git -------------------------------------------------
  remotes <- tryCatch(gert::git_remote_list(repo = root),
                      error = function(e) NULL)
  origin_url <- NULL
  if(!is.null(remotes) && nrow(remotes) > 0) {
    o <- remotes[remotes$name == "origin", , drop = FALSE]
    if(nrow(o) > 0) origin_url <- o$url[[1]]
    else origin_url <- remotes$url[[1]]
  }

  parse_remote <- function(url) {
    if(is.null(url)) return(list(host = NA_character_, repo = NA_character_))
    # accept https://github.com/owner/repo(.git) or git@github.com:owner/repo(.git)
    url2 <- sub("\\.git$", "", url)
    if(grepl("^git@", url2)) {
      m <- regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
    } else {
      m <- regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
    }
    if(length(m) < 3) return(list(host = NA_character_, repo = NA_character_))
    list(host = m[[2]], repo = m[[3]])
  }

  gh <- parse_remote(origin_url)
  repo_name <- if(is.na(gh$repo)) fs::path_file(root) else gh$repo

  # ---- 4. validation website_code ----------------------------------------
  if(!is.null(website_code)) {
    if(!is.character(website_code) || length(website_code) != 1 ||
       !grepl("^[A-Za-z0-9_]+$", website_code)) {
      cli::cli_alert_warning(
        "website_code invalide, doit être lettres/chiffres/underscores. Ignoré."
      )
      website_code <- NULL
    }
  }
  if(!isTRUE(ofce_host)) website_code <- NULL
  website_path <- if(is.null(website_code)) repo_name else website_code

  # ---- 5. titre du site ---------------------------------------------------
  index_title <- NA_character_
  idx <- Filter(function(x) tolower(x$file) == "index.qmd", qmd_info)
  if(length(idx) > 0) index_title <- idx[[1]]$title

  final_title <- if(!is.null(website_title)) website_title
                 else if(!is.na(index_title) && nzchar(index_title) &&
                         index_title != "index") index_title
                 else repo_name

  # ---- 6. édition du _quarto.yml -----------------------------------------
  yml <- yaml::read_yaml(dest_yaml)

  if(isTRUE(ofce_host)) {
    if(!ofce_server_location %in% c("staging", "wp")) {
      cli::cli_alert_warning(
        "ofce_server_location {.val {ofce_server_location}} non reconnu. Valeurs attendues : {.val staging} ou {.val wp}. Utilisation de {.val staging} par défaut."
      )
      ofce_server_location <- "staging"
    }
    yml$website$`site-url` <- "https://www.ofce.fr/"
    sp_val <- paste0(ofce_server_location, "/", website_path)
    if(isTRUE(versionning)) sp_val <- paste0(sp_val, "/v0")
    yml$website$`site-path` <- sp_val
    patch_ftp_workflow_secrets(root, ofce_server_location)
    cli::cli_alert_info(
      "Si votre dépôt n'est pas sur l'organisation OFCE, merci de voir avec Xavier T. ou Anissa pour la configuration de l'accès au serveur avant la publication du site."
    )
  } else {
    yml$website$`site-url` <- NULL
    yml$website$`site-path` <- NULL
  }

  yml$website$title <- final_title
  yml$ofce_host <- isTRUE(ofce_host)

  if(!is.na(gh$host) && !is.na(gh$repo))
    yml$website$`repo-url` <- paste0("https://github.com/", gh$host, "/", gh$repo)

  # base URL absolue pour les hrefs other-links (Quarto ne réécrit pas ces liens)
  base_url <- ""
  su <- yml$website$`site-url`
  sp <- yml$website$`site-path`
  if(!is.null(su) && nzchar(su)) {
    base_url <- sub("/?$", "/", su)
    if(!is.null(sp) && nzchar(sp))
      base_url <- paste0(base_url, sub("^/", "", sub("/?$", "/", sp)))
  } else if(!is.na(gh$host) && !is.na(gh$repo)) {
    base_url <- sprintf("https://%s.github.io/%s/", gh$host, gh$repo)
  }
  if(!nzchar(base_url)) base_url <- "/"

  # other-links : une entrée par qmd, index en tête s'il existe
  is_index <- vapply(qmd_info,
                     function(x) tolower(x$file) == "index.qmd",
                     logical(1))
  ordered <- c(qmd_info[is_index], qmd_info[!is_index])
  other <- lapply(ordered,
    function(x) list(text = x$title,
                     icon = "newspaper",
                     href = paste0(base_url, x$href))
  )
  if(length(other) > 0) yml$website$`other-links` <- other
  else yml$website$`other-links` <- NULL

  if(isTRUE(hypothesis)) {
    yml$website$comments <- list(hypothesis = TRUE)
  } else {
    yml$website$comments <- NULL
  }

  yaml::write_yaml(
    yml, dest_yaml,
    indent.mapping.sequence = TRUE,
    handlers = list(logical = yaml::verbatim_logical)
  )
  cli::cli_alert_success("Mise à jour de {.file _quarto.yml}")

  # ---- 7. .gitignore : ajoute _site -------------------------------------
  gi_path <- fs::path(root, ".gitignore")
  gi_lines <- if(fs::file_exists(gi_path)) readLines(gi_path) else character()
  if(!any(trimws(gi_lines) == "_site" | trimws(gi_lines) == "/_site" |
          trimws(gi_lines) == "_site/")) {
    gi_lines <- c(gi_lines, "_site")
    writeLines(gi_lines, gi_path)
    cli::cli_alert_success("Ajout de {.file _site} dans {.file .gitignore}")
  }

  cli::cli_h2("Résumé")
  cli::cli_li("titre       : {final_title}")
  cli::cli_li("site-url    : {yml$website$`site-url`}")
  cli::cli_li("site-path   : {yml$website$`site-path`}")
  cli::cli_li("qmds        : {length(qmd_info)} fichier{?s}")
  cli::cli_li("hypothesis  : {hypothesis}")

  invisible(NULL)
}

# Réécrit les références aux secrets FTP dans .github/workflows/ftp_deploy.yml
# en fonction de l'emplacement OFCE (staging -> STAGING_*, wp -> WP_*).
patch_ftp_workflow_secrets <- function(root, ofce_server_location) {
  wf <- fs::path(root, ".github", "workflows", "ftp_deploy.yml")
  if(!fs::file_exists(wf)) return(invisible(NULL))
  prefix <- toupper(ofce_server_location)
  lines <- readLines(wf)
  lines <- gsub("secrets\\.FTP_USER",
                paste0("secrets.", prefix, "_USER"), lines, fixed = FALSE)
  lines <- gsub("secrets\\.FTP_PASSWORD",
                paste0("secrets.", prefix, "_PASSWORD"), lines, fixed = FALSE)
  writeLines(lines, wf)
  cli::cli_alert_success(
    "Mise à jour des secrets FTP dans {.file .github/workflows/ftp_deploy.yml} ({prefix}_USERNAME / {prefix}_PASSWORD)"
  )
  invisible(NULL)
}

# Crée une branche orpheline `gh-pages` (vide) et la pousse sur origin,
# puis revient sur la branche initiale. No-op si la branche existe déjà
# (local ou distant) ou si le working tree contient des changements non commités.
init_gh_pages_branch <- function(root) {
  git <- function(...) {
    system2("git", shQuote(c("-C", root, ...)), stdout = TRUE, stderr = TRUE)
  }

  current <- tryCatch(
    suppressWarnings(git("rev-parse", "--abbrev-ref", "HEAD")),
    error = function(e) NULL)
  if(is.null(current) || !nzchar(current[[1]]) || current[[1]] == "HEAD") {
    cli::cli_alert_warning("Pas de dépôt git utilisable — branche gh-pages ignorée.")
    return(invisible(NULL))
  }
  current <- current[[1]]

  dirty <- suppressWarnings(git("status", "--porcelain"))
  if(length(dirty) > 0 && any(nzchar(dirty))) {
    cli::cli_alert_warning(
      "Working tree non propre — branche gh-pages ignorée. Commiter d'abord.")
    return(invisible(NULL))
  }

  branches <- suppressWarnings(git("branch", "-a"))
  if(any(grepl("(^|/)gh-pages$", trimws(sub("^\\*?\\s*", "", branches))))) {
    cli::cli_alert_info("Branche {.code gh-pages} déjà présente — création ignorée.")
    return(invisible(NULL))
  }

  cli::cli_h2("Initialisation de la branche {.code gh-pages}")
  on.exit({
    suppressWarnings(git("checkout", current))
  }, add = TRUE)

  steps <- list(
    c("checkout", "--orphan", "gh-pages"),
    c("reset", "--hard"),
    c("commit", "--allow-empty", "-m", "Initialising gh-pages branch"),
    c("push", "origin", "gh-pages")
  )
  for(args in steps) {
    out <- suppressWarnings(git(args))
    st  <- attr(out, "status")
    if(!is.null(st) && st != 0) {
      cli::cli_alert_danger(
        "Échec de {.code git {paste(args, collapse=' ')}} — interruption.")
      cli::cli_text(paste(out, collapse = "\n"))
      break
    }
  }
  cli::cli_alert_success("Retour sur la branche {.code {current}}")
  invisible(NULL)
}
