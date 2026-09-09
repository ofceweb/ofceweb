# local_stub_wp_side_effects() lives in helper-repo-fixtures.R (shared with
# test-version_up.R).

# Minimal published-WP repo carrying a legacy zero-padded site-path.
build_legacy_padded_wp_repo <- function(dir, wp = 7L, annee = 2026L) {
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = wp,
    annee   = annee,
    lang    = "fr",
    version = "v0",
    website = list(
      title       = "Un WP hérité",
      `site-url`  = "https://www.ofce.fr/",
      `site-path` = sprintf("%d/%03d/v0", annee, wp)
    )
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un WP hérité")
  invisible(dir)
}

test_that("setup_wp() rewrites a legacy zero-padded site-path to the unpadded form", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$website$`site-path`, "2026/7/v0")
  # citation.url is derived from annee/wp directly (not site-path) and must
  # match the real public URL, which includes the /wp/ segment.
  expect_equal(yml$citation$url, "https://www.ofce.fr/wp/2026/7/")
  # citation.issue is "{annee}-{wp}" with wp as a plain integer — no
  # zero-padding, even though the legacy site-path was zero-padded.
  expect_equal(yml$citation$issue, "2026-7")
})

test_that("setup_wp() computes a missing site-path from an existing wp/annee, without re-passing wp", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 4L,
    annee   = 2026L,
    lang    = "fr",
    website = list(title = "Sans site-path")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Sans site-path")

  # No `wp =` argument passed — site-path must still be derived from the
  # wp/annee already present in _quarto.yml.
  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$website$`site-path`, "2026/4")
  expect_equal(yml$website$`site-url`, "https://www.ofce.fr/")
})

test_that("setup_wp() comments out wp-pdf (non-blocking warning) when both PDF formats are declared", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-pdf:",
    "    output-file: OFCEWP-draft.pdf",
    "  wp-typst:",
    "    output-file: OFCEWP-draft-typst.pdf"
  ))

  expect_message(setup_wp(dir), "wp-pdf.*wp-typst|wp-typst.*wp-pdf")

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_true(any(grepl("# wp-pdf:", idx_lines, fixed = TRUE)))
  expect_true(any(grepl("wp-typst:", idx_lines, fixed = TRUE) & !grepl("#", idx_lines, fixed = TRUE)))
  # output-file is patched on the surviving format (wp-typst), not re-added
  # under the freshly-commented-out wp-pdf key.
  expect_true(any(grepl("output-file: OFCEWP2026-5.pdf", idx_lines, fixed = TRUE)))
  # format-links must follow the surviving engine (wp-typst), not the
  # commented-out wp-pdf, and its `text` must match the computed
  # output-file so the "Other Formats" link always points to the right
  # PDF. The first (bare) entry is the underlying Quarto engine name
  # without the `wp-` prefix.
  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  links <- idx_yml$`format-links`
  expect_true(any(vapply(links, identical, logical(1L), y = "typst")))
  pdf_link <- links[[which(vapply(links, is.list, logical(1L)))]]
  expect_equal(pdf_link$format, "wp-typst")
  expect_equal(pdf_link$text, "OFCEWP2026-5.pdf")
  expect_equal(pdf_link$icon, "file-pdf")
})

test_that("setup_wp() syncs format-links to the active PDF engine and computed output-file", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 24L,
    annee   = 2025L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-html: default",
    "  wp-pdf:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  suppressMessages(setup_wp(dir))

  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  links <- idx_yml$`format-links`
  expect_true(any(vapply(links, identical, logical(1L), y = "pdf")))
  pdf_link <- links[[which(vapply(links, is.list, logical(1L)))]]
  expect_equal(pdf_link$format, "wp-pdf")
  expect_equal(pdf_link$text, "OFCEWP2025-24.pdf")
  expect_equal(pdf_link$icon, "file-pdf")
})

test_that("setup_wp() adds fig-format: png and warns when rsvg-convert is absent and wp-pdf is the sole format", {
  local_stub_wp_side_effects()
  local_mocked_bindings(check_rsvg_convert = function(...) invisible(FALSE))
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-pdf:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  expect_message(setup_wp(dir), "rsvg-convert")

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_true(any(grepl("fig-format: png", idx_lines, fixed = TRUE)))
})

