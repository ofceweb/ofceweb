# registry_request() dispatches to wp_registry_request()/pb_registry_request()
# -- the only two types with a central registry (ofce/wp-registry) today.
# Every other type fails fast with an explicit message (R/registry_request.R).

test_that("registry_request() dispatches to wp_registry_request() for a WP repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_wp = TRUE, wp = 12L, annee = 2026L))

  called <- FALSE
  local_mocked_bindings(
    wp_registry_request = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(registry_request(dir))
  expect_true(called)
})

test_that("registry_request() dispatches to pb_registry_request() for a pb repo", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_pb = TRUE, pb = 5L))

  called <- FALSE
  local_mocked_bindings(
    pb_registry_request = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(registry_request(dir))
  expect_true(called)
})

test_that("registry_request() errors for a prev repo (no registry)", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_prev = TRUE, prev = 3L, annee = 2026L))

  expect_error(suppressMessages(registry_request(dir)), "registre")
})

test_that("registry_request() errors for an ife repo (no registry)", {
  dir <- fs::path(withr::local_tempdir(), "ife_webhome")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(project = list(type = "ife-website")))

  expect_error(suppressMessages(registry_request(dir)), "registre")
})

test_that("registry_request() errors for a home repo (no registry)", {
  dir <- fs::path(withr::local_tempdir(), "webhome")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(ofce_home = TRUE))

  expect_error(suppressMessages(registry_request(dir)), "registre")
})

test_that("registry_request() errors for a blog repo (no registry)", {
  dir <- fs::path(withr::local_tempdir(), "webblog")
  fs::dir_create(dir)
  write_quarto_yml(dir, list(title = "Un blog"))
  fs::dir_create(fs::path(dir, "posts"))

  expect_error(suppressMessages(registry_request(dir)), "registre")
})

test_that("registry_request() errors for a generic site repo (no registry)", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(title = "Un site quelconque"))

  expect_error(suppressMessages(registry_request(dir)), "registre")
})

test_that("registry_request() honours an explicit type= override", {
  dir <- withr::local_tempdir()
  called <- FALSE
  local_mocked_bindings(
    wp_registry_request = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  suppressMessages(registry_request(dir, type = "wp"))
  expect_true(called)
})
