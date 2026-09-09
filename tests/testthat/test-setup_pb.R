# setup_pb() touches git, the GitHub API, and (via ofce::setup_quarto()) the
# network; those calls are stubbed so the tests exercise only the
# _quarto.yml editing logic, mirroring local_stub_wp_side_effects() in
# helper-repo-fixtures.R.
local_stub_pb_side_effects <- function(env = parent.frame()) {
  local_mocked_bindings(
    init_gh_pages_branch   = function(...) invisible(NULL),
    set_gh_var             = function(...) invisible(NULL),
    sync_pb_registry_state = function(...) stop("registry lookup stubbed out for this test"),
    .env = env
  )
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(name = character(), url = character()),
    .package = "gert",
    .env = env
  )
  local_mocked_bindings(
    setup_quarto = function(...) invisible(NULL),
    .package = "ofce",
    .env = env
  )
}

build_pb_repo <- function(dir, pb = 3L) {
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = pb,
    lang    = "fr",
    version = "v0",
    website = list(
      title       = "Un PB",
      `site-url`  = "https://www.ofce.fr/",
      `site-path` = sprintf("%d/v0", pb)
    )
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un PB")
  invisible(dir)
}

# Minimal published-PB repo carrying a legacy zero-padded site-path.
build_legacy_padded_pb_repo <- function(dir, pb = 7L) {
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = pb,
    lang    = "fr",
    version = "v0",
    website = list(
      title       = "Un PB hérité",
      `site-url`  = "https://www.ofce.fr/",
      `site-path` = sprintf("%03d/v0", pb)
    )
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un PB hérité")
  invisible(dir)
}

# Minimal draft (unpublished, pb = NULL) PB repo -- used to exercise the
# stage-target "auto" resolution and the draft website.site-url computation.
build_draft_pb_repo <- function(dir) {
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    lang    = "fr"
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Brouillon")
  invisible(dir)
}

test_that("setup_pb() computes citation.issue/citation.url and stable_url for a published PB", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  build_pb_repo(dir, pb = 5L)

  suppressMessages(setup_pb(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$citation$issue, "5")
  expect_equal(yml$citation$url, "https://www.ofce.fr/pb/5/")
  # stable_url mirrors citation.url as a top-level key.
  expect_equal(yml$stable_url, "https://www.ofce.fr/pb/5/")
})

