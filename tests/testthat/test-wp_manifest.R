# wp_manifest() writes a `source-repo` field derived from the git `origin`
# remote — used by ftp_deploy.yml to detect a different repo reusing an
# already-published WP number.

build_manifest_repo <- function(dir, wp = 1L, annee = 2026L) {
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = wp,
    annee   = annee,
    lang    = "fr",
    version = "v0",
    website = list(
      title       = "Un WP",
      `site-url`  = "https://www.ofce.fr/",
      `site-path` = sprintf("%d/%d/v0", annee, wp)
    )
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un WP")
  invisible(dir)
}

test_that("wp_manifest() sets source-repo from the origin remote", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir)

  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/ofce/wp2026-1.git", name = "origin", repo = dir)

  m <- wp_manifest(dir)

  expect_equal(m$`source-repo`, "ofce/wp2026-1")

  written <- jsonlite::fromJSON(fs::path(dir, "manifest.json"))
  expect_equal(written$`source-repo`, "ofce/wp2026-1")
})

test_that("wp_manifest() leaves source-repo unset without an origin remote", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir)
  # No git repo at all here — gh_slug_from_remote() must fail gracefully.

  m <- wp_manifest(dir)

  expect_null(m$`source-repo`)
})

test_that("wp_manifest() computes pdf-path relative to www.ofce.fr from the active output-file", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, wp = 5L, annee = 2026L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$format <- list(`wp-pdf` = list(`output-file` = "OFCEWP2026-5.pdf"))
  write_quarto_yml(dir, yml)

  m <- wp_manifest(dir, stage = FALSE)

  expect_equal(m$pdf, "OFCEWP2026-5.pdf")
  expect_equal(m$`pdf-path`, "wp/2026/5/v0/OFCEWP2026-5.pdf")

  written <- jsonlite::fromJSON(fs::path(dir, "manifest.json"))
  expect_equal(written$`pdf-path`, "wp/2026/5/v0/OFCEWP2026-5.pdf")
})

test_that("wp_manifest() omits the version segment from pdf-path when there is no version", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-pdf` = list(`output-file` = "OFCEWP2026-5.pdf")),
    website = list(title = "Un WP", `site-url` = "https://www.ofce.fr/")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un WP")

  m <- wp_manifest(dir, stage = FALSE)

  expect_equal(m$`pdf-path`, "wp/2026/5/OFCEWP2026-5.pdf")
})

test_that("wp_manifest() falls back to the wp-typst output-file when wp-pdf is absent", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, wp = 5L, annee = 2026L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$format <- list(`wp-typst` = list(`output-file` = "OFCEWP2026-5.pdf"))
  write_quarto_yml(dir, yml)

  m <- wp_manifest(dir, stage = FALSE)

  expect_equal(m$`pdf-path`, "wp/2026/5/v0/OFCEWP2026-5.pdf")
})

test_that("wp_manifest() leaves pdf-path unset for a draft without wp/annee", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    lang    = "fr",
    format  = list(`wp-pdf` = list(`output-file` = "OFCEWP-draft.pdf")),
    website = list(title = "Brouillon")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")

  m <- wp_manifest(dir)

  expect_equal(m$pdf, "OFCEWP-draft.pdf")
  expect_null(m$`pdf-path`)
})

test_that("wp_manifest() leaves pdf-path unset when no PDF/Typst output-file is declared", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, wp = 5L, annee = 2026L)

  m <- wp_manifest(dir, stage = FALSE)

  expect_null(m$pdf)
  expect_null(m$`pdf-path`)
})