test_that("setup_wp() does not touch fig-format when rsvg-convert is present", {
  local_stub_wp_side_effects()
  local_mocked_bindings(check_rsvg_convert = function(...) invisible(TRUE))
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-pdf:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  suppressMessages(setup_wp(dir))

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_false(any(grepl("fig-format", idx_lines, fixed = TRUE)))
})

test_that("setup_wp() computes citation.issue and citation.url for a published WP", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir, wp = 12L, annee = 2027L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2027/12/v0"
  write_quarto_yml(dir, yml)

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$citation$issue, "2027-12")
  expect_equal(yml$citation$url, "https://www.ofce.fr/wp/2027/12/")
  expect_equal(yml$stable_url, "https://www.ofce.fr/wp/2027/12/")
})

test_that("setup_wp() updates citation.issue when the WP number changes", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir, wp = 5L, annee = 2026L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2026/5/v0"
  # setup_wp() has no wp=/annee= arguments -- a WP number change must be
  # made directly in _quarto.yml (or via the central registry).
  yml$wp <- 8L
  write_quarto_yml(dir, yml)

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$wp, 8L)
  expect_equal(yml$citation$issue, "2026-8")
  expect_equal(yml$citation$url, "https://www.ofce.fr/wp/2026/8/")
  expect_equal(yml$stable_url, "https://www.ofce.fr/wp/2026/8/")
})

test_that("setup_wp() does not set citation.issue/url for a draft (wp = NULL)", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = NULL,
    annee   = 2026L,
    lang    = "fr",
    website = list(title = "Un brouillon")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un brouillon")

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_null(yml$wp)
  expect_null(yml$citation$issue)
  expect_null(yml$citation$url)
  expect_null(yml$stable_url)
})

test_that("setup_wp() warns that the deployment URL changes when the site-path is rewritten", {
  local_stub_wp_side_effects()
  withr::local_options(cli.width = 300)
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)

  msgs <- capture_messages(setup_wp(dir))

  expect_true(any(grepl("site-path modifi", msgs)))
  expect_true(any(grepl("URL diff", msgs)))
  expect_true(any(grepl("2026/007/v0", msgs, fixed = TRUE)))
  expect_true(any(grepl("2026/7/v0", msgs, fixed = TRUE)))
})

test_that("setup_wp() does not warn when the site-path is already unpadded", {
  local_stub_wp_side_effects()
  withr::local_options(cli.width = 300)
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2026/7/v0"
  write_quarto_yml(dir, yml)

  msgs <- capture_messages(setup_wp(dir))

  expect_false(any(grepl("site-path modifi", msgs)))
})

test_that("setup_wp() installs Quarto extensions via ofce::setup_quarto()", {
  calls <- list()
  local_mocked_bindings(
    init_gh_pages_branch = function(...) invisible(NULL),
    set_gh_var           = function(...) invisible(NULL)
  )
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(name = character(), url = character()),
    .package = "gert"
  )
  local_mocked_bindings(
    setup_quarto = function(dir, ...) { calls[[length(calls) + 1L]] <<- dir; invisible(NULL) },
    .package = "ofce"
  )
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)

  suppressMessages(setup_wp(dir))

  expect_length(calls, 1L)
  expect_equal(fs::path_norm(calls[[1L]]), fs::path_norm(dir))
})

test_that("setup_wp() lets a confirmed registry entry override the existing _quarto.yml values", {
  local_mocked_bindings(
    init_gh_pages_branch = function(...) invisible(NULL),
    set_gh_var           = function(...) invisible(NULL),
    fetch_wp_entries      = function(...) list(
      list(annee = 2027L, wp = 4L, type = "repo", `source-repo` = "ofce/wp2026-1")
    )
  )
  local_mocked_bindings(
    setup_quarto = function(...) invisible(NULL),
    .package = "ofce"
  )
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir, wp = 5L, annee = 2026L)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2026/5/v0"
  write_quarto_yml(dir, yml)
  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/ofce/wp2026-1.git", name = "origin", repo = dir)

  # setup_wp() has no wp=/annee= arguments: the pre-existing _quarto.yml
  # value (wp = 5L) is deliberately different from the registry entry's
  # wp (4L) -- the registry entry must win.
  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$wp, 4L)
  expect_equal(yml$annee, 2027L)
  expect_false(yml$draft)
  expect_equal(yml$website$`site-path`, "2027/4/v0")
  expect_equal(yml$citation$issue, "2027-4")
})

