# Equivalent of test-deploy_wp.R for deploy_pb() -- see there for the
# rationale (resyncing FTP_SERVER_DIR/FTP_STAGING_DIR from the current
# _quarto.yml right before triggering the relevant FTP workflow).

test_that("deploy_pb() resyncs FTP_SERVER_DIR from the current site-path before a production deploy", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = 5L,
    version = "v2",
    website = list(`site-path` = "5/v2")
  ))
  jsonlite::write_json(
    list(stage = FALSE, pb = 5L),
    fs::path(dir, "manifest.json"),
    auto_unbox = TRUE
  )
  fs::dir_create(fs::path(dir, "_site"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) { gh_vars[[name]] <<- value; invisible(NULL) },
    site2branch = function(...) invisible(NULL),
    push_pb_redirect = function(...) invisible(NULL)
  )

  suppressMessages(deploy_pb(dir, progress = FALSE, trigger = FALSE))

  expect_equal(gh_vars[["FTP_SERVER_DIR"]], "5/v2/")
})

test_that("deploy_pb() resyncs FTP_STAGING_DIR from the current repo/version before an FTP-staging deploy", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_pb        = TRUE,
    draft          = TRUE,
    version        = "v3",
    `stage-target` = "ftp",
    website        = list(`site-url` = "https://staging.ofce.fr/test-pb/v3/")
  ))
  jsonlite::write_json(
    list(stage = TRUE, `source-repo` = "ofce/test-pb"),
    fs::path(dir, "manifest.json"),
    auto_unbox = TRUE
  )
  fs::dir_create(fs::path(dir, "_site"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) { gh_vars[[name]] <<- value; invisible(NULL) },
    site2branch = function(...) invisible(NULL),
    push_pb_staging_redirect = function(...) invisible(NULL),
    detect_gh_owner = function(root) list(owner = "ofce", repo = "test-pb", org = "ofce")
  )

  suppressMessages(deploy_pb(dir, progress = FALSE, trigger = FALSE))

  expect_equal(gh_vars[["FTP_STAGING_DIR"]], "test-pb/v3/")
})
