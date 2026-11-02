# wp_manifest() writes a `source-repo` field derived from the git `origin`
# remote — used by ftp_deploy.yml to detect a different repo reusing an
# already-published WP number. It also emits the data model v1 fields
# (modele-donnees-v1.qmd) alongside the legacy fields consumed by
# deploy_wp()/ftp_deploy.yml.

# `extra` is merged into _quarto.yml (modifyList: NULL values drop a key).
build_manifest_repo <- function(dir, wp = 1L, annee = 2026L, extra = list()) {
  yml <- list(
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
  )
  write_quarto_yml(dir, utils::modifyList(yml, extra))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un WP")
  invisible(dir)
}

# Rewrites _quarto.yml with `extra` merged on top of the current content.
patch_manifest_yml <- function(dir, extra) {
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  write_quarto_yml(dir, utils::modifyList(yml, extra))
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

  expect_equal(m$pdf, "https://www.ofce.fr/wp/2026/5/v0/OFCEWP2026-5.pdf")
  expect_equal(m$`pdf-path`, "wp/2026/5/v0/OFCEWP2026-5.pdf")

  written <- jsonlite::fromJSON(fs::path(dir, "manifest.json"))
  expect_equal(written$`pdf-path`, "wp/2026/5/v0/OFCEWP2026-5.pdf")
  expect_equal(written$pdf, "https://www.ofce.fr/wp/2026/5/v0/OFCEWP2026-5.pdf")
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
  expect_equal(m$pdf, "https://www.ofce.fr/wp/2026/5/OFCEWP2026-5.pdf")
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

test_that("wp_manifest() leaves pdf and pdf-path null for a draft without wp/annee", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    lang    = "fr",
    format  = list(`wp-pdf` = list(`output-file` = "OFCEWP-draft.pdf")),
    website = list(title = "Brouillon")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")

  m <- wp_manifest(dir)

  # The bare file name is no longer emitted (useless without its path).
  expect_null(m$pdf)
  expect_null(m$`pdf-path`)
})

test_that("wp_manifest() leaves pdf-path unset when no PDF/Typst output-file is declared", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, wp = 5L, annee = 2026L)

  m <- wp_manifest(dir, stage = FALSE)

  expect_null(m$pdf)
  expect_null(m$`pdf-path`)
})

# ---- data model v1 ---------------------------------------------------------

test_that("wp_manifest() emits the v1 constants and drops `date` for `date_published`", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, wp = 6L, annee = 2026L, extra = list(date = "2026-06-15"))

  m <- wp_manifest(dir, stage = FALSE)

  expect_equal(m$schema_version, "1.0")
  expect_equal(m$type, "working-paper")
  expect_equal(m$media, "html")
  expect_true(m$auto_update)
  expect_equal(m$date_published, "2026-06-15")
  expect_false("date" %in% names(m))
  expect_true("date_modified" %in% names(m))

  written <- jsonlite::read_json(fs::path(dir, "manifest.json"))
  expect_equal(written$schema_version, "1.0")
  expect_true(written$auto_update)
  expect_equal(written$date_published, "2026-06-15")
  expect_null(written$date)
})

test_that("wp_manifest() does not mistake date-modified for date", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(`date-modified` = "last-modified"))

  m <- wp_manifest(dir)

  # `date` absent: falls back to today, not to the `date-modified` value.
  expect_equal(m$date_published, format(Sys.Date(), "%Y-%m-%d"))
})

test_that("wp_manifest() builds a lower-case id without zero-padding, stable across versions", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, wp = 6L, annee = 2026L)

  m0 <- wp_manifest(dir, stage = FALSE)
  expect_equal(m0$id, "ofce-wp-2026-6-fr")

  patch_manifest_yml(dir, list(version = "v1"))
  m1 <- wp_manifest(dir, stage = FALSE)
  expect_equal(m1$version, "v1")
  expect_equal(m1$id, m0$id)

  patch_manifest_yml(dir, list(lang = "en", institution = "cepii"))
  expect_equal(wp_manifest(dir)$id, "cepii-wp-2026-6-en")
})

test_that("wp_manifest() writes a null id for a draft without a registered number", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, lang = "fr", website = list(title = "Brouillon")))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")

  m <- wp_manifest(dir)

  expect_null(m$id)
  expect_true("id" %in% names(m))
  expect_match(paste(readLines(fs::path(dir, "manifest.json")), collapse = "\n"),
               '"id": null', fixed = TRUE)
})

test_that("wp_manifest() passes institution through for ofce, cepii and ife", {
  for (inst in c("ofce", "cepii", "ife")) {
    dir <- withr::local_tempdir()
    build_manifest_repo(dir, extra = list(institution = inst))

    m <- wp_manifest(dir)

    expect_equal(m$institution, inst)
    expect_match(m$id, paste0("^", inst, "-wp-"))
  }
})

test_that("wp_manifest() defaults institution to ofce when absent", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir)

  expect_no_warning(m <- wp_manifest(dir))

  expect_equal(m$institution, "ofce")
})

test_that("wp_manifest() warns and falls back to ofce on an unknown institution", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(institution = "ifo"))

  expect_warning(m <- wp_manifest(dir), "institution")

  expect_equal(m$institution, "ofce")
  expect_match(m$id, "^ofce-wp-")
})

test_that("wp_manifest() does not read the Typst branding field `institut`", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(institut = "ife-ofce"))

  expect_no_warning(m <- wp_manifest(dir))

  expect_equal(m$institution, "ofce")
})

