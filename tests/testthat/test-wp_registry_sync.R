# sync_wp_registry_state() is the shared helper behind setup_wp() and
# publish_wp() that consults ofceweb/wp-registry and persists
# draft/wp/annee into _quarto.yml. See R/wp_registry_sync.R.

build_sync_repo <- function(dir, wp = NULL, annee = 2026L) {
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = wp,
    annee   = annee,
    lang    = "fr"
  ))
  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/ofce/wp2026-1.git", name = "origin", repo = dir)
  invisible(dir)
}

test_that("sync_wp_registry_state() syncs draft/wp/annee from a matched registry entry", {
  dir <- withr::local_tempdir()
  build_sync_repo(dir, wp = NULL, annee = 2026L)

  local_mocked_bindings(
    fetch_wp_entries = function(...) list(
      list(annee = 2026L, wp = 9L, type = "repo", `source-repo` = "ofce/wp2026-1")
    )
  )

  result <- sync_wp_registry_state(dir, quiet = TRUE)

  expect_false(result$network_error)
  expect_false(result$stage)
  expect_equal(result$registry_entry$wp, 9L)

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_equal(yml$wp, 9L)
  expect_equal(yml$annee, 2026L)
  expect_false(yml$draft)
})

test_that("sync_wp_registry_state() clears wp/annee and sets draft when unmatched", {
  dir <- withr::local_tempdir()
  build_sync_repo(dir, wp = 9L, annee = 2026L)

  local_mocked_bindings(
    fetch_wp_entries = function(...) list()
  )

  result <- sync_wp_registry_state(dir, quiet = TRUE)

  expect_false(result$network_error)
  expect_true(result$stage)
  expect_null(result$registry_entry)

  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_null(yml$wp)
  expect_null(yml$annee)
  expect_true(yml$draft)
})

test_that("sync_wp_registry_state() clears wp/annee and forces draft on a registry fetch error", {
  dir <- withr::local_tempdir()
  build_sync_repo(dir, wp = 9L, annee = 2026L)

  local_mocked_bindings(
    fetch_wp_entries = function(...) NULL
  )

  result <- sync_wp_registry_state(dir, quiet = TRUE)

  expect_true(result$network_error)
  expect_true(result$stage)
  expect_null(result$registry_entry)

  # Verification is impossible on a registry fetch failure, so wp/annee are
  # cleared and draft is forced to TRUE — an unverified WP must never be
  # treated as confirmed for production, even if it was previously published.
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  expect_null(yml$wp)
  expect_null(yml$annee)
  expect_true(yml$draft)
})
