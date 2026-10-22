# deploy_wp() must resynchronize the FTP GitHub variable that the workflow it
# is about to trigger relies on (FTP_SERVER_DIR for production,
# FTP_STAGING_DIR for FTP staging) from whatever _quarto.yml currently says --
# not whatever setup_wp()/wp_version_up() last wrote -- so a manual edit to
# `version`/`website.site-path` (or a merge) doesn't silently deploy to a
# stale FTP directory. See R/deploy_wp.R + sync_ftp_dir_var() in
# R/git_utils.R.

test_that("deploy_wp() resyncs FTP_SERVER_DIR from the current site-path before a production deploy", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    annee   = 2024L,
    wp      = 12L,
    version = "v2",
    website = list(`site-path` = "2024/12/v2")
  ))
  # Deliberately NOT what wp_version_up()/setup_wp() would have produced for
  # an earlier version -- simulates _quarto.yml having been hand-edited (or
  # merged) since the last time one of those ran.
  jsonlite::write_json(
    list(stage = FALSE, annee = 2024L, wp = 12L),
    fs::path(dir, "manifest.json"),
    auto_unbox = TRUE
  )
  fs::dir_create(fs::path(dir, "_site"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) { gh_vars[[name]] <<- value; invisible(NULL) },
    site2branch = function(...) invisible(NULL),
    push_wp_redirect = function(...) invisible(NULL)
  )

  suppressMessages(deploy_wp(dir, progress = FALSE, trigger = FALSE))

  expect_equal(gh_vars[["FTP_SERVER_DIR"]], "2024/12/v2/")
})

test_that("deploy_wp() resyncs FTP_STAGING_DIR from the current repo/version before an FTP-staging deploy", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_wp        = TRUE,
    draft          = TRUE,
    version        = "v3",
    `stage-target` = "ftp",
    website        = list(`site-url` = "https://staging.ofce.fr/test-wp/v3/")
  ))
  jsonlite::write_json(
    list(stage = TRUE, `source-repo` = "ofce/test-wp"),
    fs::path(dir, "manifest.json"),
    auto_unbox = TRUE
  )
  fs::dir_create(fs::path(dir, "_site"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) { gh_vars[[name]] <<- value; invisible(NULL) },
    site2branch = function(...) invisible(NULL),
    push_wp_staging_redirect = function(...) invisible(NULL),
    detect_gh_owner = function(root) list(owner = "ofce", repo = "test-wp", org = "ofce")
  )

  suppressMessages(deploy_wp(dir, progress = FALSE, trigger = FALSE))

  expect_equal(gh_vars[["FTP_STAGING_DIR"]], "test-wp/v3/")
})
