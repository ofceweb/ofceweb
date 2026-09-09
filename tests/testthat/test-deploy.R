# deploy() dispatches to the internal deploy_xxx() functions based on
# detect_repo_type() -- same detection as render()/publish(). `blog` has no
# deploy entry in the shared dispatch table (R/repo_type.R): publishing a
# post goes through publish_blog(), not a separate deploy step.

test_that("deploy() dispatches to deploy_wp() for a WP repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    deploy_wp = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(deploy(dir))
  expect_true(called)
})

test_that("deploy() dispatches to deploy_prev() for a prev repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_prev = TRUE, prev = 3L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    deploy_prev = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(deploy(dir))
  expect_true(called)
})

test_that("deploy() dispatches to deploy_pb() for a pb repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_pb = TRUE, pb = 5L))

  called <- FALSE
  local_mocked_bindings(
    deploy_pb = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(deploy(dir))
  expect_true(called)
})

test_that("deploy() dispatches to deploy_ife() for an ife repo", {
  dir <- fs::path(withr::local_tempdir(), "ife_webhome")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(project = list(type = "ife-website")))

  called <- FALSE
  local_mocked_bindings(
    deploy_ife = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(deploy(dir))
  expect_true(called)
})

test_that("deploy() dispatches to deploy_home() for a home repo", {
  dir <- fs::path(withr::local_tempdir(), "webhome")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(ofce_home = TRUE))

  called <- FALSE
  local_mocked_bindings(
    deploy_home = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(deploy(dir))
  expect_true(called)
})

test_that("deploy() dispatches to deploy_site() for a generic site repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un site quelconque"))

  called <- FALSE
  local_mocked_bindings(
    deploy_site = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(deploy(dir))
  expect_true(called)
})

test_that("deploy() has no deploy available for a blog repo", {
  dir <- fs::path(withr::local_tempdir(), "webblog")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(title = "Un blog"))
  fs::dir_create(fs::path(dir, "posts"))

  expect_error(suppressMessages(deploy(dir)), "Pas de.*deploy")
})

test_that("deploy() honours an explicit type= override", {
  dir <- withr::local_tempdir()
  called <- FALSE
  local_mocked_bindings(
    deploy_site = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(deploy(dir, type = "site"))
  expect_true(called)
})
