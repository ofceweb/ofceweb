# No pb_manifest() test file existed before; scoped here to the pdf-path
# field (mirrors test-wp_manifest.R's pdf-path coverage for wp_manifest()).

build_pb_manifest_repo <- function(dir, pb = 5L) {
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = pb,
    lang    = "fr",
    pb_series = "ife",
    website = list(
      title       = "Un PB",
      `site-url`  = "https://www.ofce.fr/",
      `site-path` = sprintf("ife/%d", pb)
    )
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un PB")
  invisible(dir)
}

test_that("pb_manifest() computes pdf-path relative to www.ofce.fr from the active output-file", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 5L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$format <- list(`pb-pdf` = list(`output-file` = "IFEPB5.pdf"))
  write_quarto_yml(dir, yml)

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$pdf, "IFEPB5.pdf")
  expect_equal(m$`pdf-path`, "pb/ife/5/IFEPB5.pdf")

  written <- jsonlite::fromJSON(fs::path(dir, "manifest.json"))
  expect_equal(written$`pdf-path`, "pb/ife/5/IFEPB5.pdf")
})

test_that("pb_manifest() falls back to pb/{pb} for pdf-path when site-path is absent", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    lang    = "fr",
    format  = list(`pb-pdf` = list(`output-file` = "IFEPB5.pdf")),
    website = list(title = "Un PB", `site-url` = "https://www.ofce.fr/")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un PB")

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$`pdf-path`, "pb/5/IFEPB5.pdf")
})

test_that("pb_manifest() falls back to the pb-typst output-file when pb-pdf is absent", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 5L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$format <- list(`pb-typst` = list(`output-file` = "IFEPB5.pdf"))
  write_quarto_yml(dir, yml)

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$`pdf-path`, "pb/ife/5/IFEPB5.pdf")
})

test_that("pb_manifest() leaves pdf-path unset for a draft without pb", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    lang    = "fr",
    format  = list(`pb-pdf` = list(`output-file` = "OFCEPB-draft.pdf")),
    website = list(title = "Brouillon")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")

  m <- pb_manifest(dir)

  expect_equal(m$pdf, "OFCEPB-draft.pdf")
  expect_null(m$`pdf-path`)
})

test_that("pb_manifest() leaves pdf-path unset when no PDF/Typst output-file is declared", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 5L)

  m <- pb_manifest(dir, stage = FALSE)

  expect_null(m$pdf)
  expect_null(m$`pdf-path`)
})

test_that("pb_manifest() gives a published PB its unversioned public URL and its series", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 12L)

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$url, "https://www.ofce.fr/pb/ife/12/")
  expect_equal(m$pb_series, "ife")
  expect_null(m$version)
})

test_that("pb_manifest() keeps the version in the staging URL of a draft", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb   = TRUE,
    pb_series = "ife",
    lang      = "fr",
    version   = "v2",
    website   = list(title = "Brouillon")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")
  local_mocked_bindings(gh_slug_from_remote = function(...) "ofce/pb-ab-x")

  m <- pb_manifest(dir, stage = TRUE)

  expect_equal(m$url, "https://staging.ofce.fr/pb-ab-x/v2/")
  expect_null(m[["pb"]])
  expect_equal(m$pb_series, "ife")
})