test_that("setup_pb() does not set citation.issue/url/stable_url for a draft (pb = NULL)", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = NULL,
    lang    = "fr",
    website = list(title = "Un brouillon PB")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un brouillon PB")

  suppressMessages(setup_pb(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_null(yml$pb)
  expect_null(yml$citation$issue)
  expect_null(yml$citation$url)
  expect_null(yml$stable_url)
})

test_that("setup_pb() rewrites a legacy zero-padded site-path to the unpadded form", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  build_legacy_padded_pb_repo(dir, pb = 7L)

  suppressMessages(setup_pb(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$website$`site-path`, "7/v0")
  expect_equal(yml$citation$url, "https://www.ofce.fr/pb/7/")
  expect_equal(yml$citation$issue, "7")
  expect_equal(yml$stable_url, "https://www.ofce.fr/pb/7/")
})

test_that("setup_pb() computes a missing site-path from an existing pb, without re-passing pb", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 4L,
    lang    = "fr",
    website = list(title = "Sans site-path")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Sans site-path")

  suppressMessages(setup_pb(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$website$`site-path`, "4")
  expect_equal(yml$website$`site-url`, "https://www.ofce.fr/")
})

test_that("setup_pb() warns that the deployment URL changes when the site-path is rewritten", {
  local_stub_pb_side_effects()
  withr::local_options(cli.width = 300)
  dir <- withr::local_tempdir()
  build_legacy_padded_pb_repo(dir, pb = 7L)

  msgs <- capture_messages(setup_pb(dir))

  expect_true(any(grepl("site-path modifi", msgs)))
  expect_true(any(grepl("URL diff", msgs)))
  expect_true(any(grepl("007/v0", msgs, fixed = TRUE)))
  expect_true(any(grepl("7/v0", msgs, fixed = TRUE)))
})

test_that("setup_pb() does not warn when the site-path is already unpadded", {
  local_stub_pb_side_effects()
  withr::local_options(cli.width = 300)
  dir <- withr::local_tempdir()
  build_pb_repo(dir, pb = 7L)

  msgs <- capture_messages(setup_pb(dir))

  expect_false(any(grepl("site-path modifi", msgs)))
})

test_that("setup_pb() installs Quarto extensions via ofce::setup_quarto()", {
  calls <- list()
  local_mocked_bindings(
    init_gh_pages_branch   = function(...) invisible(NULL),
    set_gh_var             = function(...) invisible(NULL),
    sync_pb_registry_state = function(...) stop("registry lookup stubbed out for this test")
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
  build_pb_repo(dir)

  suppressMessages(setup_pb(dir))

  expect_length(calls, 1L)
  expect_equal(fs::path_norm(calls[[1L]]), fs::path_norm(dir))
})

test_that("setup_pb() lets a confirmed registry entry override the existing _quarto.yml values", {
  local_mocked_bindings(
    init_gh_pages_branch = function(...) invisible(NULL),
    set_gh_var            = function(...) invisible(NULL),
    fetch_pb_entries      = function(...) list(
      list(pb = 4L, type = "repo", `source-repo` = "ofce/pb2026-1")
    )
  )
  local_mocked_bindings(
    setup_quarto = function(...) invisible(NULL),
    .package = "ofce"
  )
  dir <- withr::local_tempdir()
  build_pb_repo(dir, pb = 5L)
  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/ofce/pb2026-1.git", name = "origin", repo = dir)

  # setup_pb() has no pb= argument: the pre-existing _quarto.yml value
  # (pb = 5L) is deliberately different from the registry entry's pb (4L)
  # -- the registry entry must win.
  suppressMessages(setup_pb(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$pb, 4L)
  expect_false(yml$draft)
  expect_equal(yml$website$`site-path`, "4/v0")
  expect_equal(yml$citation$issue, "4")
  expect_equal(yml$stable_url, "https://www.ofce.fr/pb/4/")
})

test_that("setup_pb() does not assume the ofce org when no git remote is configured and gh is not authenticated", {
  local_stub_pb_side_effects()
  local_mocked_bindings(check_gh_login = function(...) invisible(NA_character_))
  dir <- withr::local_tempdir()
  build_draft_pb_repo(dir)

  expect_message(setup_pb(dir), "URL GitHub Pages")

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$`stage-target`, "auto")
  expect_false(identical(yml$website$`site-url`, sprintf("https://ofce.github.io/%s/", fs::path_file(dir))))
})

test_that("setup_pb() uses the authenticated gh account (not 'ofce') for the draft GitHub Pages URL when there is no remote", {
  local_stub_pb_side_effects()
  local_mocked_bindings(check_gh_login = function(...) invisible("someuser"))
  dir <- withr::local_tempdir()
  build_draft_pb_repo(dir)

  suppressMessages(setup_pb(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$`stage-target`, "auto")
  expect_equal(yml$website$`site-url`, sprintf("https://someuser.github.io/%s/", fs::path_file(dir)))
})

test_that("setup_pb() resolves stage-target to ftp and skips the GitHub Pages URL when the remote is under the ofce org", {
  local_stub_pb_side_effects()
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(
      name = "origin",
      url  = "https://github.com/ofce/pb-example.git"
    ),
    .package = "gert"
  )
  dir <- withr::local_tempdir()
  build_draft_pb_repo(dir)

  suppressMessages(setup_pb(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$`stage-target`, "auto")
  expect_match(yml$website$`site-url`, "^https://staging\\.ofce\\.fr/")
})

test_that("setup_pb() resolves stage-target to gh-pages and uses the real owner for a non-ofce remote", {
  local_stub_pb_side_effects()
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(
      name = "origin",
      url  = "https://github.com/someoneelse/pb-example.git"
    ),
    .package = "gert"
  )
  dir <- withr::local_tempdir()
  build_draft_pb_repo(dir)

  suppressMessages(setup_pb(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$`stage-target`, "auto")
  expect_equal(yml$website$`site-url`, "https://someoneelse.github.io/pb-example/")
})

test_that("setup_pb() comments out pb-pdf (non-blocking warning) when both PDF formats are declared", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    lang    = "fr",
    format  = list(`pb-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: PB",
    "format:",
    "  pb-pdf:",
    "    output-file: OFCEPB-draft.pdf",
    "  pb-typst:",
    "    output-file: OFCEPB-draft-typst.pdf"
  ))

  expect_message(setup_pb(dir), "pb-pdf.*pb-typst|pb-typst.*pb-pdf")

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_true(any(grepl("# pb-pdf:", idx_lines, fixed = TRUE)))
  expect_true(any(grepl("pb-typst:", idx_lines, fixed = TRUE) & !grepl("#", idx_lines, fixed = TRUE)))
  expect_true(any(grepl("output-file: OFCEPB5.pdf", idx_lines, fixed = TRUE)))

  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  links <- idx_yml$`format-links`
  expect_true(any(vapply(links, identical, logical(1L), y = "typst")))
  pdf_link <- links[[which(vapply(links, is.list, logical(1L)))]]
  expect_equal(pdf_link$format, "pb-typst")
  expect_equal(pdf_link$text, "OFCEPB5.pdf")
  expect_equal(pdf_link$icon, "file-pdf")
})

test_that("setup_pb() syncs format-links to the active PDF engine and computed output-file", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 24L,
    lang    = "fr",
    format  = list(`pb-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: PB",
    "format:",
    "  pb-html: default",
    "  pb-pdf:",
    "    output-file: OFCEPB-draft.pdf"
  ))

  suppressMessages(setup_pb(dir))

  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  links <- idx_yml$`format-links`
  expect_true(any(vapply(links, identical, logical(1L), y = "pdf")))
  pdf_link <- links[[which(vapply(links, is.list, logical(1L)))]]
  expect_equal(pdf_link$format, "pb-pdf")
  expect_equal(pdf_link$text, "OFCEPB24.pdf")
  expect_equal(pdf_link$icon, "file-pdf")
})

test_that("setup_pb() adds fig-format: png and warns when rsvg-convert is absent and pb-pdf is the sole format", {
  local_stub_pb_side_effects()
  local_mocked_bindings(check_rsvg_convert = function(...) invisible(FALSE))
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    lang    = "fr",
    format  = list(`pb-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: PB",
    "format:",
    "  pb-pdf:",
    "    output-file: OFCEPB-draft.pdf"
  ))

  expect_message(setup_pb(dir), "rsvg-convert")

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_true(any(grepl("fig-format: png", idx_lines, fixed = TRUE)))
})

test_that("setup_pb() does not touch fig-format when rsvg-convert is present", {
  local_stub_pb_side_effects()
  local_mocked_bindings(check_rsvg_convert = function(...) invisible(TRUE))
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    lang    = "fr",
    format  = list(`pb-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: PB",
    "format:",
    "  pb-pdf:",
    "    output-file: OFCEPB-draft.pdf"
  ))

  suppressMessages(setup_pb(dir))

  idx_lines <- readLines(fs::path(dir, "index.qmd"))
  expect_false(any(grepl("fig-format", idx_lines, fixed = TRUE)))
})

