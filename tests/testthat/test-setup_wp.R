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
  # No remote and no gh account to guess from: stage-target must default to
  # gh-pages (never silently "ftp", which would wrongly assume the ofce
  # org), and site-url must not be fabricated as https://ofce.github.io/...
  expect_equal(yml$`stage-target`, "gh-pages")
  expect_false(identical(yml$website$`site-url`, sprintf("https://ofce.github.io/%s/", fs::path_file(dir))))
})

test_that("setup_wp() uses the authenticated gh account (not 'ofce') for the draft GitHub Pages URL when there is no remote", {
  local_stub_wp_side_effects()
  local_mocked_bindings(check_gh_login = function(...) invisible("someuser"))
  dir <- withr::local_tempdir()
  build_draft_wp_repo(dir)

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$`stage-target`, "gh-pages")
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

  expect_equal(yml$`stage-target`, "ftp")
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

  expect_equal(yml$`stage-target`, "gh-pages")
  expect_equal(yml$website$`site-url`, "https://someoneelse.github.io/wp-example/")
})
