# pb_registry_request() must accept the "ofce" GitHub organisation
# regardless of the casing used in the remote URL (e.g. "OFCE/repo"),
# and still reject genuinely different owners. It targets the pb/
# subfolder of the shared ofce/wp-registry repo (see R/pb_registry_request.R).
# PB numbering is sequential from the origin, independent of `annee` — the
# registry itself is a flat `pb/pb.json` file, so `_quarto.yml` doesn't need
# an `annee` field for this flow.

build_registry_repo_pb <- function(dir) {
  write_quarto_yml(dir, list())
  invisible(dir)
}

test_that("pb_registry_request() accepts an OFCE-cased (uppercase) remote owner", {
  dir <- withr::local_tempdir()
  build_registry_repo_pb(dir)

  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/OFCE/pb2026-1.git", name = "origin", repo = dir)

  local_mocked_bindings(
    fetch_pb_registry = function(...) NULL,
    .env = environment()
  )
  local_mocked_bindings(
    req_perform = function(...) stop("no network in tests"),
    .package = "httr2"
  )

  result <- pb_registry_request(
    path    = dir,
    contact = "jane.doe@ofce.sciences-po.fr",
    dry_run = TRUE
  )

  expect_equal(result$entry$`source-repo`, "OFCE/pb2026-1")
  expect_null(result$pr_url)
})

test_that("pb_registry_request() aborts for a remote owner outside ofce", {
  dir <- withr::local_tempdir()
  build_registry_repo_pb(dir)

  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/someone-else/pb2026-1.git", name = "origin", repo = dir)

  expect_error(
    pb_registry_request(
      path    = dir,
      contact = "jane.doe@ofce.sciences-po.fr",
      dry_run = TRUE
    ),
    "someone-else"
  )
})