test_that("setup_wp() warns about legacy stray extensions left on disk", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)
  # Simulate a leftover flat `wp` extension from before the migration to
  # ofce::setup_quarto().
  legacy_ext <- fs::path(dir, "_extensions", "wp")
  fs::dir_create(legacy_ext, recurse = TRUE)
  writeLines("title: old", fs::path(legacy_ext, "_extension.yml"))

  msgs <- capture_messages(setup_wp(dir))

  expect_true(any(grepl("p\u00e9rim\u00e9e", msgs)))
  expect_true(any(grepl("_extensions/wp", msgs, fixed = TRUE)))
  # No automatic deletion.
  expect_true(fs::file_exists(fs::path(legacy_ext, "_extension.yml")))
})


# Minimal draft (unpublished, wp = NULL) WP repo -- used to exercise the
# stage-target "auto" resolution and the draft website.site-url computation.
build_draft_wp_repo <- function(dir) {
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    lang    = "fr"
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")
  invisible(dir)
}

test_that("setup_wp() does not assume the ofce org when no git remote is configured and gh is not authenticated", {
  local_stub_wp_side_effects()
  local_mocked_bindings(check_gh_login = function(...) invisible(NA_character_))
  dir <- withr::local_tempdir()
  build_draft_wp_repo(dir)

  expect_message(setup_wp(dir), "URL GitHub Pages")

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  # No remote and no gh account to guess from: stage-target is written back
  # literally as "auto" (so a later transfer to the ofce org resolves
  # correctly at the next deploy_wp() call, without rerunning setup_wp()),
  # but the resolution used for the draft URL must never silently assume
  # "ftp" (the ofce org) -- site-url must not be fabricated as
  # https://ofce.github.io/...
  expect_equal(yml$`stage-target`, "auto")
  expect_false(identical(yml$website$`site-url`, sprintf("https://ofce.github.io/%s/", fs::path_file(dir))))
})

test_that("setup_wp() uses the authenticated gh account (not 'ofce') for the draft GitHub Pages URL when there is no remote", {
  local_stub_wp_side_effects()
  local_mocked_bindings(check_gh_login = function(...) invisible("someuser"))
  dir <- withr::local_tempdir()
  build_draft_wp_repo(dir)

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  # stage-target stays "auto" literally in _quarto.yml -- only the
  # resolved draft URL reflects the authenticated gh account.
  expect_equal(yml$`stage-target`, "auto")
  expect_equal(yml$website$`site-url`, sprintf("https://someuser.github.io/%s/", fs::path_file(dir)))
})

test_that("setup_wp() resolves stage-target to ftp and skips the GitHub Pages URL when the remote is under the ofce org", {
  local_stub_wp_side_effects()
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(
      name = "origin",
      url  = "https://github.com/ofce/wp-example.git"
    ),
    .package = "gert"
  )
  dir <- withr::local_tempdir()
  build_draft_wp_repo(dir)

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  # stage-target stays "auto" literally in _quarto.yml -- only the
  # resolved draft URL reflects the ofce-owned remote.
  expect_equal(yml$`stage-target`, "auto")
  expect_match(yml$website$`site-url`, "^https://staging\\.ofce\\.fr/")
})

test_that("setup_wp() resolves stage-target to gh-pages and uses the real owner for a non-ofce remote", {
  local_stub_wp_side_effects()
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(
      name = "origin",
      url  = "https://github.com/someoneelse/wp-example.git"
    ),
    .package = "gert"
  )
  dir <- withr::local_tempdir()
  build_draft_wp_repo(dir)

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  # stage-target stays "auto" literally in _quarto.yml -- only the
  # resolved draft URL reflects the non-ofce remote owner.
  expect_equal(yml$`stage-target`, "auto")
  expect_equal(yml$website$`site-url`, "https://someoneelse.github.io/wp-example/")
})

