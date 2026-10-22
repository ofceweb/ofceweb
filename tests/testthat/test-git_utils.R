test_that("resolve_stage_target() returns canonical values unchanged", {
  expect_equal(resolve_stage_target("gh-pages"), "gh-pages")
  expect_equal(resolve_stage_target("ftp"), "ftp")
})

test_that("resolve_stage_target() maps the legacy 'ofce' alias to 'ftp'", {
  expect_equal(resolve_stage_target("ofce"), "ftp")
  expect_equal(resolve_stage_target("ofce", org = "someoneelse"), "ftp")
})

test_that("resolve_stage_target() resolves 'auto' to 'ftp' for the ofce org (case-insensitive)", {
  expect_equal(resolve_stage_target("auto", org = "ofce"), "ftp")
  expect_equal(resolve_stage_target("auto", org = "OFCE"), "ftp")
})

test_that("resolve_stage_target() resolves 'auto' to 'gh-pages' for any other org or unknown org", {
  expect_equal(resolve_stage_target("auto", org = "someoneelse"), "gh-pages")
  expect_equal(resolve_stage_target("auto", org = NA_character_), "gh-pages")
  expect_equal(resolve_stage_target("auto"), "gh-pages")
})

test_that("resolve_stage_target() rejects unrecognized values", {
  expect_error(resolve_stage_target("bogus"))
})

# ---- sync_ftp_dir_var() -----------------------------------------------------
#
# Shared by deploy_wp()/deploy_pb()/deploy_prev() to resynchronize a single
# FTP GitHub variable from whatever _quarto.yml/profile file currently says,
# immediately before triggering a deploy.

test_that("sync_ftp_dir_var() appends a missing trailing slash", {
  captured <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) { captured[[name]] <<- value; invisible(NULL) }
  )
  sync_ftp_dir_var("dummy", "FTP_SERVER_DIR", "2024/12/v1")
  expect_equal(captured[["FTP_SERVER_DIR"]], "2024/12/v1/")
})

test_that("sync_ftp_dir_var() leaves an already slash-terminated value untouched", {
  captured <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) { captured[[name]] <<- value; invisible(NULL) }
  )
  sync_ftp_dir_var("dummy", "FTP_SERVER_DIR", "2024/12/v1/")
  expect_equal(captured[["FTP_SERVER_DIR"]], "2024/12/v1/")
})

test_that("sync_ftp_dir_var() is a no-op for NULL or empty values", {
  called <- FALSE
  local_mocked_bindings(set_gh_var = function(...) { called <<- TRUE; invisible(NULL) })
  sync_ftp_dir_var("dummy", "FTP_SERVER_DIR", NULL)
  sync_ftp_dir_var("dummy", "FTP_SERVER_DIR", "")
  expect_false(called)
})

test_that("sync_ftp_dir_var() downgrades a set_gh_var() error to a non-blocking message", {
  local_mocked_bindings(set_gh_var = function(...) stop("boom"))
  expect_message(sync_ftp_dir_var("dummy", "FTP_SERVER_DIR", "x"), "non resynchronis")
})