test_that("setup_pb() leaves a sole pb-typst declaration untouched -- no pb-pdf is added", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    lang    = "fr",
    format  = list(`pb-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: PB",
    "format:",
    "  pb-typst:",
    "    output-file: OFCEPB-draft.pdf"
  ))

  suppressMessages(setup_pb(dir))

  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  expect_null(idx_yml$format$`pb-pdf`)
  expect_equal(idx_yml$format$`pb-typst`$`output-file`, "OFCEPB5.pdf")
})

# Note: unlike setup_wp(), setup_pb() has no "stray format key" comment-out
# pass (e.g. a generic `pdf:`/`html:`/`ofce-pdf:` key alongside pb-pdf/
# pb-typst) -- there is no `is_stray_pdf_format_key`/`is_stray_html_format_key`
# equivalent wired into setup_pb(). A repo with such a stray key simply keeps
# it untouched, and pdf_output stays NA (no format-links/output-file patch)
# unless the key is literally named pb-pdf or pb-typst. Not covered here
# since it isn't implemented; flagged as a possible follow-up.

test_that("setup_pb() uses the static draft PDF filename when pb is not yet assigned", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = NULL,
    lang    = "fr",
    format  = list(`pb-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: PB",
    "format:",
    "  pb-pdf:",
    "    output-file: OFCEPB-draft.pdf"
  ))

  suppressMessages(setup_pb(dir))

  idx_yml <- yaml::read_yaml(fs::path(dir, "index.qmd"))
  expect_equal(idx_yml$format$`pb-pdf`$`output-file`, "OFCEPB-draft.pdf")
})

test_that("setup_pb() is idempotent on an already-clean repo using pb-pdf", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    lang    = "fr",
    format  = list(`pb-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: PB",
    "format:",
    "  pb-pdf:",
    "    output-file: OFCEPB-draft.pdf"
  ))

  suppressMessages(setup_pb(dir))
  after_first <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )
  suppressMessages(setup_pb(dir))
  after_second <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )

  expect_identical(after_first$yml, after_second$yml)
  expect_identical(after_first$idx, after_second$idx)
})

test_that("setup_pb() is idempotent on an already-clean repo using pb-typst", {
  local_stub_pb_side_effects()
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    lang    = "fr",
    format  = list(`pb-html` = "default")
  ))
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: PB",
    "format:",
    "  pb-typst:",
    "    output-file: OFCEPB-draft.pdf"
  ))

  suppressMessages(setup_pb(dir))
  after_first <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )
  suppressMessages(setup_pb(dir))
  after_second <- list(
    yml = readLines(fs::path(dir, "_quarto.yml")),
    idx = readLines(fs::path(dir, "index.qmd"))
  )

  expect_identical(after_first$yml, after_second$yml)
  expect_identical(after_first$idx, after_second$idx)
})
