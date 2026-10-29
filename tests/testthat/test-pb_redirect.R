# push_pb_staging_redirect() --------------------------------------------------

test_that("push_pb_staging_redirect() errors without _quarto.yml", {
  root <- withr::local_tempdir()
  expect_error(push_pb_staging_redirect(path = root), "Pas de.*_quarto.yml")
})

test_that("push_pb_staging_redirect() errors without ofce_pb: true", {
  root <- withr::local_tempdir()
  writeLines("project:\n  type: website", fs::path(root, "_quarto.yml"))

  expect_error(
    push_pb_staging_redirect(path = root),
    "ne fonctionne que sur un d\u00e9p\u00f4t PB"
  )
})

test_that("push_pb_staging_redirect() alerts when site-url is missing", {
  root <- withr::local_tempdir()
  writeLines("ofce_pb: true", fs::path(root, "_quarto.yml"))

  expect_message(push_pb_staging_redirect(path = root), "site-url.*absent")
})

test_that("push_pb_staging_redirect() is a no-op for a published PB (site-url without repo/version)", {
  root <- withr::local_tempdir()
  writeLines(c(
    "ofce_pb: true",
    "pb: 12",
    "website:",
    "  site-url: https://www.ofce.fr/"
  ), fs::path(root, "_quarto.yml"))

  expect_message(push_pb_staging_redirect(path = root), "non n\u00e9cessaire")
})

test_that("push_pb_staging_redirect() is a no-op for a gh-pages draft", {
  root <- withr::local_tempdir()
  writeLines(c(
    "ofce_pb: true",
    "draft: true",
    "website:",
    "  site-url: https://ofce.github.io/pb-example/"
  ), fs::path(root, "_quarto.yml"))

  expect_message(push_pb_staging_redirect(path = root), "non n\u00e9cessaire")
})

test_that("push_pb_staging_redirect() computes FTP_STAGING_REDIRECT_DIR for a numeric version", {
  root <- withr::local_tempdir()
  gert::git_init(path = root)
  writeLines(c(
    "ofce_pb: true",
    "draft: true",
    "version: v1",
    "website:",
    "  site-url: https://staging.ofce.fr/pb-example/v1/"
  ), fs::path(root, "_quarto.yml"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) {
      gh_vars[[name]] <<- value
      invisible(NULL)
    }
  )

  expect_message(push_pb_staging_redirect(path = root), "Pas de remote 'origin'")
  expect_equal(gh_vars[["FTP_STAGING_REDIRECT_DIR"]], "pb-example/")
})

test_that("push_pb_staging_redirect() computes FTP_STAGING_REDIRECT_DIR for a custom version suffix", {
  root <- withr::local_tempdir()
  gert::git_init(path = root)
  writeLines(c(
    "ofce_pb: true",
    "draft: true",
    "version: v2_corr",
    "website:",
    "  site-url: https://staging.ofce.fr/pb-example/v2_corr/"
  ), fs::path(root, "_quarto.yml"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) {
      gh_vars[[name]] <<- value
      invisible(NULL)
    }
  )

  expect_message(push_pb_staging_redirect(path = root), "Pas de remote 'origin'")
  expect_equal(gh_vars[["FTP_STAGING_REDIRECT_DIR"]], "pb-example/")
})
