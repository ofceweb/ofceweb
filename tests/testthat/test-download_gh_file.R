test_that("download_gh_file() queries the {path} placeholder, not a fixed root listing", {
  requested_path <- NULL

  local_mocked_bindings(
    gh = function(endpoint, owner, repo, path, ref) {
      requested_path <<- path
      expect_equal(endpoint, "GET /repos/{owner}/{repo}/contents/{path}")
      list(name = fs::path_file(path), download_url = "https://example.com/raw/file")
    },
    .package = "gh"
  )
  local_mocked_bindings(
    curl_download = function(url, destfile, handle) {
      writeLines("contenu factice", destfile)
      destfile
    },
    .package = "curl"
  )

  dest <- withr::local_tempfile()
  nested_path <- "posts/2024-01-01/index.qmd"

  result <- download_gh_file(nested_path, dest = dest)

  # The full nested path must reach the API call unchanged -- this is the
  # regression: the previous "contents/." template silently ignored `path`
  # and always listed the repository root.
  expect_equal(requested_path, nested_path)
  expect_equal(result, dest)
  expect_true(fs::file_exists(dest))
})

test_that("download_gh_file() returns NULL when the API has no download_url (e.g. a directory or 404)", {
  local_mocked_bindings(
    gh = function(endpoint, owner, repo, path, ref) {
      # Simulate a directory listing (array, no top-level download_url) or a
      # 404 raised as an error -- both should resolve to NULL, not a crash.
      stop("Not Found (HTTP 404)")
    },
    .package = "gh"
  )

  expect_null(download_gh_file("posts/does-not-exist/index.qmd"))
})