test_that("setup_wp() injects a default wp-typst format for a brand-new draft with no PDF format declared", {
  local_stub_wp_side_effects()
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(
      name = "origin",
      url  = "https://github.com/ofce/wp-pam-pmq.git"
    ),
    .package = "gert"
  )
  dir <- withr::local_tempdir()
  build_draft_wp_repo(dir)

  suppressMessages(setup_wp(dir))

  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  expect_null(idx_yml$format$`wp-pdf`)
  expect_equal(idx_yml$format$`wp-typst`$`output-file`, "OFCEWP-draft.pdf")
  links <- idx_yml$`format-links`
  pdf_link <- links[[which(vapply(links, is.list, logical(1L)))]]
  expect_equal(pdf_link$format, "wp-typst")
  expect_equal(pdf_link$text, "OFCEWP-draft.pdf")
})

test_that("setup_wp() names a wp-pdf draft file from the repo (wp- prefix stripped) when wp-pdf is the declared engine", {
  local_stub_wp_side_effects()
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(
      name = "origin",
      url  = "https://github.com/ofce/wp-pam-pmq.git"
    ),
    .package = "gert"
  )
  dir <- withr::local_tempdir()
  build_draft_wp_repo(dir)
  # Declare wp-pdf explicitly -- the repo-derived draft filename only kicks
  # in for the wp-pdf (LaTeX) engine; wp-typst keeps the historical
  # "OFCEWP-draft.pdf" name regardless of repo (see test above).
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-pdf:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  suppressMessages(setup_wp(dir))

  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  expect_equal(idx_yml$format$`wp-pdf`$`output-file`, "ofce-draft-pam-pmq.pdf")
  links <- idx_yml$`format-links`
  pdf_link <- links[[which(vapply(links, is.list, logical(1L)))]]
  expect_equal(pdf_link$format, "wp-pdf")
  expect_equal(pdf_link$text, "ofce-draft-pam-pmq.pdf")
})

test_that("setup_wp() leaves a sole wp-typst declaration untouched -- no wp-pdf is added", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-typst:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  suppressMessages(setup_wp(dir))

  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  expect_null(idx_yml$format$`wp-pdf`)
  expect_equal(idx_yml$format$`wp-typst`$`output-file`, "OFCEWP2026-5.pdf")
})

test_that("setup_wp() comments out a stray PDF key and injects wp-typst when neither wp-pdf nor wp-typst is declared", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  pdf:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  suppressMessages(setup_wp(dir))

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_true(any(grepl("^\\s*#\\s*pdf:", idx_lines)))
  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  expect_null(idx_yml$format$`wp-pdf`)
  expect_equal(idx_yml$format$`wp-typst`$`output-file`, "OFCEWP2026-5.pdf")
})

test_that("setup_wp() comments out a stray PDF key alongside an existing wp-typst, without adding wp-pdf", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-typst:",
    "    output-file: OFCEWP-draft.pdf",
    "  ofce-pdf:",
    "    output-file: OFCEWP-draft-2.pdf"
  ))

  suppressMessages(setup_wp(dir))

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_true(any(grepl("^\\s*#\\s*ofce-pdf:", idx_lines)))
  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  expect_null(idx_yml$format$`wp-pdf`)
  expect_equal(idx_yml$format$`wp-typst`$`output-file`, "OFCEWP2026-5.pdf")
})

test_that("setup_wp() comments out a stray HTML key in index.qmd, keeping wp-html untouched", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default", `wp-pdf` = list(`output-file` = "OFCEWP-draft.pdf"))
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  html: default"
  ))

  expect_message(setup_wp(dir), "HTML parasite")

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_true(any(grepl("^\\s*#\\s*html:", idx_lines)))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$format$`wp-html`, "default")
})

test_that("setup_wp() adds format.wp-html to _quarto.yml when it's missing (pre-existing repo)", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr"
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-pdf:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  suppressMessages(setup_wp(dir))

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$format$`wp-html`, "default")
})

test_that("setup_wp() is idempotent on an already-clean repo using wp-pdf", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-pdf:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  suppressMessages(setup_wp(dir))
  after_first <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )
  suppressMessages(setup_wp(dir))
  after_second <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )

  expect_identical(after_first$yml, after_second$yml)
  expect_identical(after_first$idx, after_second$idx)
})

