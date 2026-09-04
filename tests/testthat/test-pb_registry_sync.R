# sync_pb_registry_state() is the shared helper behind setup_pb() and
# publish_pb() that consults the pb/ subfolder of ofce/wp-registry and
# persists draft/pb/annee into _quarto.yml. See R/pb_registry_sync.R.

build_sync_repo_pb <- function(dir, pb = NULL, annee = 2026L) {
  write_quarto_yml(dir, list(
    ofce_pb = TRUE,
    pb      = pb,
    annee   = annee,
    lang    = "fr"
  ))
  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/ofce/pb2026-1.git", name = "origin", repo = dir)
  invisible(dir)
}

test_that("sync_pb_registry_state() syncs draft/pb/annee from a matched registry entry", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = NULL, annee = 2026L)

  local_mocked_bindings(
    fetch_pb_entries = function(...) list(
      list(annee = 2026L, pb = 9L, type = "repo", `source-repo` = "ofce/pb2026-1")
    )
  )

  result <- sync_pb_registry_state(dir, quiet = TRUE)

  expect_false(result$network_error)
  expect_false(result$stage)
  expect_equal(result$registry_entry$pb, 9L)

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$pb, 9L)
  expect_equal(yml$annee, 2026L)
  expect_false(yml$draft)
})

test_that("sync_pb_registry_state() clears pb/annee and sets draft when unmatched", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = 9L, annee = 2026L)

  local_mocked_bindings(
    fetch_pb_entries = function(...) list()
  )

  result <- sync_pb_registry_state(dir, quiet = TRUE)

  expect_false(result$network_error)
  expect_true(result$stage)
  expect_null(result$registry_entry)

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_null(yml$pb)
  expect_null(yml$annee)
  expect_true(yml$draft)
})

test_that("sync_pb_registry_state() clears pb/annee and forces draft on a registry fetch error", {
  dir <- withr::local_tempdir()
  build_sync_repo_pb(dir, pb = 9L, annee = 2026L)

  local_mocked_bindings(
    fetch_pb_entries = function(...) NULL
  )

  result <- sync_pb_registry_state(dir, quiet = TRUE)

  expect_true(result$network_error)
  expect_true(result$stage)
  expect_null(result$registry_entry)

  # Verification is impossible on a registry fetch failure, so pb/annee are
  # cleared and draft is forced to TRUE — an unverified PB must never be
  # treated as confirmed for production, even if it was previously published.
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_null(yml$pb)
  expect_null(yml$annee)
  expect_true(yml$draft)
})
