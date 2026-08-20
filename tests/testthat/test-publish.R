# publish() dispatches to publish_wp()/publish_prev()/publish_blog()/
# stage_site() based on detect_repo_type() — the same detection logic used
# by render() (see R/render.R for detect_repo_type() and its own tests).
# Site has no dedicated publish_site(): stage_site() (render + deploy)
# stands in for it, since generic sites have no staging/publish split.

test_that("publish() dispatches to publish_wp() for a WP repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    publish_wp   = function(path, ...) { called <<- TRUE; invisible(NULL) },
    publish_prev = function(...) stop("should not be called"),
    publish_blog = function(...) stop("should not be called"),
    stage_site   = function(...) stop("should not be called")
  )

  suppressMessages(publish(dir))
  expect_true(called)
})

test_that("publish() dispatches to publish_prev() for a prev repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_prev = TRUE, prev = 3L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    publish_wp   = function(...) stop("should not be called"),
    publish_prev = function(path, ...) { called <<- TRUE; invisible(NULL) },
    publish_blog = function(...) stop("should not be called"),
    stage_site   = function(...) stop("should not be called")
  )

  suppressMessages(publish(dir))
  expect_true(called)
})

test_that("publish() dispatches to publish_blog() for a blog repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un blog"))
  fs::dir_create(fs::path(dir, "posts"))

  called <- FALSE
  local_mocked_bindings(
    publish_wp   = function(...) stop("should not be called"),
    publish_prev = function(...) stop("should not be called"),
    publish_blog = function(path, ...) { called <<- TRUE; invisible(NULL) },
    stage_site   = function(...) stop("should not be called")
  )

  suppressMessages(publish(dir))
  expect_true(called)
})

test_that("publish() dispatches to stage_site() for a generic site repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un site quelconque"))

  called <- FALSE
  local_mocked_bindings(
    publish_wp   = function(...) stop("should not be called"),
    publish_prev = function(...) stop("should not be called"),
    publish_blog = function(...) stop("should not be called"),
    stage_site   = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(publish(dir))
  expect_true(called)
})

test_that("publish() forwards path and extra arguments to the dispatched function", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))

  captured <- NULL
  local_mocked_bindings(
    publish_wp = function(path, workers = 8L, ...) {
      captured <<- list(path = path, workers = workers)
      invisible(NULL)
    }
  )

  suppressMessages(publish(dir, workers = 2L))
  expect_equal(captured$path, dir)
  expect_equal(captured$workers, 2L)
})

test_that("publish() honours an explicit type= override", {
  dir <- withr::local_tempdir()
  # No markers at all: detect_repo_type() would normally error, but an
  # explicit `type=` bypasses detection entirely.
  called <- FALSE
  local_mocked_bindings(
    stage_site = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(publish(dir, type = "site"))
  expect_true(called)
})

test_that("publish() errors with a French message when nothing is recognised", {
  dir <- withr::local_tempdir()
  expect_error(publish(dir), "Aucun type")
})
