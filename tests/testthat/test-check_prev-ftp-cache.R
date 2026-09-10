# check_prev()'s FTP_STAGING_DIR/FTP_PUBLISH_DIR variable check and
# STATICRYPT_PASSWORD secret check spawn the `gh` CLI; both are cached per
# repo root via gh_cached_check() (shared with check_gh_login() and
# adhoc_check_deploy_prereqs()) so repeated check_prev() calls in the same
# session don't re-spawn `gh` every time -- see git_utils.R.
#
# Only a minimal `_quarto.yml` is needed here: check_prev() only returns
# early (skipping steps 11/12) when `_quarto.yml` is absent or unreadable.

reset_gh_checks_cache <- function() {
  rm(list = ls(envir = .gh_checks_cache), envir = .gh_checks_cache)
}

test_that("check_prev(): caches the gh CLI variable/secret lookups per repo root", {
  reset_gh_checks_cache()
  dir <- withr::local_tempdir()
  writeLines("ofce_prev: true", fs::path(dir, "_quarto.yml"))

  variable_calls <- 0L
  secret_calls   <- 0L

  local_mocked_bindings(
    Sys.which = function(...) "/usr/bin/gh",
    system2   = function(command, args, ...) {
      if (identical(args[[1]], "variable")) {
        variable_calls <<- variable_calls + 1L
        return('{"name":["FTP_STAGING_DIR","FTP_PUBLISH_DIR"]}')
      }
      if (identical(args[[1]], "secret")) {
        secret_calls <<- secret_calls + 1L
        return('{"name":["STATICRYPT_PASSWORD"]}')
      }
      if (identical(args[[1]], "api")) return(character())
      0L
    },
    .package = "base"
  )

  df1 <- check_prev(dir, verbose = FALSE)
  expect_equal(variable_calls, 1L)
  expect_equal(secret_calls, 1L)
  expect_equal(diag_status(df1, "FTP_STAGING_DIR"), "ok")
  expect_equal(diag_status(df1, "STATICRYPT_PASSWORD"), "ok")

  # Second call for the same repo: cache hit, no new `gh` subprocess calls.
  df2 <- check_prev(dir, verbose = FALSE)
  expect_equal(variable_calls, 1L)
  expect_equal(secret_calls, 1L)
  expect_equal(diag_status(df2, "FTP_STAGING_DIR"), "ok")

  # A direct check_gh_setup() call invalidates the cache for the next check_prev().
  local_mocked_bindings(
    git_config_get = function(name, repo = ".") {
      if (name == "user.name") "Jane Doe" else "jane@example.com"
    },
    .package = "gert"
  )
  withr::local_envvar(DEPLOY_PAT = "ghp_dummy")
  check_gh_setup(dir, verbose = FALSE)

  df3 <- check_prev(dir, verbose = FALSE)
  expect_equal(variable_calls, 2L)
  expect_equal(secret_calls, 2L)
})
