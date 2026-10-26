# sync_pb_registry_state() is the shared helper behind setup_pb() and
# publish_pb() that consults the pb/ subfolder of ofce/wp-registry (series
# index pb/index.json + one pb/{series}.json file per series) and persists
# draft/pb/pb_series into _quarto.yml. See R/pb_registry_sync.R. `annee` is
# never read or written here.

build_sync_repo_pb <- function(dir, pb = NULL) {
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = pb,
    lang    = "fr"
  ))
  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/ofce/pb2026-1.git", name = "origin", repo = dir)
  invisible(dir)
}

test_that("sync_pb_registry_state() syncs draft/pb from a matched registry entry", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = NULL)

  local_mocked_bindings(
    fetch_pb_entries = function(...) list(
      list(pb = 9L, type = "repo", `source-repo` = "ofce/pb2026-1")
    )
  )

  result <- sync_pb_registry_state(dir, quiet = TRUE)

  expect_false(result$network_error)
  expect_false(result$stage)
  expect_equal(result$registry_entry$pb, 9L)

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$pb, 9L)
  expect_false(yml$draft)
})

test_that("sync_pb_registry_state() clears pb and sets draft when unmatched", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = 9L)

  local_mocked_bindings(
    fetch_pb_entries = function(...) list()
  )

  result <- sync_pb_registry_state(dir, quiet = TRUE)

  expect_false(result$network_error)
  expect_true(result$stage)
  expect_null(result$registry_entry)

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_null(yml$pb)
  expect_true(yml$draft)
})

test_that("sync_pb_registry_state() clears pb and forces draft on a registry fetch error", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = 9L)

  local_mocked_bindings(
    fetch_pb_entries = function(...) NULL
  )

  result <- sync_pb_registry_state(dir, quiet = TRUE)

  expect_true(result$network_error)
  expect_true(result$stage)
  expect_null(result$registry_entry)

  # Verification is impossible on a registry fetch failure, so pb is
  # cleared and draft is forced to TRUE — an unverified PB must never be
  # treated as confirmed for production, even if it was previously published.
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_null(yml$pb)
  expect_true(yml$draft)
})

# ---- multi-series registry (pb/index.json + pb/{series}.json) ----------------

test_that("pb_series() reads pb_series, lowercases it and defaults to 'ofce'", {
  expect_equal(pb_series(list()), "ofce")
  expect_equal(pb_series(list(pb_series = "")), "ofce")
  expect_equal(pb_series(list(pb_series = NULL)), "ofce")
  expect_equal(pb_series(list(pb_series = " IFE ")), "ife")
  # `institut` only picks the logo: never used to derive the series
  expect_equal(pb_series(list(institut = "ife")), "ofce")
  # exact `[[` matching: a partial key must not match
  expect_equal(pb_series(list(pb_series_extra = "ife")), "ofce")
})

test_that("fetch_pb_registry() returns NULL when the index is unavailable", {
  local_mocked_bindings(fetch_pb_series_index = function(...) NULL)
  expect_null(fetch_pb_registry())
})

test_that("fetch_pb_registry() flattens series files and sets pb_series from the file name", {
  idx <- list(ofce = list(open = FALSE), ife = list(open = TRUE))
  local_mocked_bindings(
    fetch_pb_series_index = function(...) stop("index must not be refetched"),
  )
  local_mocked_bindings(
    fromJSON = function(txt, ...) {
      if (grepl("/ofce[.]json$", txt))
        list(pb = list(list(pb = 1L, pb_series = "wrong", type = "repo")))
      else if (grepl("/ife[.]json$", txt))
        list(pb = list(list(pb = 1L, type = "repo"), list(pb = 2L, type = "repo")))
      else stop("unexpected url: ", txt)
    },
    .package = "jsonlite"
  )

  res <- fetch_pb_registry(index = idx)

  expect_length(res, 3L)
  expect_equal(vapply(res, `[[`, "", "pb_series"), c("ofce", "ife", "ife"))
})

test_that("fetch_pb_registry() returns NULL if any series file fails to download", {
  idx <- list(ofce = list(open = FALSE), ife = list(open = TRUE))
  local_mocked_bindings(
    fromJSON = function(txt, ...) {
      if (grepl("/ife[.]json$", txt)) stop("HTTP 404")
      list(pb = list(list(pb = 1L, type = "repo")))
    },
    .package = "jsonlite"
  )

  expect_null(fetch_pb_registry(index = idx))
})

test_that("fetch_pb_entries() is an alias of fetch_pb_registry()", {
  local_mocked_bindings(fetch_pb_registry = function(registry_repo, ...) list(registry_repo))
  expect_equal(fetch_pb_entries("x/y"), list("x/y"))
})

test_that("sync_pb_registry_state() writes pb and pb_series from the matched entry", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = NULL)

  local_mocked_bindings(
    fetch_pb_entries = function(...) list(
      list(pb = 3L, pb_series = "ife", type = "repo", `source-repo` = "ofce/pb2026-1"),
      list(pb = 3L, pb_series = "ofce", type = "repo", `source-repo` = "ofce/other")
    )
  )

  result <- sync_pb_registry_state(dir, quiet = TRUE)

  expect_equal(result$pb_series, "ife")
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$pb, 3L)
  expect_equal(yml$pb_series, "ife")
})

test_that("sync_pb_registry_state() warns when the local pb_series differs from the registry", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = NULL)
  write_quarto_yml(dir, list(ofce_pb = TRUE, pb_series = "ofce", lang = "fr"))

  local_mocked_bindings(
    fetch_pb_entries = function(...) list(
      list(pb = 3L, pb_series = "ife", type = "repo", `source-repo` = "ofce/pb2026-1")
    )
  )

  expect_message(sync_pb_registry_state(dir), "pb_series")
  expect_equal(yaml::read_yaml(fs::path(dir, "_quarto.yml"))$pb_series, "ife")
})

test_that("sync_pb_registry_state() does not warn when pb_series is absent locally and registry says ofce", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = NULL)

  local_mocked_bindings(
    fetch_pb_entries = function(...) list(
      list(pb = 140L, pb_series = "ofce", type = "repo", `source-repo` = "ofce/pb2026-1")
    )
  )

  msgs <- testthat::capture_messages(sync_pb_registry_state(dir))
  expect_false(any(grepl("corrigé", msgs)))
  expect_equal(yaml::read_yaml(fs::path(dir, "_quarto.yml"))$pb_series, "ofce")
})

test_that("sync_pb_registry_state() leaves pb_series untouched on a network error and when unregistered", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = 9L)
  write_quarto_yml(dir, list(ofce_pb = TRUE, pb = 9L, pb_series = "ife", lang = "fr"))

  local_mocked_bindings(fetch_pb_entries = function(...) NULL)
  result <- sync_pb_registry_state(dir, quiet = TRUE)
  expect_true(result$network_error)
  expect_null(result$pb_series)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_null(yml[["pb"]])
  expect_equal(yml$pb_series, "ife")

  local_mocked_bindings(fetch_pb_entries = function(...) list(
    list(pb = 1L, pb_series = "ofce", type = "repo", `source-repo` = "ofce/other")
  ))
  result <- sync_pb_registry_state(dir, quiet = TRUE)
  expect_true(result$stage)
  expect_null(result$pb_series)
  expect_equal(yaml::read_yaml(fs::path(dir, "_quarto.yml"))$pb_series, "ife")
})
