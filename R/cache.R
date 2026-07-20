hash_file <- function(path, knownf = TRUE) {
  purrr::map_chr(path, ~ {
    if(file.exists(.x)) {
      content <- NULL
      if(fs::path_ext(.x) %in% c("R", "r", "txt", "csv", "bib", "qmd", "json"))
        content <- readLines(.x, warn = FALSE)
      if(fs::path_ext(.x) %in% c("jpg", "png", "gif", "tiff"))
        content <- magick::image_read(.x, warn = FALSE)
      if(!is.null(content)&knownf)
        return(digest::digest(content, algo = "sha1", file = FALSE))
      if(!knownf)
        return(digest::digest(.x, algo = "sha1", file = TRUE))
    }
    return(strrep("0", 40))
  })
}

hash_folder <- function(
    path,
    include = c("qmd", "txt", "csv", "r", "R", "json", "bib")) {
  if("all" %in% include)
    regexp <- NULL
  else
    regexp <- stringr::str_c("\\.(", stringr::str_c(include, collapse = "|"), ")$")
  files <- fs::dir_ls(path, recurse=TRUE, all= TRUE, type = "file", regexp = regexp)
  ok_files <- purrr::map_lgl(files, file.exists)
  if(any(ok_files))
    return(hash_file(as.character(files[ok_files])) |>
             sort() |>
             digest::digest(algo = "sha1"))
  return(strrep("0", 40))
}


cache_posts <- function(cached, lang = "fr", root = ".", progress = TRUE) {
  setwd(root)
  cache_path <- fs::path_join(c("_posts_cache", lang))
  cli::cli_alert_info("Cache des posts...")
  if(!dir.exists(cache_path))
    dir.create(cache_path, recursive = TRUE)

  cache_path <- fs::path_join(c("_posts_cache", lang))
  path_posts_html <- fs::path_join(c("_site", lang))
  path_posts_origin <- fs::path_join(c(stringr::str_c("_", lang), lang))
  path_source <- fs::path_join(c("posts"))

  posts_list <- cached |>
    dplyr::filter(!from_cache)
  posts <- purrr::pmap_dfr(
    posts_list,
    \(name, hash, lang, origin, source, cache, yaml,...) {
      .f_html <- fs::path_join(c("_site", lang, name))
      copied <- TRUE
      if(dir.exists(.f_html))
        fs::dir_copy(.f_html, cache, overwrite = TRUE)
      tibble::tibble(name = name, lang = lang, hash = hash, copied = copied, cache = cache)
    })

  pat <- glue::glue("^_posts_cache/{lang}/[0-9]{{4}}/[^/]+-([a-f0-9]){{40}}$")
  files_in_cache <- fs::dir_ls(fs::path_join(c("_posts_cache", lang)),
                               type = "any", recurse = TRUE) |>
    purrr::keep(~stringr::str_detect(.x, pat ))
  incache <- purrr::map(
    c(cached |>
        dplyr::filter(from_cache) |>
        dplyr::pull(cache),
      posts$cache),
    ~ files_in_cache |> stringr::str_starts(.x) )  |>
    purrr::transpose() |>
    purrr::map_lgl(any)

  unlink(files_in_cache[!incache], force = TRUE, recursive = TRUE)

  if(nrow(posts)>0)
    npc <- nrow(posts |> dplyr::filter(copied))
  else
    npc <- 0
  if(npc>0)
    cli::cli_alert_success("{npc} post{?s} mis en cache")
  if(npc==0)
    cli::cli_alert_success("Pas de post mis en cache")
  posts
}

get_from_cache <- function(lang, root, force_freeze = TRUE, progress = TRUE) {
  cli::cli_alert_info(
    "Copie des posts du cache")
  posts <- tibble::tibble(
    origin = character(),
    source = character(),
    cache = character(),
    name = character(),
    lang = character(),
    hash = character(),
    from_cache = logical(),
    yaml = list())

  setwd(root)
  cache_path <- fs::path_join(c("_posts_cache", lang))

  if(!dir.exists(cache_path))
    return(posts)

  path_html <- fs::path_join(c("_site", lang))
  path_origin <- fs::path_join(c(stringr::str_c("_", lang)))
  path_source <- fs::path_join(c("posts"))
  path_origin <- fs::path_join(c(path_origin, lang))
  years <- fs::dir_ls(path_origin, type = "directory") |>
    fs::path_rel(path_origin) |>
    purrr::discard(~stringr::str_detect(.x, "^_|/_"))

  posts_list <- purrr::map(
    years,
    \(.y) fs::dir_ls(fs::path_join(c(path_origin, .y)), type = "directory")) |>
    purrr::list_c() |>
    fs::path_rel(path_origin) |>
    purrr::discard(~stringr::str_detect(.x, "^_|/_"))

  posts <- purrr::map_dfr(posts_list, \(.f) {
    .f_o <- fs::path_join(c(path_origin,.f))
    .f_h <- fs::path_join(c(path_html, .f))
    .f_s <- fs::path_join(c(path_source,.f))
    hash <- hash_folder(.f_s)
    name <-  fs::path_file(.f_o)
    .f_cached <- fs::path_join(c(cache_path, stringr::str_c(.f, "-", hash)))
    cached <- dir.exists(.f_cached) &&
      file.exists(fs::path_join(c(.f_cached,"index.html")))
    index <- fs::path_join(c(.f_o, "index.qmd"))
    yaml <- get_yaml(index)
    if(!is.null(yaml[["freeze"]]))
      cached <- ((yaml$freeze != FALSE) | force_freeze) && cached

    if(cached) {
      index <- fs::path_join(c(.f_o, "index.qmd"))
      yaml <- get_yaml(index)
      fs::dir_delete(.f_o)
      fs::dir_copy(.f_cached, .f_h, overwrite = TRUE)
    }
    tibble::tibble(
      origin = .f_o,
      source = .f_s,
      cache = .f_cached,
      name = .f,
      lang = lang,
      hash = hash,
      from_cache = cached,
      yaml = list(yaml))
  }, .progress = progress) |>
    futurize::futurize()

  np <- nrow(posts |> dplyr::filter(from_cache))

  arkiv_yaml <- purrr::pmap(posts |> dplyr::filter(from_cache), \(name, yaml, ...) {
    if(length(yaml[['categories']]) ==1)
      cat <- list(yaml[['categories']])
    else
      cat <- yaml[['categories']]
    list(
      title = yaml[['title']],
      image = fs::path_join(c(lang, name, yaml[['image']])),
      date = yaml[['date']],
      description = yaml[['description']],
      categories = cat ,
      author = format_name_yaml(yaml[['author']]),
      `reading-time` = yaml[['reading-time']],
      gow = yaml[['gow']],
      nb = yaml[['nb']],
      path = stringr::str_c(lang, "/", name, "/index.html") ) |>
      purrr::compact()
  }) |>
    futurize::futurize()

  if(length(arkiv_yaml)>0) {
    arkiv <- stringr::str_c("cached_", lang, ".yaml")
    yaml::write_yaml(arkiv_yaml, fs::path_join(c(stringr::str_c("_", lang), arkiv)))
    root_index <- fs::path_join(c(stringr::str_c("_", lang), "index.qmd"))

    root_yaml <- get_yaml(root_index) |>
      purrr::list_modify(listing =list(contents =  list(lang, arkiv)))
    put_yaml(root_yaml, root_index)
  }
  cli::cli_alert_success("{np}/{nrow(posts)} post{?s} du cache")
  posts
}

