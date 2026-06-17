posts_db <- function(path) {
  posts <- fs::dir_ls(path = path, recurse = TRUE, glob = "*.qmd") |>
    fs::path_rel(path) |>
    purrr::discard(~stringr::str_detect(.x, "^_|/_"))
  if(length(posts)==0)
    cli::cli_abort("Pas de posts")
  posts_en <- posts |> purrr::keep(~stringr::str_detect(.x, "\\.en\\.qmd$"))
  posts_fr <- setdiff(posts, posts_en)
  ppath <- function(x) fs::path_join(c(path, x))
  posts <- purrr::map_dfr(posts_fr, ~{
    yaml <- get_yaml(ppath(.x))
    postID  <- fs::path_ext_remove(.x) |> stringr::str_remove("\\.fr")

    post_en <- posts_en |> purrr::keep(~stringr::str_detect(.x, postID))
    if(length(post_en)!=1) {
      post_en <- NA_character_
      translated <- FALSE
      yaml_en <- NULL
    } else {
      translated <- TRUE
      yaml_en <- get_yaml(ppath(post_en))
    }
    # adding also a comment there
    author <- .parse_authors(yaml$author)

    pdf_link_fr <- stringr::str_c(postID, ".fr.pdf")
    pdf_link_en <- stringr::str_c(postID, ".en.pdf")

    tibble::tibble(
      postID  = postID,
      file_fr = .x,
      file_en = post_en %||% NA_character_,
      author = list(author),
      date = yaml$date,
      translated = translated,
      categories_fr  = list(yaml$categories),
      categories_en  = list(yaml_en$categories),
      title_fr = yaml$title %||% NA_character_,
      title_en = yaml_en$title %||% NA_character_,
      description_fr = yaml$description %||% NA_character_,
      description_en = yaml_en$description %||% NA_character_,
      pdf_link_fr = pdf_link_fr,
      pdf_link_en = pdf_link_en,
      gow = yaml$gow %||% FALSE)

  }) |>
    futurize::futurize()

  posts <- posts |>
    dplyr::mutate(path = fs::path_dir(file_fr))
  dbl <- posts |>
    dplyr::group_by(path) |>
    dplyr::mutate(n=dplyr::n()) |>
    dplyr::ungroup() |>
    dplyr::distinct(path,n) |>
    dplyr::filter(n>1)

  purrr::pwalk(dbl, \(path, n) cli::cli_alert_danger("{n} qmd dans le dossier {path}"))

  posts |>
    dplyr::distinct(path, .keep_all = TRUE) |>
    dplyr::select(-path)
}


copy_files <- function(lang = "fr", freeze = TRUE, progress = TRUE) {
  cli::cli_alert_info("Copie des fichiers site en {lang}")
  has_freeze <- FALSE
  dir <- stringr::str_c("_", lang)
  tmp_freeze <- fs::path_join(c(tempdir(), "_freeze"))
  if(fs::dir_exists(dir)) {
    if(fs::dir_exists(glue::glue("{dir}/_freeze"))&freeze) {
      has_freeze <- TRUE
      unlink(tmp_freeze, recursive=TRUE, force = TRUE)
      fs::file_move(glue::glue("{dir}/_freeze"), tmp_freeze)
    }
    unlink(dir, recursive = TRUE, force = TRUE)
  }

  fs::dir_create(dir)
  if(has_freeze)
    fs::file_move(tmp_freeze, glue::glue("{dir}/_freeze"))

  root_files <- c("_quarto.yml", "_quarto-en.yml", "_quarto-fr.yml", "index.qmd", "about.qmd")
  #, "about.en.qmd")
  root_dirs <- c("_extensions", "www", "_utils")
  purrr::walk(root_files, ~fs::file_copy(.x, fs::path_join(c(dir,.x)), overwrite = TRUE))
  purrr::walk(root_dirs, ~fs::dir_copy(.x, fs::path_join(c(dir,.x)), overwrite = TRUE))
}


