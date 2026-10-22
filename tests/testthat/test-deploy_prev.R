# deploy_prev() reads _quarto-staging.yml/_quarto-publish.yml and resyncs
# FTP_STAGING_DIR/FTP_PUBLISH_DIR from the current site-path right before
# pushing, so a hand-edited version/site-path doesn't silently deploy to a
# stale FTP directory. Custom profiles are untouched: ftp_deploy_profile.yml
# computes server-dir inline (repo name + profile input), no GitHub variable
# involved.

test_that("deploy_prev(profile = 'staging') resyncs FTP_STAGING_DIR from the current _quarto-staging.yml", {
  dir <- withr::local_tempdir()
  yaml::write_yaml(
    list(website = list(`site-path` = "prev2601/v4")),
    fs::path(dir, "_quarto-staging.yml")
  )
  fs::dir_create(fs::path(dir, "_site_staging"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var  = function(root, name, value) { gh_vars[[name]] <<- value; invisible(NULL) },
    site2staging = function(...) invisible(NULL)
  )

  suppressMessages(deploy_prev(dir, profile = "staging", progress = FALSE, trigger = FALSE))

  expect_equal(gh_vars[["FTP_STAGING_DIR"]], "prev2601/v4/")
})

test_that("deploy_prev(profile = 'publish') resyncs FTP_PUBLISH_DIR from the current _quarto-publish.yml", {
  dir <- withr::local_tempdir()
  yaml::write_yaml(
    list(website = list(`site-path` = "prev/prev2601")),
    fs::path(dir, "_quarto-publish.yml")
  )
  fs::dir_create(fs::path(dir, "_site_publish"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var  = function(root, name, value) { gh_vars[[name]] <<- value; invisible(NULL) },
    site2publish = function(...) invisible(NULL)
  )

  suppressMessages(deploy_prev(dir, profile = "publish", progress = FALSE, trigger = FALSE))

  expect_equal(gh_vars[["FTP_PUBLISH_DIR"]], "prev/prev2601/")
})

test_that("deploy_prev() does not touch any GitHub variable for a custom profile", {
  dir <- withr::local_tempdir()
  fs::dir_create(fs::path(dir, "_site_custom"))

  called <- FALSE
  local_mocked_bindings(
    set_gh_var   = function(...) { called <<- TRUE; invisible(NULL) },
    site2profile = function(...) invisible(NULL)
  )

  suppressMessages(deploy_prev(dir, profile = "custom", progress = FALSE, trigger = FALSE))

  expect_false(called)
})
