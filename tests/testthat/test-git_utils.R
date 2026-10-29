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

# ---- registry_diag_rows() ----------------------------------------------------

pb_reg_entries <- function() list(
  list(pb = 3L, pb_series = "ife", type = "repo", `source-repo` = "ofce/pb-x"),
  list(pb = 3L, pb_series = "ofce", type = "repo", `source-repo` = "ofce/pb-y")
)

test_that("registry_diag_rows(kind = 'pb') is ok when number and series both match", {
  rows <- registry_diag_rows(pb_reg_entries(), "ofce/pb-x", 3L, kind = "pb",
                             local_series = "ife")
  expect_length(rows, 1L)
  expect_equal(rows[[1L]]$status, "ok")
})

test_that("registry_diag_rows(kind = 'pb') warns on a series mismatch even if the number matches", {
  rows <- registry_diag_rows(pb_reg_entries(), "ofce/pb-x", 3L, kind = "pb",
                             local_series = "ofce")
  expect_equal(rows[[1L]]$status, "warning")
  expect_match(rows[[1L]]$message, "pb/pb_series locaux (3/ofce)", fixed = TRUE)
  expect_match(rows[[1L]]$message, "(3/ife)", fixed = TRUE)
  expect_match(rows[[1L]]$message, "setup_pb()", fixed = TRUE)
})

test_that("registry_diag_rows(kind = 'pb') warns on a number mismatch with a matching series", {
  rows <- registry_diag_rows(pb_reg_entries(), "ofce/pb-x", 4L, kind = "pb",
                             local_series = "ife")
  expect_equal(rows[[1L]]$status, "warning")
})

test_that("registry_diag_rows(kind = 'pb') without local_series only compares the number", {
  rows <- registry_diag_rows(pb_reg_entries(), "ofce/pb-x", 3L, kind = "pb")
  expect_equal(rows[[1L]]$status, "ok")
})

test_that("registry_diag_rows(kind = 'wp') is unchanged by local_series handling", {
  entries <- list(list(wp = 12L, annee = 2024L, type = "repo", `source-repo` = "ofce/wp-x"))
  ok <- registry_diag_rows(entries, "ofce/wp-x", 12L, 2024L, kind = "wp")
  expect_equal(ok[[1L]]$status, "ok")
  expect_match(ok[[1L]]$message, "wp/annee locaux (12/2024)", fixed = TRUE)
  bad <- registry_diag_rows(entries, "ofce/wp-x", 13L, 2024L, kind = "wp")
  expect_equal(bad[[1L]]$status, "warning")
  expect_match(bad[[1L]]$message, "setup_wp()", fixed = TRUE)
})