copy_post <- function(posts, lang = "fr",
                      path = "posts",
                      typst = TRUE,
                      force_freeze = FALSE,
                      progress = TRUE) {
  cli::cli_alert_info("Copie des posts site en {lang}")
  ppath <- function(x) fs::path_join(c(path, x))
  dir <- stringr::str_c("_", lang, "/", lang)
  fs::dir_create(dir)

  metayaml <- get_yaml(fs::path_join(c("posts", "_metadata.yml")))
  if(lang=="fr") {
    metayaml[["lang"]] <- "fr"
    metayaml[["french"]] <-  TRUE
  }
  else {
    metayaml[["lang"]] <- "en"
    metayaml[["french"]] <-  FALSE
  }

  # Don't set formats in metadata - they will be set per-post
  # This avoids conflicts when mixing blog and GoW posts

  put_yaml(metayaml, fs::path_join(c(dir, "_metadata.yml")), pure = TRUE)

  purrr::pwalk(
    posts,
    \(file_fr, file_en, title_fr, title_en,
      translated,
      description_fr, description_en, categories_fr,
      pdf_link_fr, pdf_link_en, ...) {
      if(lang=="fr") {
        title <- title_fr
        description <- description_fr
        file <- file_fr
        pdf_link <- pdf_link_fr
      }
      if(lang=="en") {
        if(!translated)
          return(NULL)
        title <- title_en
        description <- description_en
        file <- file_en
        pdf_link <- pdf_link_en
      }
      post_path <- fs::path_dir(ppath(file))
      post_folder <-fs::path_dir(file)
      new_path <- fs::path_join(c(dir, post_folder))
      new_qmd <- fs::path_join(c(new_path, "index.qmd"))
      old_qmd <- fs::path_join(c(new_path, fs::path_file(file)))
      fs::dir_copy(post_path, new_path, overwrite = TRUE)
      autres_qmd <- fs::dir_ls(new_path, glob = "*.qmd") |>
        purrr::discard(~stringr::str_detect(fs::path_file(.x), "^_")) |>
        purrr::discard(~stringr::str_detect(.x, old_qmd))
      fs::file_delete(autres_qmd)
      fs::file_move(old_qmd, new_qmd)
      post_name <- fs::path_file(file) |>
        fs::path_ext_remove() |>
        stringr::str_remove("\\.en$")
      pdf_link <- glue::glue("{post_name}.{lang}.pdf")
      yaml <- get_yaml(new_qmd)

      # Determine format based on whether this is a GoW post
      is_gow_post <- isTRUE(yaml$gow)
      html_fmt <- if(is_gow_post) "ofce-gow-html" else "ofce-blog-html"
      typst_fmt <- if(is_gow_post) "ofce-gow-typst" else "ofce-blog-typst"

      # Clear any existing format specifications
      yaml[["format"]] <- list()
      if(!is.null(yaml[["freeze"]]) & force_freeze)
        yaml[["freeze"]] <- FALSE
      # Set only the appropriate formats for this post type

      # todo : traiter le cas des kw anglais
      keywords <- c(categories_fr, "blog de l'OFCE", "économie") |>
        unique() |>
        as.list()
      yaml[["format"]][[html_fmt]] <- list(keywords = keywords)
      if(typst)
        yaml[["format"]][[typst_fmt]][["output-file"]] <- pdf_link
      else
        pdf_link <- NULL
      yaml$translated <- translated
      yaml$socialband <- TRUE
      yaml$share = list(
        twitter = TRUE,
        facebook = TRUE,
        linkedin = TRUE,
        mastodon = TRUE,
        reddit = TRUE,
        tumblr = TRUE,
        stumble = TRUE,
        bluesky = TRUE,
        email = TRUE,
        pdf = pdf_link,
        location = "socialshare",
        permalink = glue::glue("https://ofce.sciences-po.fr/blog2024/{lang}/{post_folder}/index.html"),
        description = title)
      if(is.null(yaml$image)) {
        if(length(fs::dir_ls(new_path, glob="*.jpg"))>0)
          new_img <- fs::dir_ls(new_path, glob="*.jpg")[[1]] |> fs::path_file()
        else {
          if(is.null(yaml$categories_fr))
            origin <- "_utils/dta/logement.jpg"
          else
            origin <- glue::glue("_utils/dta/{yaml$categories_fr[[1]]}.jpg")
          target <- fs::path_join(c(new_path, "image.jpg"))
          if(fs::file_exists(origin))
            fs::file_copy(origin, target)
          else
            fs::file_copy("_utils/dta/logement.jpg", target )
          new_img <-  "image.jpg"
        }
      }
      put_yaml(yaml, new_qmd, insert = c("" , "::: {#socialshare}", ":::", ""))
    }, .progress = progress)
  # |>
  #   futurize::futurize()
}


