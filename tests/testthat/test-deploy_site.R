# deploy_site() reads `ofce_host` from _quarto.yml to pick a deploy route,
# then prints a success message with the URL where the site actually ended
# up. The two routes must not share a single URL-computation path: the
# `ofce_host` (FTP/site2branch) branch trusts website.site-url/site-path
# (an accurate description of the OFCE hosting target in that case), while
# the gh-pages branch must recompute the URL from the repo's git remote --
# website.site-url can point at an unrelated host (e.g. staging.ofce.fr for
# a PB repo) that has nothing to do with where `quarto publish gh-pages`
# just pushed the site. See R/deploy_site.R.

local_mock_gh_remote <- function(owner = "OFCE", repo = "test_pb", env = parent.frame()) {
  local_mocked_bindings(
    git_remote_list = function(...) {
      data.frame(
        name = "origin",
        url  = sprintf("https://github.com/%s/%s.git", owner, repo),
        stringsAsFactors = FALSE
      )
    },
    .package = "gert",
    .env = env
  )
}

test_that("deploy_site() with ofce_host: true pushes via site2branch and reports the site-url", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(
    ofce_host = TRUE,
    website   = list(`site-url` = "https://staging.ofce.fr/", `site-path` = "test_pb/v0/")
  ))
  fs::dir_create(fs::path(dir, "_site"))

  local_mock_gh_remote(env = environment())

  called <- FALSE
  local_mocked_bindings(
    site2branch = function(path, ...) { called <<- TRUE; invisible(NULL) }
  )

  expect_message(
    deploy_site(dir),
    "https://staging.ofce.fr/test_pb/v0/index.html",
    fixed = TRUE
  )
  expect_true(called)
})

test_that("deploy_site() with ofce_host: false publishes to gh-pages and reports the github.io URL, not site-url", {
  dir <- withr::local_tempdir()
  # website.site-url deliberately points at an unrelated (OFCE) host: this
  # is exactly the PB-repo scenario that produced a misleading "available at
  # staging.ofce.fr" message even though the content was actually pushed to
  # GitHub Pages.
  write_quarto_yml(dir, list(
    ofce_host = FALSE,
    website   = list(`site-url` = "https://staging.ofce.fr/", `site-path` = "test_pb/v0/")
  ))
  fs::dir_create(fs::path(dir, "_site"))

  local_mock_gh_remote(owner = "OFCE", repo = "test_pb", env = environment())

  local_mocked_bindings(
    system2 = function(...) 0L,
    .package = "base"
  )
  local_mocked_bindings(
    site2branch = function(...) stop("should not be called")
  )

  msgs <- capture_messages(deploy_site(dir))

  expect_false(any(grepl("staging.ofce.fr", msgs, fixed = TRUE)))
  expect_true(any(grepl(
    "https://OFCE.github.io/test_pb/index.html", msgs, fixed = TRUE)))
})

test_that("deploy_site() gh-pages branch aborts with no URL message when quarto fails", {
  dir <- withr::local_tempdir()
  write_quarto_yml(dir, list(ofce_host = FALSE))
  fs::dir_create(fs::path(dir, "_site"))

  local_mock_gh_remote(env = environment())

  local_mocked_bindings(
    system2 = function(...) 1L,
    .package = "base"
  )

  expect_error(
    suppressWarnings(deploy_site(dir)),
    "chec"
  )
})
