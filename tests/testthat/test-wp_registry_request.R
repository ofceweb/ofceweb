# wp_registry_request() must accept the "ofce" GitHub organisation
# regardless of the casing used in the remote URL (e.g. "OFCE/repo"),
# and still reject genuinely different owners.

build_registry_repo <- function(dir, annee = 2026L) {
  write_quarto_yml(dir, list(annee = annee))
  invisible(dir)
}

test_that("wp_registry_request() accepts an OFCE-cased (uppercase) remote owner", {
  dir <- withr::local_tempdir()
  build_registry_repo(dir)

  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/OFCE/wp2026-1.git", name = "origin", repo = dir)

  local_mocked_bindings(
    fetch_wp_year = function(...) NULL,
    .env = environment()
  )
  local_mocked_bindings(
    req_perform = function(...) stop("no network in tests"),
    .package = "httr2"
  )

  result <- wp_registry_request(
    path    = dir,
    contact = "jane.doe@ofce.sciences-po.fr",
    dry_run = TRUE
  )

  expect_equal(result$entry$`source-repo`, "OFCE/wp2026-1")
  expect_null(result$pr_url)
})

test_that("wp_registry_request() aborts for a remote owner outside ofce", {
  dir <- withr::local_tempdir()
  build_registry_repo(dir)

  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/someone-else/wp2026-1.git", name = "origin", repo = dir)

  expect_error(
    wp_registry_request(
      path    = dir,
      contact = "jane.doe@ofce.sciences-po.fr",
      dry_run = TRUE
    ),
    "someone-else"
  )
})
