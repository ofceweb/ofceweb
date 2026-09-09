test_that("adhoc_slug: deterministic slug generation", {
  # Same path should always produce the same slug
  slug1 <- adhoc_slug("notes/draft")
  slug2 <- adhoc_slug("notes/draft")
  expect_equal(slug1, slug2)
})

test_that("adhoc_slug: sanitization (lowercase, dashes for non-alphanumeric)", {
  slug <- adhoc_slug("My-Folder/Sub_Folder")
  # Should be lowercase and use dashes
  expect_match(slug, "^[a-z0-9-]+$")
  expect_true(grepl("my", slug))
  expect_true(grepl("folder", slug))
})

test_that("adhoc_slug: truncation and hash suffix", {
  # Path longer than 40 chars should be truncated, then hash appended
  long_path <- "very/long/path/with/many/segments/that/exceeds/forty/characters"
  slug <- adhoc_slug(long_path)
  # Should have format: truncated-hash (40 chars + 1 dash + 6 hash chars = 47 max)
  expect_match(slug, "^.+-[a-z0-9]{6}$")
  expect_true(nchar(slug) <= 50)
})

test_that("adhoc_slug: hash changes with path", {
  slug1 <- adhoc_slug("path1")
  slug2 <- adhoc_slug("path2")
  expect_false(slug1 == slug2)
})

test_that("inject_quick_publish_banner: injects banner after <body>", {
  # Create a temp HTML file with a body tag
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "test_banner.html")

  original <- "<html>\n<head><title>Test</title></head>\n<body>\n<p>Content</p>\n</body>\n</html>"
  writeLines(original, test_file)

  # Inject banner
  inject_quick_publish_banner(temp_dir)

  # Read back
  result <- readLines(test_file, warn = FALSE) |> paste(collapse = "\n")

  # Should contain the banner
  expect_true(grepl("OFCE", result))
  expect_true(grepl("publication rapide", result))
  # Banner should be after body tag
  expect_true(grepl("<body[^>]*>.*OFCE", result, ignore.case = TRUE))

  # Clean up
  file.remove(test_file)
})

test_that("inject_quick_publish_banner: handles missing <body> tag gracefully", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "test_no_body.html")

  original <- "<html><head></head></html>"
  writeLines(original, test_file)

  inject_quick_publish_banner(temp_dir)

  result <- readLines(test_file, warn = FALSE) |> paste(collapse = "\n")
  expect_true(grepl("OFCE", result))

  file.remove(test_file)
})

test_that("inject_quick_publish_banner: processes all *.html files recursively", {
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  subdir <- file.path(temp_dir, "subdir")
  dir.create(subdir)

  # Create multiple HTML files
  file1 <- file.path(temp_dir, "page1.html")
  file2 <- file.path(subdir, "page2.html")
  writeLines("<body>\n<p>Test 1</p>\n</body>", file1)
  writeLines("<body>\n<p>Test 2</p>\n</body>", file2)

  inject_quick_publish_banner(temp_dir)

  result1 <- readLines(file1, warn = FALSE) |> paste(collapse = "\n")
  result2 <- readLines(file2, warn = FALSE) |> paste(collapse = "\n")

  expect_true(grepl("OFCE", result1))
  expect_true(grepl("OFCE", result2))

  unlink(temp_dir, recursive = TRUE)
})

test_that("find_git_root: finds git repository root", {
  skip_if_not_installed("gert")

  # This test is run from within a git repo (ofceweb itself)
  # So we can test finding its root
  root <- find_git_root(".")
  expect_true(dir.exists(file.path(root, ".git")))
})

test_that("find_git_root: errors when no .git found", {
  # Create a temp directory with no .git
  temp_dir <- tempfile()
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE))

  expect_error(find_git_root(temp_dir), "Pas de dépôt Git")
})
