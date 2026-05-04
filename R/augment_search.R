# augment_search.R
# Builds an Algolia-compatible search_augmented.json from all source QMDs in posts/.
# Covers cached AND freshly-rendered posts (unlike quarto_inspect()-based approaches).
# Output: _site/search_augmented.json

# ── Helpers ───────────────────────────────────────────────────────────────────

# Extract author names robustly from YAML $author field.
# Handles: list of named lists (standard modern format).
.parse_authors <- function(author_field) {
  if (is.null(author_field)) return(list())
  if (is.character(author_field)) return(as.list(author_field))
  # List of named lists — each entry may have $name
  purrr::map_chr(author_field, ~ {
    if (is.list(.x) && !is.null(.x$name)) .x$name
    else if (is.character(.x))            .x
    else                                  "?"
  }) |> as.list()
}

# Parse YAML front matter and return a tidy one-row tibble.
.parse_qmd <- function(qmd_path, lang = "fr", full_text = FALSE) {
  if(!require("lightparser", quietly = TRUE))
    stop("Installer le package lightparser")
  post <- tryCatch(
    lightparser::split_to_tbl(qmd_path),
    error = function(e) NULL
  )
  if (is.null(post)) {
    warning("Could not parse YAML: ", qmd_path)
    return(NULL)
  }

  # post_id = "YYYY/folder_name" — derived from directory, not filename
  post_dir <- fs::path_dir(qmd_path)              # posts/2026/20260310_XT_gow
  post_id  <- fs::path_rel(post_dir, "posts") |>  # 2026/20260310_XT_gow
    as.character()
  post_id <- fs::path_join(c(lang, post_id, "index.html"))

  object_id <- "post_" |>
    stringr::str_c(
      qmd_path |>
        fs::path_file() )

  yaml <- post |>
    dplyr::slice(1) |>
    purrr::pluck("params") |>
    purrr::pluck(1)
  text <- ""

  if(full_text) {
    text <- post |>
      slice(-1) |>
      pull(text) |>
      unlist()
    text <- text |>
      stringr::str_remove_all(
        "!\\[[^\\]]*\\](?:\\([^)]*\\)(?:\\{[^}]*\\})?|\\[[^\\]]*\\])" ) |>
      stringr::str_remove_all(
        "(?s)\\$\\$.*?\\$\\$" ) |>
      stringr::str_remove_all(
        "\\$(?!\\s)(?:[^$\n\\\\]|\\\\.)+(?<!\\s)\\$") |>
      stringr::str_remove_all(
        "(?s)\\\\begin\\{[a-zA-Z*]+\\}.*?\\\\end\\{[a-zA-Z*]+\\}") |>
      purrr::discard(~stringr::str_length(.x)==0) |>
      stringr::str_c(collapse = "\n\n")
  }
  if(!full_text) {
    text <- yaml$description %||% ""
  }

  tibble::tibble(
    objectID = object_id,
    href     = post_id,
    title    = yaml$title       %||% "",
    type = "post",
    section  = "",
    text     = text,
    cat      = list(as.list(unlist(yaml$categories))),
    authors  = list(.parse_authors(yaml$author)),
    lang     = lang,
    date     = as.character(yaml$date %||% NA_character_)
  )
}

# ── Main function ─────────────────────────────────────────────────────────────

augment_search <- function(root = ".", progress = TRUE) {
  setwd(root)
  # ── Scan source QMDs ────────────────────────────────────────────────────────

  fr_qmds <- fs::dir_ls("posts", recurse = TRUE, type = "file", regexp = "\\.qmd$") |>
    stringr::str_subset("\\.en\\.qmd$", negate = TRUE) |>
    purrr::discard(~stringr::str_detect(fs::path_file(.x), "^_"))

  en_qmds <- fs::dir_ls("posts", recurse = TRUE, type = "file", regexp = "\\.en\\.qmd$") |>
    purrr::discard(~stringr::str_detect(fs::path_file(.x), "^_"))

  cli::cli_alert_info("Parsing {length(fr_qmds)} fr and {length(en_qmds)} en source QMDs...")

  fr_meta <- purrr::map(fr_qmds, .parse_qmd, lang = "fr", .progress=progress) |>
    futurize::futurize() |>
    purrr::compact() |>
    purrr::list_rbind()
  en_meta <- purrr::map(en_qmds, .parse_qmd, lang = "en", .progress=progress) |>
    futurize::futurize() |>
    purrr::compact() |>
    purrr::list_rbind()

  posts_meta <- dplyr::bind_rows(fr_meta, en_meta) |>
    dplyr::arrange(lang, dplyr::desc(date))

  # ── Write output ─────────────────────────────────────────────────────────────

  out_path <- fs::path_join(c("/tmp", "search_augmented.json"))
  jsonlite::write_json(posts_meta, out_path, auto_unbox = FALSE, pretty = TRUE)

  cli::cli_alert_success(
    "Wrote {nrow(posts_meta)} entries ({sum(posts_meta$lang=='fr')} fr, {sum(posts_meta$lang=='en')} en) to {out_path}"
  )

  # ── Upload to Algolia ────────────────────────────────────────────────────────
  # Requires three environment variables (set in ~/.Renviron or CI secrets):
  #   ALGOLIA_APP_ID   — e.g. "ABCDE12345"
  #   ALGOLIA_API_KEY  — Admin API key (write access)
  #   ALGOLIA_INDEX    — index name (default: "blog_posts")
  #
  # Records are upserted via the Batch API (action = "updateObject").
  # Stale entries (deleted posts) are NOT removed; run a separate clearObjects
  # call first if a clean rebuild is needed.

  algolia_app_id  <- Sys.getenv("ALGOLIA_APP_ID", unset = NA_character_)
  algolia_api_key <- Sys.getenv("ALGOLIA_API_KEY", unset = NA_character_)
  algolia_index   <- Sys.getenv("ALGOLIA_INDEX",   unset = "blog_posts")

  if (is.na(algolia_app_id) || is.na(algolia_api_key)) {
    cli::cli_alert_info(c(
      "Algolia upload skipped — env vars not set. ",
      "Set ALGOLIA_APP_ID and ALGOLIA_API_KEY to enable."
    ))
    return(invisible(posts_meta))
  }

  records    <- purrr::pmap(posts_meta, \(...) list(...))
  chunk_size <- 1000L
  chunks     <- split(records, ceiling(seq_along(records) / chunk_size))
  batch_url  <- sprintf(
    "https://%s.algolia.net/1/indexes/%s/batch",
    algolia_app_id, algolia_index
  )

  cli::cli_alert_info(
    "Uploading {length(records)} record{?s} to Algolia index \\
    '{algolia_index}' in {length(chunks)} batch{?es}..."
  )

  for (i in seq_along(chunks)) {
    resp <- httr2::request(batch_url) |>
      httr2::req_headers(
        `X-Algolia-Application-Id` = algolia_app_id,
        `X-Algolia-API-Key`        = algolia_api_key
      ) |>
      httr2::req_body_json(
        list(requests = purrr::map(chunks[[i]], \(rec) list(action = "updateObject", body = rec))),
        auto_unbox = TRUE
      ) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_is_error(resp)) {
      cli::cli_warn(
        "Batch {i}/{length(chunks)} failed (HTTP {httr2::resp_status(resp)}): \\
        {httr2::resp_body_string(resp)}"
      )
    } else {
      cli::cli_alert_success("Batch {i}/{length(chunks)} OK.")
    }
  }

  cli::cli_alert_success("Algolia upload complete.")
  invisible(posts_meta)
}
