# push_pb_redirect() ---------------------------------------------------------

test_that("push_pb_redirect() errors without _quarto.yml", {
  root <- withr::local_tempdir()
  expect_error(push_pb_redirect(path = root), "Pas de.*_quarto.yml")
})

test_that("push_pb_redirect() does nothing for a draft (pb: null)", {
  root <- withr::local_tempdir()
  writeLines("ofce_pb: true", fs::path(root, "_quarto.yml"))

  expect_message(push_pb_redirect(path = root), "brouillon")
})

test_that("push_pb_redirect() does nothing without a version field", {
  root <- withr::local_tempdir()
  writeLines(c(
    "ofce_pb: true",
    "pb: 12",
    "website:",
    "  site-path: pb/12/v1"
  ), fs::path(root, "_quarto.yml"))

  expect_message(push_pb_redirect(path = root), "version.*ignor")
})

test_that("push_pb_redirect() alerts when site-path is missing", {
  root <- withr::local_tempdir()
  writeLines(c(
    "ofce_pb: true",
    "pb: 12",
    "version: v1"
  ), fs::path(root, "_quarto.yml"))

  expect_message(push_pb_redirect(path = root), "site-path.*absent")
})

test_that("push_pb_redirect() strips a purely numeric version segment (v1) from FTP_REDIRECT_DIR", {
  root <- withr::local_tempdir()
  gert::git_init(path = root)
  writeLines(c(
    "ofce_pb: true",
    "pb: 12",
    "version: v1",
    "website:",
    "  site-url: https://www.ofce.fr/",
    "  site-path: pb/12/v1"
  ), fs::path(root, "_quarto.yml"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) {
      gh_vars[[name]] <<- value
      invisible(NULL)
    }
  )

  # No git remote configured -> push is skipped, but FTP_REDIRECT_DIR is
  # computed and set before that point is reached.
  expect_message(push_pb_redirect(path = root), "Pas de remote 'origin'")
  expect_equal(gh_vars[["FTP_REDIRECT_DIR"]], "pb/12/")
})

test_that("push_pb_redirect() strips a custom, non-numeric version segment (v2_corr) from FTP_REDIRECT_DIR", {
  # Regression test: the redirect-dir computation used to rely on a
  # purely-numeric regex (`/v\\d+$`), which silently failed to strip custom
  # version suffixes (e.g. "v2_corr", "v5_AS42") supported by
  # pb_version_up(custom_version = ...), leaving FTP_REDIRECT_DIR identical
  # to the full versioned FTP_SERVER_DIR path.
  root <- withr::local_tempdir()
  gert::git_init(path = root)
  writeLines(c(
    "ofce_pb: true",
    "pb: 12",
    "version: v2_corr",
    "website:",
    "  site-url: https://www.ofce.fr/",
    "  site-path: pb/12/v2_corr"
  ), fs::path(root, "_quarto.yml"))

  gh_vars <- list()
  local_mocked_bindings(
    set_gh_var = function(root, name, value) {
      gh_vars[[name]] <<- value
      invisible(NULL)
    }
  )

  expect_message(push_pb_redirect(path = root), "Pas de remote 'origin'")
  expect_equal(gh_vars[["FTP_REDIRECT_DIR"]], "pb/12/")
})

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