test_that("setup_wp() is idempotent on an already-clean repo using wp-typst", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 5L,
    annee   = 2026L,
    lang    = "fr",
    format  = list(`wp-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-typst:",
    "    output-file: OFCEWP-draft.pdf"
  ))

  suppressMessages(setup_wp(dir))
  after_first <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )
  suppressMessages(setup_wp(dir))
  after_second <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )

  expect_identical(after_first$yml, after_second$yml)
  expect_identical(after_first$idx, after_second$idx)
})

# Inserts a template-style (2-space indented sequence) `author:` placeholder
# block into an already-written `_quarto.yml`, right before `website:` --
# mirroring the real inst/setup_wp/_quarto.yml gabarit exactly (as opposed
# to write_quarto_yml()'s `author =` argument, which round-trips through
# yaml::write_yaml() and emits list items at the *same* indentation as the
# parent key -- a different, also valid, YAML style covered separately
# below and in test-yaml_patch.R).
insert_author_placeholder <- function(dir) {
  path  <- fs::path(dir, "_quarto.yml")
  lines <- readLines(path, warn = FALSE)
  placeholder <- c(
    "author:",
    "  - name: \"Prénom Nom\"",
    "    email: \"prenom.nom@sciencespo.fr\""
  )
  website_line <- which(grepl("^website:", lines))[[1]]
  lines <- append(lines, placeholder, after = website_line - 1L)
  writeLines(lines, path)
  invisible(path)
}

test_that("setup_wp() moves an author key found in index.qmd into _quarto.yml, replacing the template placeholder", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 8L,
    annee   = 2026L,
    lang    = "fr",
    website = list(title = "Un WP")
  ))
  insert_author_placeholder(dir)
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: Un WP",
    "author:",
    "  - name: Jane Doe",
    "    email: jane.doe@sciencespo.fr"
  ))

  expect_message(setup_wp(dir), "author")

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$author[[1]]$name, "Jane Doe")
  expect_equal(yml$author[[1]]$email, "jane.doe@sciencespo.fr")

  idx_yml <- get_yaml(fs::path(dir, "index.qmd"))
  expect_null(idx_yml$author)
  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_true(any(grepl("^\\s*#\\s*author:", idx_lines)))
})

test_that("setup_wp() leaves _quarto.yml's author untouched when index.qmd has no author key", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 9L,
    annee   = 2026L,
    lang    = "fr",
    website = list(title = "Un autre WP")
  ))
  insert_author_placeholder(dir)
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un autre WP")

  expect_no_message(setup_wp(dir), message = "author")

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$author[[1]]$name, "Prénom Nom")
  expect_equal(yml$author[[1]]$email, "prenom.nom@sciencespo.fr")
})

test_that("setup_wp() moves author into a same-indent-sequence author placeholder (dash at column 0)", {
  # Regression test for the yaml_block_end() same-indentation sequence fix:
  # write_quarto_yml() (via yaml::write_yaml()) emits `author:` list items
  # at the *same* column as the key itself, rather than indented under it
  # like the real gabarit -- both are valid YAML, and setup_wp() must
  # correctly replace the whole placeholder subtree either way.
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 11L,
    annee   = 2026L,
    lang    = "fr",
    author  = list(list(name = "Prénom Nom", email = "prenom.nom@sciencespo.fr")),
    website = list(title = "Un WP au format dash-même-colonne")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: Un WP au format dash-même-colonne",
    "author:",
    "  - name: Jane Doe",
    "    email: jane.doe@sciencespo.fr"
  ))

  expect_message(setup_wp(dir), "author")

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$author[[1]]$name, "Jane Doe")
  expect_equal(yml$author[[1]]$email, "jane.doe@sciencespo.fr")
  # No other top-level key was swallowed by the (previously mis-detected)
  # author subtree.
  expect_true(isTRUE(yml$ofce_wp))
  expect_equal(yml$wp, 11L)
})

test_that("setup_wp() is idempotent after moving author from index.qmd to _quarto.yml", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = 10L,
    annee   = 2026L,
    lang    = "fr",
    website = list(title = "WP idempotent")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP idempotent",
    "author:",
    "  - name: Jane Doe",
    "    email: jane.doe@sciencespo.fr"
  ))

  expect_message(setup_wp(dir), "author")
  after_first <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )

  expect_no_message(setup_wp(dir), message = "author")
  after_second <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )

  expect_identical(after_first$yml, after_second$yml)
  expect_identical(after_first$idx, after_second$idx)
})