test_that("wp_manifest() defaults categories/keywords/jel to empty arrays", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir)

  m <- wp_manifest(dir)

  expect_equal(m$categories, list())
  expect_equal(m$keywords, list())
  expect_equal(m$jel, list())

  json <- paste(readLines(fs::path(dir, "manifest.json")), collapse = "\n")
  expect_match(json, '"categories": []', fixed = TRUE)
  expect_match(json, '"keywords": []', fixed = TRUE)
  expect_match(json, '"jel": []', fixed = TRUE)
})

test_that("wp_manifest() reads categories/keywords/jel from _quarto.yml and upper-cases JEL", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(
    categories = c("macroéconomie", "emploi"),
    keywords   = "inflation",
    jel        = c("e24", "E25")
  ))

  m <- wp_manifest(dir)

  expect_equal(m$categories, list("macroéconomie", "emploi"))
  # Scalar coerced to a length-1 array, not unboxed.
  expect_equal(m$keywords, list("inflation"))
  expect_equal(m$jel, list("E24", "E25"))

  written <- jsonlite::read_json(fs::path(dir, "manifest.json"))
  expect_equal(written$keywords, list("inflation"))
  expect_equal(written$jel, list("E24", "E25"))
})

test_that("wp_manifest() falls back to index.qmd for the editorial lists", {
  dir <- withr::local_tempdir()
  # `_quarto.yml` carries the template's empty slots; index.qmd has the values.
  build_manifest_repo(dir, extra = list(categories = list(), keywords = list()))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: Un WP",
    "keywords: [prévision, inflation]",
    "jel: [e37]"
  ))

  m <- wp_manifest(dir)

  expect_equal(m$keywords, list("prévision", "inflation"))
  expect_equal(m$jel, list("E37"))
  expect_equal(m$categories, list())
})

test_that("wp_manifest() prefers _quarto.yml over index.qmd for the editorial lists", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(keywords = c("a", "b")))
  write_qmd(dir, "index.qmd", yaml_lines = c("title: Un WP", "keywords: [z]"))

  expect_equal(wp_manifest(dir)$keywords, list("a", "b"))
})

test_that("wp_manifest() sets translation_id to null unless declared", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir)
  expect_null(wp_manifest(dir)$translation_id)

  patch_manifest_yml(dir, list(translation_id = "ofce-wp-2026-1"))
  expect_equal(wp_manifest(dir)$translation_id, "ofce-wp-2026-1")
})

test_that("wp_manifest() flattens authors to name strings, preserving order", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(author = list(
    list(name = "Xavier Timbeau", affiliation = "OFCE", orcid = "0000-0002-6198-5953"),
    list(name = "Paul Malliet", email = "paul@example.org"),
    list(name = "Jane Doe")
  )))

  m <- wp_manifest(dir)

  expect_equal(m$authors, list("Xavier Timbeau", "Paul Malliet", "Jane Doe"))

  written <- jsonlite::read_json(fs::path(dir, "manifest.json"))
  expect_equal(written$authors, list("Xavier Timbeau", "Paul Malliet", "Jane Doe"))
})

test_that("wp_manifest() handles a single author given as a mapping or a string", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(author = list(name = "Solo Auteur", affiliation = "OFCE")))
  expect_equal(wp_manifest(dir)$authors, list("Solo Auteur"))

  build_manifest_repo(dir, extra = list(author = "Jane Doe"))
  expect_equal(wp_manifest(dir)$authors, list("Jane Doe"))
})

test_that("wp_manifest() writes an empty authors array when none is declared", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir)

  m <- wp_manifest(dir)

  expect_equal(m$authors, list())
  expect_match(paste(readLines(fs::path(dir, "manifest.json")), collapse = "\n"),
               '"authors": []', fixed = TRUE)
})

test_that("wp_manifest() does not take author-title for the author list", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(`author-title` = "Auteurs"))

  expect_equal(wp_manifest(dir)$authors, list())
})

test_that("wp_manifest() falls back to the index.qmd title when _quarto.yml has none", {
  dir <- withr::local_tempdir()
  # Regression: wp-xt-travail / wp-gamp-gainemploi had an empty manifest title
  # because only _quarto.yml$title was read.
  build_manifest_repo(dir)
  write_qmd(dir, "index.qmd", yaml_lines = "title: Titre dans index.qmd")

  m <- wp_manifest(dir)

  expect_equal(m$title, "Titre dans index.qmd")
})

test_that("wp_manifest() prefers the _quarto.yml title and tolerates an empty one", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, extra = list(title = "Titre projet"))
  expect_equal(wp_manifest(dir)$title, "Titre projet")

  patch_manifest_yml(dir, list(title = ""))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Titre dans index.qmd")
  expect_equal(wp_manifest(dir)$title, "Titre dans index.qmd")
})

test_that("wp_manifest() keeps the legacy fields read by deploy_wp()/ftp_deploy.yml", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir, wp = 6L, annee = 2026L)

  m <- wp_manifest(dir, stage = FALSE)

  expect_equal(m$wp, 6L)
  expect_equal(m$annee, 2026L)
  expect_equal(m$version, "v0")
  expect_false(m$stage)
  expect_true(all(c("source-repo", "pdf-path", "ofceweb-version") %in% names(m)))
  expect_equal(m$url, "https://www.ofce.fr/wp/2026/6/v0/")
})
