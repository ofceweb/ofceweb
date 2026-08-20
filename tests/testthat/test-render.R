# render() dispatches to render_wp()/render_site()/render_prev()/render_blog()
# based on detect_repo_type(), which reads `_quarto.yml` markers and folder
# structure. See R/render.R.

# ---- detect_repo_type() ----------------------------------------------------

test_that("detect_repo_type() recognises a WP repo via ofce_wp: true", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))
  expect_equal(detect_repo_type(dir), "wp")
})

test_that("detect_repo_type() recognises a prev repo via ofce_prev: true", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_prev = TRUE, prev = 3L, annee = 2026L))
  expect_equal(detect_repo_type(dir), "prev")
})

test_that("detect_repo_type() recognises a blog via a posts/ directory", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un blog"))
  fs::dir_create(fs::path(dir, "posts"))
  expect_equal(detect_repo_type(dir), "blog")
})

test_that("detect_repo_type() falls back to site when _quarto.yml has no marker", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un site quelconque"))
  expect_equal(detect_repo_type(dir), "site")
})

test_that("detect_repo_type() errors when both ofce_wp and ofce_prev are true", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, ofce_prev = TRUE))
  expect_error(detect_repo_type(dir), "incoh")
})

test_that("detect_repo_type() errors and suggests setup_* when nothing is recognised", {
  dir <- withr::local_tempdir()
  expect_error(detect_repo_type(dir), "Aucun type")
})

# ---- render() dispatch ------------------------------------------------------

test_that("render() dispatches to render_wp() for a WP repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    render_wp   = function(path, ...) { called <<- TRUE; invisible(NULL) },
    render_site = function(...) stop("should not be called"),
    render_prev = function(...) stop("should not be called"),
    render_blog = function(...) stop("should not be called")
  )

  suppressMessages(render(dir))
  expect_true(called)
})

test_that("render() dispatches to render_prev() for a prev repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_prev = TRUE, prev = 3L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    render_wp   = function(...) stop("should not be called"),
    render_site = function(...) stop("should not be called"),
    render_prev = function(path, ...) { called <<- TRUE; invisible(NULL) },
    render_blog = function(...) stop("should not be called")
  )

  suppressMessages(render(dir))
  expect_true(called)
})

test_that("render() dispatches to render_blog() for a blog repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un blog"))
  fs::dir_create(fs::path(dir, "posts"))

  called <- FALSE
  local_mocked_bindings(
    render_wp   = function(...) stop("should not be called"),
    render_site = function(...) stop("should not be called"),
    render_prev = function(...) stop("should not be called"),
    render_blog = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(render(dir))
  expect_true(called)
})

test_that("render() dispatches to render_site() for a generic site repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un site quelconque"))

  called <- FALSE
  local_mocked_bindings(
    render_wp   = function(...) stop("should not be called"),
    render_site = function(path, ...) { called <<- TRUE; invisible(NULL) },
    render_prev = function(...) stop("should not be called"),
    render_blog = function(...) stop("should not be called")
  )

  suppressMessages(render(dir))
  expect_true(called)
})

test_that("render() forwards path and extra arguments to the dispatched function", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))

  captured <- NULL
  local_mocked_bindings(
    render_wp = function(path, workers = 8L, ...) {
      captured <<- list(path = path, workers = workers)
      invisible(NULL)
    }
  )

  suppressMessages(render(dir, workers = 2L))
  expect_equal(captured$path, dir)
  expect_equal(captured$workers, 2L)
})

test_that("render() honours an explicit type= override", {
  dir <- withr::local_tempdir()
  # No markers at all: detect_repo_type() would normally error, but an
  # explicit `type=` bypasses detection entirely.
  called <- FALSE
  local_mocked_bindings(
    render_site = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(render(dir, type = "site"))
  expect_true(called)
})

test_that("render() errors with a French message when nothing is recognised", {
  dir <- withr::local_tempdir()
  expect_error(render(dir), "Aucun type")
})
