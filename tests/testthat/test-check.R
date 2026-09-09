# check() dispatches to check_wp()/check_prev()/check_pb() -- the only
# per-repo-root diagnostics available today (R/repo_type.R). `ife`/`home`/
# `site`/`blog` have no `check` entry: `blog` additionally has a per-post
# check_blog() that intentionally does not fit check()'s
# `path = <repo root>` contract (see submit_blog()).

test_that("check() dispatches to check_wp() for a WP repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    check_wp = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(check(dir))
  expect_true(called)
})

test_that("check() dispatches to check_prev() for a prev repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_prev = TRUE, prev = 3L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    check_prev = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(check(dir))
  expect_true(called)
})

test_that("check() dispatches to check_pb() for a pb repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_pb = TRUE, pb = 5L))

  called <- FALSE
  local_mocked_bindings(
    check_pb = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(check(dir))
  expect_true(called)
})

test_that("check() has no check available for an ife repo", {
  dir <- fs::path(withr::local_tempdir(), "ife_webhome")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(project = list(type = "ife-website")))

  expect_error(suppressMessages(check(dir)), "Pas de.*check")
})

test_that("check() has no check available for a home repo", {
  dir <- fs::path(withr::local_tempdir(), "webhome")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(ofce_home = TRUE))

  expect_error(suppressMessages(check(dir)), "Pas de.*check")
})

test_that("check() has no check available for a generic site repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un site quelconque"))

  expect_error(suppressMessages(check(dir)), "Pas de.*check")
})

test_that("check() has no check available for a blog repo and points to submit_blog()", {
  dir <- fs::path(withr::local_tempdir(), "webblog")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(title = "Un blog"))
  fs::dir_create(fs::path(dir, "posts"))

  expect_error(suppressMessages(check(dir)), "submit_blog")
})

test_that("check() honours an explicit type= override", {
  dir <- withr::local_tempdir()
  called <- FALSE
  local_mocked_bindings(
    check_wp = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(check(dir, type = "wp"))
  expect_true(called)
})