#' Sync back `.sourcoise/` directories from rendered copies to source posts
#'
#' After rendering a language pass, any `.sourcoise/` directory that appeared
#' (or was populated) inside the ephemeral copy folder is mirrored back to the
#' original `posts/` tree. Only files **not already present** in the target
#' `.sourcoise/` are copied, which naturally deduplicates across the FR and EN
#' passes without extra bookkeeping.
#'
#' @param cached Data frame returned by [get_from_cache()]. Must contain at
#'   least the columns `from_cache`, `origin` (path to the rendered copy), and
#'   `source` (path to the original post folder under `posts/`).
#' @param lang Character. Language label used for cli messages (`"fr"` or
#'   `"en"`).
#' @return Invisibly, the total number of files synced back across all posts.
#' @keywords internal
sync_back_sourcoise <- function(cached, lang, max_size_mb = 50) {
  to_sync <- dplyr::filter(cached, !from_cache)

  if (nrow(to_sync) == 0L) {
    cli::cli_alert_info("Sync-back .sourcoise ({lang}) : aucun post re-rendu.")
    return(invisible(0L))
  }

  total <- 0L

  purrr::pwalk(to_sync, \(origin, source, name, ...) {
    if (!fs::dir_exists(origin)) return(invisible(NULL))

    # Find every .sourcoise/ directory at any depth inside the copy
    all_dirs <- fs::dir_ls(origin, recurse = TRUE, type = "directory", all = TRUE)
    sourcoise_dirs <- all_dirs[fs::path_file(all_dirs) == ".sourcoise"]

    if (length(sourcoise_dirs) == 0L) return(invisible(NULL))

    purrr::walk(sourcoise_dirs, \(copy_sourcoise) {
      # Preserve relative path from copy root → mirror under source root
      rel <- fs::path_rel(copy_sourcoise, origin)
      target_sourcoise <- fs::path_join(c(source, rel))

      copy_files <- fs::dir_ls(copy_sourcoise, type = "file", all = TRUE) |>
        fs::path_file()

      already_synced <- if (fs::dir_exists(target_sourcoise)) {
        fs::dir_ls(target_sourcoise, type = "file", all = TRUE) |> fs::path_file()
      } else {
        character(0L)
      }

      new_files <- setdiff(copy_files, already_synced)
      if (length(new_files) == 0L) return(invisible(NULL))

      # Drop files exceeding the size threshold
      max_bytes <- max_size_mb * 1024^2
      new_files <- purrr::keep(new_files, \(fname) {
        sz <- fs::file_size(fs::path_join(c(copy_sourcoise, fname)))
        if (sz > max_bytes) {
          cli::cli_alert_warning(
            "Sync-back ({lang}) ignoré (>{max_size_mb} Mo) : {fname}"
          )
          FALSE
        } else {
          TRUE
        }
      })
      if (length(new_files) == 0L) return(invisible(NULL))

      fs::dir_create(target_sourcoise, recurse = TRUE)
      purrr::walk(new_files, \(fname) {
        fs::file_copy(
          fs::path_join(c(copy_sourcoise, fname)),
          fs::path_join(c(target_sourcoise, fname)),
          overwrite = FALSE
        )
      })

      total <<- total + length(new_files)
      cli::cli_alert_success(
        "Sync-back ({lang}) {length(new_files)} fichier{?s} \u2192 {target_sourcoise}"
      )
    })
  })

  if (total == 0L)
    cli::cli_alert_info("Sync-back .sourcoise ({lang}) : rien de nouveau.")

  invisible(total)
}
