# prev_version_up(), wp_version_up() and site_version_up() all read
# `_quarto.yml`/`_quarto-staging.yml` via yaml::read_yaml() for logic, but
# must write back through the comment-preserving yaml_patch_*() primitives
# (see R/yaml_patch.R) rather than yaml::write_yaml(), which would silently
# drop comments, blank lines and key ordering on every version bump.
#
# local_stub_version_up_side_effects() lives in helper-repo-fixtures.R
# (shared with test-setup_wp.R).

# ---- wp_version_up() -------------------------------------------------------

test_that("wp_version_up() preserves comments and layout in _quarto.yml", {
  local_stub_version_up_side_effects()
  dir <- withr::local_tempdir()
  writeLines(c(
    "# Quarto config for this working paper",
    "ofce_wp: true",
    "wp: 12",
    "annee: 2026",
    "",
    "# --- website section ---",
    "website:",
    "  title: A working paper",
    "  site-path: 2026/12/v0",
    "version: v0"
  ), fs::path(dir, "_quarto.yml"))

  suppressMessages(wp_version_up(dir))
  lines <- readLines(fs::path(dir, "_quarto.yml"))

  expect_true(any(grepl("^# Quarto config", lines)))
  expect_true(any(grepl("^# --- website section", lines)))
  expect_true(any(grepl("^$", lines))) # blank line preserved

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$version, "v1")
  expect_equal(yml$website$`site-path`, "2026/12/v1")
  # Untouched fields still intact.
  expect_true(isTRUE(yml$ofce_wp))
  expect_equal(yml$wp, 12L)
})

test_that("wp_version_up() honours custom_version and updates site-path accordingly", {
  local_stub_version_up_side_effects()
  dir <- withr::local_tempdir()
  writeLines(c(
    "ofce_wp: true",
    "wp: 3",
    "annee: 2026",
    "version: v1",
    "website:",
    "  site-path: 2026/3/v1"
  ), fs::path(dir, "_quarto.yml"))

  suppressMessages(wp_version_up(dir, custom_version = "v2_corr"))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$version, "v2_corr")
  expect_equal(yml$website$`site-path`, "2026/3/v2_corr")
})

# ---- site_version_up() -----------------------------------------------------

test_that("site_version_up() preserves comments and layout in _quarto.yml", {
  local_stub_version_up_side_effects()
  dir <- withr::local_tempdir()
  writeLines(c(
    "# site config",
    "ofce_host: true",
    "",
    "website:",
    "  # main title",
    "  title: A site",
    "  site-path: 2026/v3"
  ), fs::path(dir, "_quarto.yml"))

  suppressMessages(site_version_up(dir))
  lines <- readLines(fs::path(dir, "_quarto.yml"))

  expect_true(any(grepl("^# site config", lines)))
  expect_true(any(grepl("main title", lines)))
  expect_true(any(grepl("^$", lines))) # blank line preserved

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$website$`site-path`, "2026/v4")
  expect_true(isTRUE(yml$ofce_host))
})

test_that("site_version_up() honours custom_version", {
  local_stub_version_up_side_effects()
  dir <- withr::local_tempdir()
  writeLines(c(
    "ofce_host: true",
    "website:",
    "  site-path: 2026/v3"
  ), fs::path(dir, "_quarto.yml"))

  suppressMessages(site_version_up(dir, custom_version = "v3_rc"))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$website$`site-path`, "2026/v3_rc")
})

# ---- prev_version_up() -----------------------------------------------------

test_that("prev_version_up() preserves comments and layout in _quarto-staging.yml", {
  local_stub_version_up_side_effects()
  dir <- withr::local_tempdir()
  writeLines(c(
    "# main quarto config",
    "ofce_prev: true"
  ), fs::path(dir, "_quarto.yml"))
  writeLines(c(
    "# staging config",
    "version: v2",
    "",
    "website:",
    "  # staging path",
    "  site-path: staging/2026/v2"
  ), fs::path(dir, "_quarto-staging.yml"))

  suppressMessages(prev_version_up(dir))
  lines <- readLines(fs::path(dir, "_quarto-staging.yml"))

  expect_true(any(grepl("^# staging config", lines)))
  expect_true(any(grepl("staging path", lines)))
  expect_true(any(grepl("^$", lines))) # blank line preserved

  stg <- yaml::read_yaml(fs::path(dir, "_quarto-staging.yml"))
  expect_equal(stg$version, "v3")
  expect_equal(stg$website$`site-path`, "staging/2026/v3")
})

test_that("prev_version_up() honours custom_version", {
  local_stub_version_up_side_effects()
  dir <- withr::local_tempdir()
  writeLines(c("ofce_prev: true"), fs::path(dir, "_quarto.yml"))
  writeLines(c(
    "version: v1",
    "website:",
    "  site-path: staging/2026/v1"
  ), fs::path(dir, "_quarto-staging.yml"))

  suppressMessages(prev_version_up(dir, custom_version = "v1_hotfix"))
  stg <- yaml::read_yaml(fs::path(dir, "_quarto-staging.yml"))

  expect_equal(stg$version, "v1_hotfix")
  expect_equal(stg$website$`site-path`, "staging/2026/v1_hotfix")
})

test_that("prev_version_up() aborts when not a prevision repo", {
  local_stub_version_up_side_effects()
  dir <- withr::local_tempdir()
  writeLines(c("ofce_wp: true"), fs::path(dir, "_quarto.yml"))
  writeLines(c("version: v0"), fs::path(dir, "_quarto-staging.yml"))

  expect_error(prev_version_up(dir), "setup_prev")
})

# ---- version_up() dispatcher -----------------------------------------------
#
# version_up() dispatches to wp_version_up()/pb_version_up()/
# prev_version_up()/site_version_up() -- the only per-repo-root version
# incrementers available today (R/repo_type.R). `ife`/`home`/`blog` have no
# `version_up` entry.

test_that("version_up() dispatches to wp_version_up() for a WP repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    wp_version_up = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(version_up(dir))
  expect_true(called)
})

test_that("version_up() dispatches to pb_version_up() for a pb repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_pb = TRUE, pb = 5L))

  called <- FALSE
  local_mocked_bindings(
    pb_version_up = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(version_up(dir))
  expect_true(called)
})

test_that("version_up() dispatches to prev_version_up() for a prev repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_prev = TRUE, prev = 3L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    prev_version_up = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(version_up(dir))
  expect_true(called)
})

test_that("version_up() dispatches to site_version_up() for a generic site repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un site quelconque"))

  called <- FALSE
  local_mocked_bindings(
    site_version_up = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(version_up(dir))
  expect_true(called)
})

test_that("version_up() has no version_up available for an ife repo", {
  dir <- fs::path(withr::local_tempdir(), "ife_webhome")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(project = list(type = "ife-website")))

  expect_error(suppressMessages(version_up(dir)), "Pas de.*version_up")
})

test_that("version_up() has no version_up available for a home repo", {
  dir <- fs::path(withr::local_tempdir(), "webhome")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(ofce_home = TRUE))

  expect_error(suppressMessages(version_up(dir)), "Pas de.*version_up")
})

test_that("version_up() has no version_up available for a blog repo", {
  dir <- fs::path(withr::local_tempdir(), "webblog")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(title = "Un blog"))
  fs::dir_create(fs::path(dir, "posts"))

  expect_error(suppressMessages(version_up(dir)), "Pas de.*version_up")
})

test_that("version_up() honours an explicit type= override", {
  dir <- withr::local_tempdir()
  called <- FALSE
  local_mocked_bindings(
    wp_version_up = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(version_up(dir, type = "wp"))
  expect_true(called)
})
