# pb_registry_request() must accept the "ofce" GitHub organisation
# regardless of the casing used in the remote URL (e.g. "OFCE/repo"),
# and still reject genuinely different owners. It targets the pb/
# subfolder of the shared ofce/wp-registry repo (see R/pb_registry_request.R):
# the series is read from `pb_series` in _quarto.yml (default "ofce"), the
# series list and open/closed status come from pb/index.json, and each series
# is numbered from 1 in its own pb/{series}.json file.

test_index <- function() {
  list(
    ofce = list(open = FALSE, label = "OFCE"),
    ife  = list(open = TRUE,  label = "IFE"),
    cepii = list(open = TRUE, label = "CEPII")
  )
}

test_entries <- function() {
  list(
    list(pb = 156L, pb_series = "ofce", type = "repo", `source-repo` = "ofce/old-a"),
    list(pb = 157L, pb_series = "ofce", type = "repo", `source-repo` = "ofce/old-b"),
    list(pb = 1L,   pb_series = "cepii", type = "repo", `source-repo` = "ofce/cepii-a")
  )
}

# Builds a PB repo with a git remote and mocks the registry/network layer.
# `index`/`entries` are what the mocked fetchers return (NULL = unavailable).
setup_request_repo <- function(dir, pb_series = "ife", remote = "ofce/pb-new",
                               index = test_index(), entries = test_entries(),
                               env = parent.frame()) {
  yml <- list()
  if (!is.null(pb_series)) yml$pb_series <- pb_series
  write_quarto_yml(dir, yml)
  gert::git_init(path = dir)
  gert::git_remote_add(
    url = sprintf("https://github.com/%s.git", remote), name = "origin", repo = dir)

  testthat::local_mocked_bindings(
    fetch_pb_series_index = function(...) index,
    fetch_pb_registry     = function(...) entries,
    .env = env
  )
  testthat::local_mocked_bindings(
    req_perform = function(...) stop("no network in tests"),
    .package = "httr2",
    .env = env
  )
  invisible(dir)
}

request_dry <- function(dir, ...) {
  suppressMessages(pb_registry_request(
    path = dir, contact = "jane.doe@ofce.sciences-po.fr", dry_run = TRUE, ...))
}

test_that("pb_registry_request() accepts an OFCE-cased (uppercase) remote owner", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, remote = "OFCE/pb2026-1")

  result <- request_dry(dir)

  expect_equal(result$entry$`source-repo`, "OFCE/pb2026-1")
  expect_null(result$pr_url)
})

test_that("pb_registry_request() aborts for a remote owner outside ofce", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, remote = "someone-else/pb2026-1")

  expect_error(request_dry(dir), "someone-else")
})

test_that("pb_registry_request() restarts numbering at 1 in an empty open series", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, pb_series = "ife")  # entries only hold ofce:157 and cepii:1

  result <- request_dry(dir)

  expect_equal(result$entry$pb, 1L)
  expect_equal(result$entry$pb_series, "ife")
})

test_that("pb_registry_request() numbers max+1 within the series only", {
  dir <- withr::local_tempdir()
  entries <- c(test_entries(), list(
    list(pb = 4L, pb_series = "ife", type = "repo", `source-repo` = "ofce/ife-a"),
    list(pb = 2L, pb_series = "ife", type = "pdf-only", `source-repo` = NULL)
  ))
  setup_request_repo(dir, pb_series = "ife", entries = entries)

  result <- request_dry(dir)

  expect_equal(result$entry$pb, 5L)
})

test_that("pb_registry_request() dry_run entry has the documented fields in order", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, pb_series = "cepii")

  result <- request_dry(dir)

  expect_equal(result$entry$pb_series, "cepii")
  expect_equal(result$entry$pb, 2L)
  expect_equal(
    setdiff(names(result$entry), "registered-by"),  # NULL offline, but position is fixed
    c("pb", "pb_series", "type", "source-repo", "contact", "registered-at"))
  expect_equal(names(result$entry)[3:5], c("type", "source-repo", "contact"))
})

test_that("pb_registry_request() aborts when the series is closed", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, pb_series = "ofce")

  expect_error(request_dry(dir), "close")
  expect_error(request_dry(dir), "ife")
})

test_that("pb_registry_request() falls back to the closed 'ofce' series when pb_series is absent", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, pb_series = NULL)

  expect_error(request_dry(dir), "ofce.*close")
})

test_that("pb_registry_request() aborts on an unknown series", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, pb_series = "nope")

  expect_error(request_dry(dir), "inconnue")
})

test_that("pb_registry_request() aborts when the series index is unavailable", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, index = NULL)

  expect_error(request_dry(dir), "inaccessible")
})

test_that("pb_registry_request() aborts when a series file is unavailable", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, entries = NULL)

  expect_error(request_dry(dir), "inaccessible")
})

test_that("pb_registry_request() aborts when the repo is already registered (any series)", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, pb_series = "ife", remote = "ofce/cepii-a")

  expect_error(request_dry(dir), "d.j. enregistr")
  expect_error(request_dry(dir), "setup_pb")
})

test_that("pb_registry_request() checks explicit-number collisions within the series only", {
  dir <- withr::local_tempdir()
  entries <- c(test_entries(), list(
    list(pb = 3L, pb_series = "ife", type = "repo", `source-repo` = "ofce/ife-a")
  ))
  setup_request_repo(dir, pb_series = "ife", entries = entries)

  # 3 is taken in ife
  expect_error(request_dry(dir, pb = 3L), "d.j. enregistr")
  # 157 exists in ofce but is free in ife
  expect_equal(request_dry(dir, pb = 157L)$entry$pb, 157L)
})

test_that("pb_registry_request() fetches entries using the index it already downloaded", {
  dir <- withr::local_tempdir()
  setup_request_repo(dir, pb_series = "ife")
  received <- NULL
  testthat::local_mocked_bindings(
    fetch_pb_registry = function(registry_repo, index = NULL) {
      received <<- index
      list()
    }
  )

  request_dry(dir)

  expect_equal(names(received), names(test_index()))
})
