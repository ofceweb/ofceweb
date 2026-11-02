# pb_manifest(): pdf-path (mirrors test-wp_manifest.R) and the data model v1
# fields (modele-donnees-v1.qmd). PBs are numbered sequentially, with no year.

# `extra` is merged into _quarto.yml (modifyList: NULL values drop a key).
build_pb_manifest_repo <- function(dir, pb = 5L, extra = list()) {
  yml <- list(
    ofce_pb = TRUE,
    pb      = pb,
    lang    = "fr",
    version = "v0",
    website = list(
      title       = "Un PB",
      `site-url`  = "https://www.ofce.fr/",
      `site-path` = sprintf("%d/v0", pb)
    )
  )
  write_quarto_yml(dir, utils::modifyList(yml, extra))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un PB")
  invisible(dir)
}

test_that("pb_manifest() computes pdf-path relative to www.ofce.fr from the active output-file", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 5L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$format <- list(`pb-pdf` = list(`output-file` = "OFCEPB2026-5.pdf"))
  write_quarto_yml(dir, yml)

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$pdf, "https://www.ofce.fr/pb/5/v0/OFCEPB2026-5.pdf")
  expect_equal(m$`pdf-path`, "pb/5/v0/OFCEPB2026-5.pdf")

  written <- jsonlite::fromJSON(fs::path(dir, "manifest.json"))
  expect_equal(written$`pdf-path`, "pb/5/v0/OFCEPB2026-5.pdf")
  expect_equal(written$pdf, "https://www.ofce.fr/pb/5/v0/OFCEPB2026-5.pdf")
})

test_that("pb_manifest() omits the version segment from pdf-path when there is no version", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    lang    = "fr",
    format  = list(`pb-pdf` = list(`output-file` = "OFCEPB2026-5.pdf")),
    website = list(title = "Un PB", `site-url` = "https://www.ofce.fr/")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un PB")

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$`pdf-path`, "pb/5/OFCEPB2026-5.pdf")
})

test_that("pb_manifest() falls back to the pb-typst output-file when pb-pdf is absent", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 5L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$format <- list(`pb-typst` = list(`output-file` = "OFCEPB2026-5.pdf"))
  write_quarto_yml(dir, yml)

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$`pdf-path`, "pb/5/v0/OFCEPB2026-5.pdf")
})

test_that("pb_manifest() leaves pdf and pdf-path null for a draft without pb", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    lang    = "fr",
    format  = list(`pb-pdf` = list(`output-file` = "OFCEPB-draft.pdf")),
    website = list(title = "Brouillon")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")

  m <- pb_manifest(dir)

  expect_null(m$pdf)
  expect_null(m$`pdf-path`)
})

test_that("pb_manifest() leaves pdf-path unset when no PDF/Typst output-file is declared", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 5L)

  m <- pb_manifest(dir, stage = FALSE)

  expect_null(m$pdf)
  expect_null(m$`pdf-path`)
})

# ---- data model v1 ---------------------------------------------------------

test_that("pb_manifest() emits the v1 constants and `date_published`", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 153L, extra = list(date = "2026-06-15"))

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$schema_version, "1.0")
  expect_equal(m$type, "policy-brief")
  expect_equal(m$media, "html")
  expect_true(m$auto_update)
  expect_equal(m$date_published, "2026-06-15")
  expect_false("date" %in% names(m))
  expect_equal(m$institution, "ofce")
  expect_null(m$translation_id)
  expect_equal(m$categories, list())
  expect_equal(m$keywords, list())
  expect_equal(m$jel, list())
})

test_that("pb_manifest() builds an id without year, stable across versions", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 153L)

  m0 <- pb_manifest(dir, stage = FALSE)
  expect_equal(m0$id, "ofce-pb-153-fr")

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$version <- "v1"
  write_quarto_yml(dir, yml)
  expect_equal(pb_manifest(dir, stage = FALSE)$id, m0$id)
})

test_that("pb_manifest() writes a null id for a draft without pb", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_pb = TRUE, lang = "fr", website = list(title = "Brouillon")))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")

  expect_null(pb_manifest(dir)$id)
})

test_that("pb_manifest() handles institution: passthrough, default, unknown, `institut` ignored", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 7L, extra = list(institution = "cepii"))
  m <- pb_manifest(dir)
  expect_equal(m$institution, "cepii")
  expect_equal(m$id, "cepii-pb-7-fr")

  build_pb_manifest_repo(dir, pb = 7L, extra = list(institut = "ife-ofce"))
  expect_no_warning(m <- pb_manifest(dir))
  expect_equal(m$institution, "ofce")

  build_pb_manifest_repo(dir, pb = 7L, extra = list(institution = "ifo"))
  expect_warning(m <- pb_manifest(dir), "institution")
  expect_equal(m$institution, "ofce")
})

test_that("pb_manifest() reads the editorial lists with index.qmd fallback and JEL upper-casing", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, extra = list(keywords = "budget", jel = c("h60", "E62")))
  write_qmd(dir, "index.qmd", yaml_lines = c("title: Un PB", "categories: [fiscalité]"))

  m <- pb_manifest(dir)

  expect_equal(m$keywords, list("budget"))
  expect_equal(m$jel, list("H60", "E62"))
  expect_equal(m$categories, list("fiscalité"))
})

test_that("pb_manifest() flattens authors to name strings", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, extra = list(author = list(
    list(name = "Xavier Timbeau", affiliation = "OFCE"),
    list(name = "Paul Malliet")
  )))

  expect_equal(pb_manifest(dir)$authors, list("Xavier Timbeau", "Paul Malliet"))
})

test_that("pb_manifest() falls back to the index.qmd title", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir)
  write_qmd(dir, "index.qmd", yaml_lines = "title: Titre dans index.qmd")

  expect_equal(pb_manifest(dir)$title, "Titre dans index.qmd")
})

test_that("pb_manifest() keeps the legacy fields read by deploy_pb()/ftp_deploy.yml", {
  dir <- withr::local_tempdir()
  build_pb_manifest_repo(dir, pb = 5L)

  m <- pb_manifest(dir, stage = FALSE)

  expect_equal(m$pb, 5L)
  expect_equal(m$version, "v0")
  expect_false(m$stage)
  expect_true(all(c("source-repo", "pdf-path", "ofceweb-version") %in% names(m)))
  expect_equal(m$url, "https://www.ofce.fr/pb/5/v0/")
})