format_name_yaml <- function(author) {
  purrr::map_chr(author, ~{
    auth <- "?"
    if('name' %in% names(.x))
      auth <- .x[["name"]]
    if(purrr::pluck_depth(.x) == 1)
      auth <- .x
    auth}) |>
    stringr::str_c(collapse = ", ")
}

patch_sitelibs_hashes <- function(cached, root = ".", progress = TRUE) {
  setwd(root)
  site_libs_path <- "_site/site_libs"
  if (!fs::dir_exists(site_libs_path)) {
    cli::cli_alert_warning("site_libs introuvable, patch ignoré")
    return(invisible(NULL))
  }

  # Find all hashed CSS/JS files currently in site_libs
  all_files    <- fs::dir_ls(site_libs_path, recurse = TRUE, type = "file")
  hashed_files <- all_files[grepl("-[a-f0-9]{32}\\.", fs::path_file(all_files))]

  if (length(hashed_files) == 0) {
    cli::cli_alert_info("Pas de fichiers hashés dans site_libs, patch ignoré")
    return(invisible(NULL))
  }

  # Build mapping: hashed file → stable file (hash stripped from filename).
  # e.g. site_libs/bootstrap/bootstrap-68c484c0....min.css
  #   →  site_libs/bootstrap/bootstrap.min.css
  # The stable path is used both to rename the file on disk and to rewrite
  # every HTML reference, so subsequent renders always produce identical URLs.
  file_map <- purrr::map(hashed_files, \(hf) {
    filename    <- fs::path_file(hf)
    dir         <- fs::path_dir(hf)
    rel_dir     <- fs::path_rel(dir, "_site") |> as.character() |>
      stringr::str_replace_all("\\\\", "/")
    base        <- sub("-[a-f0-9]{32}.*$", "", filename)   # e.g. "bootstrap"
    suffix      <- sub("^.*-[a-f0-9]{32}", "", filename)   # e.g. ".min.css"
    stable_name <- paste0(base, ".hashed", suffix)                    # e.g. "bootstrap.min.css"
    esc_suffix  <- stringr::str_replace_all(suffix, "\\.", "\\\\.")
    list(
      hashed_file = hf,
      stable_file = fs::path(dir, stable_name),
      stable_rel  = paste0(rel_dir, "/", stable_name),
      # Matches any hash variant so cached HTML from prior renders is also fixed
      pattern     = paste0(rel_dir, "/", base, "-[a-f0-9]{32}", esc_suffix)
    )
  })

  # Rename hashed files to their stable equivalents in site_libs/
  purrr::walk(file_map, \(m) {
    fs::file_copy(m$hashed_file, m$stable_file, overwrite = TRUE)
    fs::file_delete(m$hashed_file)
  })
  cli::cli_alert_info("{length(file_map)} fichier(s) renommé(s) (hash supprimé)")

  # Replace hashed references in ALL HTML files (freshly rendered + from cache).
  # Using stable names means the HTML is identical across renders, which
  # drastically reduces the number of files transferred by the FTP sync.
  all_html  <- fs::dir_ls("_site", recurse = TRUE, glob = "*.html", type = "file")
  n_patched <- 0L
  purrr::walk(all_html, \(html) {
    content <- readLines(html, encoding = "UTF-8", warn = FALSE)
    changed <- FALSE
    for (m in file_map) {
      hit <- grepl(m$pattern, content, perl = TRUE)
      idx <- which(hit)
      if (length(idx) >= 1) {
        new_content <- gsub(m$pattern, m$stable_rel, content[idx], perl = TRUE)
        if (!identical(new_content, content[idx])) {
          content[idx] <- new_content
          changed <- TRUE
        }
      }
    }
    if (changed) {
      writeLines(content, html, useBytes = FALSE)
      n_patched <<- n_patched + 1L
    }
  }, .progress = progress)

  cli::cli_alert_success("{n_patched} fichier(s) HTML patché(s) (références stables)")
  invisible(n_patched)
}
