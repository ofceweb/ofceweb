#' Rescanne les pages et met à jour la section `other-links`
#'
#' Scanne les fichiers `.qmd` à la racine du dépôt (récursivement, en ignorant
#' ceux qui commencent par `_`) et réécrit la section
#' `website > other-links` du `_quarto.yml` avec une entrée par page trouvée,
#' y compris `index.qmd`.
#' Le titre est lu dans le YAML front-matter du qmd ; à défaut, on utilise le
#' nom du fichier sans extension.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param icon Icône bootstrap utilisée pour chaque entrée. Défaut `"newspaper"`.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @export
rescan_site <- function(path = ".", icon = "newspaper") {

  root <- fs::path_abs(fs::path_expand(path))

  if(!fs::dir_exists(root))
    cli::cli_abort("Le dossier {.path {root}} n'existe pas.")

  dest_yaml <- fs::path(root, "_quarto.yml")
  if(!fs::file_exists(dest_yaml))
    cli::cli_abort("Aucun {.file _quarto.yml} trouvé dans {.path {root}}.")

  cli::cli_h1("rescan_site dans {.path {fs::path_file(root)}}")

  qmds <- fs::dir_ls(root, recurse = TRUE, glob = "*.qmd", type = "file")
  qmds <- qmds[!grepl("^_", fs::path_file(qmds))]
  qmds <- unname(as.character(qmds))

  # base URL pour les hrefs : on construit une URL absolue afin que les liens
  # other-links fonctionnent depuis n'importe quelle profondeur de page
  # (Quarto ne réécrit pas les hrefs de la section other-links).
  yml_tmp <- yaml::read_yaml(dest_yaml)
  site_url  <- yml_tmp$website$`site-url`
  site_path <- yml_tmp$website$`site-path`
  base_url <- ""
  if(!is.null(site_url) && nzchar(site_url)) {
    base_url <- sub("/?$", "/", site_url)
    if(!is.null(site_path) && nzchar(site_path))
      base_url <- paste0(base_url, sub("^/", "", sub("/?$", "/", site_path)))
  } else {
    # fallback : déduire l'URL gh-pages depuis le remote origin
    remotes <- tryCatch(gert::git_remote_list(repo = root),
                        error = function(e) NULL)
    if(!is.null(remotes) && nrow(remotes) > 0) {
      o <- remotes[remotes$name == "origin", , drop = FALSE]
      url <- if(nrow(o) > 0) o$url[[1]] else remotes$url[[1]]
      url2 <- sub("\\.git$", "", url)
      m <- if(grepl("^git@", url2))
        regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
      else
        regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
      if(length(m) >= 3)
        base_url <- sprintf("https://%s.github.io/%s/", m[[2]], m[[3]])
    }
  }
  if(!nzchar(base_url)) base_url <- "/"
  cli::cli_alert_info("base URL : {.url {base_url}}")

  read_title <- function(p) {
    y <- tryCatch(get_yaml(p), error = function(e) NULL)
    if(is.list(y) && length(y$title) >= 1) {
      t <- y$title[[1]]
      if(is.character(t) && nzchar(trimws(t))) return(trimws(t))
    }
    # fallback : regex sur la 1re ligne `title:` du frontmatter
    lines <- tryCatch(readLines(p, warn = FALSE, encoding = "UTF-8"),
                      error = function(e) character())
    m <- regmatches(lines, regexec("^\\s*title\\s*:\\s*(.*?)\\s*$", lines))
    for(mm in m) {
      if(length(mm) >= 2 && nzchar(mm[[2]])) {
        v <- mm[[2]]
        v <- sub('^["\']', "", v); v <- sub('["\']$', "", v)
        if(nzchar(v)) return(v)
      }
    }
    NA_character_
  }

  qmd_info <- lapply(qmds, function(p) {
    title <- read_title(p)
    if(is.na(title))
      title <- fs::path_ext_remove(fs::path_file(p))
    rel  <- as.character(fs::path_rel(p, root))
    href <- paste0(base_url, as.character(fs::path_ext_set(rel, "html")))
    cli::cli_alert_info("{.file {fs::path_rel(p, root)}} → {.val {title}}")
    list(title = title, href = href)
  })

  # mettre index.qmd en tête si présent
  is_index <- vapply(qmd_info,
                     function(x) tolower(fs::path_file(x$href)) == "index.html",
                     logical(1))
  qmd_info <- c(qmd_info[is_index], qmd_info[!is_index])

  yml <- yml_tmp

  other <- lapply(qmd_info, function(x)
    list(text = x$title, icon = icon, href = x$href))

  if(length(other) > 0) yml$website$`other-links` <- other
  else yml$website$`other-links` <- NULL

  yaml::write_yaml(
    yml, dest_yaml,
    indent.mapping.sequence = TRUE,
    handlers = list(logical = yaml::verbatim_logical)
  )

  cli::cli_alert_success(
    "Mise à jour de {.file _quarto.yml} : {length(other)} entrée{?s} dans {.field other-links}."
  )

  invisible(NULL)
}
