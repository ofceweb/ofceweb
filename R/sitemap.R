# build_sitemap.R
# Rebuilds _site/sitemap.xml after a full render.
#
# Quarto's FR rendering only adds freshly-processed pages to the sitemap.
# This function supplements it with:
#   • all EN posts  (_site/en/{year}/{post}/index.html)
#   • all cached FR posts that Quarto did not (re)process
#   • the EN root page (_site/index.en.html)
#
# Strategy: build the sitemap from scratch by scanning _site/ directly,
# so the result is always in sync with what is actually on disk.

build_sitemap <- function(root = ".", progress=TRUE) {
  setwd(root)

  # ── Base URL from _quarto.yml ────────────────────────────────────────────────
  quarto_yml <- yaml::read_yaml("_quarto.yml")
  site_url   <- quarto_yml$website[["site-url"]] %||%
    "https://www.ofce.sciences-po.fr/blog2024/"
  if (!stringr::str_ends(site_url, "/"))
    site_url <- paste0(site_url, "/")

  sitemap_path <- "_site/sitemap.xml"

  # ── Helpers ──────────────────────────────────────────────────────────────────

  # Format a file's mtime as ISO 8601 UTC (matches Quarto's own format)
  fmt_lastmod <- function(path) {
    mtime <- fs::file_info(path)$modification_time
    format(mtime, "%Y-%m-%dT%H:%M:%S.000Z", tz = "UTC")
  }

  # Build one-row tibble {loc, lastmod} for a file path under _site/
  url_entry <- function(path) {
    rel <- fs::path_rel(path, "_site") |>
      fs::path_norm() |>
      as.character()

    tibble::tibble(loc = paste0(site_url, rel), lastmod = fmt_lastmod(path))
  }

  # ── 1. Top-level HTML pages (index.html, about.html, index.en.html …) ───────
  root_html <- fs::dir_ls("_site", type = "file", regexp = "\\.html$")
  root_urls <- purrr::map_dfr(root_html, url_entry)

  # ── 2. FR post index.html (freshly rendered + restored from cache) ───────────
  fr_html <- if (fs::dir_exists("_site/fr"))
    fs::dir_ls("_site/fr", recurse = TRUE, type = "file", regexp = "index\\.html$")
  else
    character(0)

  # ── 3. EN post index.html ────────────────────────────────────────────────────
  en_html <- if (fs::dir_exists("_site/en"))
    fs::dir_ls("_site/en", recurse = TRUE, type = "file", regexp = "index\\.html$")
  else
    character(0)

  post_urls <- purrr::map_dfr(c(fr_html, en_html), url_entry)

  cli::cli_alert_info(
    "Sitemap: {length(fr_html)} FR post{?s}, {length(en_html)} EN post{?s} found in _site/"
  )

  # ── 4. Combine, deduplicate, sort ─────────────────────────────────────────────
  all_urls <- dplyr::bind_rows(root_urls, post_urls) |>
    dplyr::distinct(loc, .keep_all = TRUE) |>
    dplyr::arrange(loc)

  # ── 5. Serialise to XML ───────────────────────────────────────────────────────
  url_nodes <- purrr::map_chr(seq_len(nrow(all_urls)), \(i)
                              glue::glue(
                                "  <url>\n    <loc>{all_urls$loc[[i]]}</loc>\n    <lastmod>{all_urls$lastmod[[i]]}</lastmod>\n  </url>"
                              )
  )

  xml_lines <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    url_nodes,
    '</urlset>'
  )

  writeLines(xml_lines, sitemap_path)

  n_fr <- sum(stringr::str_detect(all_urls$loc, "/fr/"))
  n_en <- sum(stringr::str_detect(all_urls$loc, "/en/"))

  cli::cli_alert_success(
    "sitemap.xml written: {nrow(all_urls)} URL{?s} \
    ({n_fr} fr post{?s}, {n_en} en post{?s}, {nrow(root_urls)} root page{?s})"
  )

  invisible(all_urls)
}
