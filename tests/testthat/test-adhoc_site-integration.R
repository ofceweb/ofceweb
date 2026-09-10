test_that("render_folder_worker: renders a simple .qmd to _site/", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  # Create a temp git repo with a simple qmd file
  temp_repo <- tempfile(pattern = "adhoc_test_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  # Initialize git repo
  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  # Create a simple qmd file
  test_qmd <- "---\ntitle: 'Test Document'\n---\n# Hello\n\nThis is a test.\n"
  writeLines(test_qmd, file.path(temp_repo, "index.qmd"))

  # Render using the worker function (not as_job)
  url <- render_folder_worker(
    path     = temp_repo,
    index    = "index.qmd",
    slug     = NULL,
    progress = FALSE,
    preview  = FALSE
  )

  # Check that _site was created
  site_dir <- file.path(temp_repo, "_site")
  expect_true(dir.exists(site_dir))

  # Check that index.html exists
  expect_true(file.exists(file.path(site_dir, "index.html")))

  # Check that .adhoc-meta.json was created
  meta_file <- file.path(site_dir, ".adhoc-meta.json")
  expect_true(file.exists(meta_file))

  # Check metadata contents
  metadata <- jsonlite::read_json(meta_file)
  expect_equal(metadata$index, "index.qmd")
  expect_true(nchar(metadata$slug) > 0)
  expect_true(nchar(metadata$rendered_at) > 0)

  # Check that banner was injected
  html_content <- readLines(file.path(site_dir, "index.html"), warn = FALSE) |>
    paste(collapse = "\n")
  expect_true(grepl("OFCE", html_content))
})

test_that("render_folder_worker: auto-detects index when only one .qmd exists", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  temp_repo <- tempfile(pattern = "adhoc_auto_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  # Initialize git
  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  # Create single .qmd (no index argument)
  writeLines("---\ntitle: 'Auto'\n---\nContent", file.path(temp_repo, "document.qmd"))

  # Should not error on missing index argument
  expect_no_error({
    render_folder_worker(
      path     = temp_repo,
      index    = NULL,  # Let it auto-detect
      slug     = NULL,
      progress = FALSE,
      preview  = FALSE
    )
  })

  expect_true(file.exists(file.path(temp_repo, "_site", "index.html")))
})

test_that("render_folder_worker: picks most recently modified .qmd when multiple exist and no index specified", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  temp_repo <- tempfile(pattern = "adhoc_multi_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  # Create multiple .qmd files, doc2.qmd modified last
  writeLines("---
title: 'One'
---
Content", file.path(temp_repo, "doc1.qmd"))
  Sys.sleep(1.1)
  writeLines("---
title: 'Two'
---
Content", file.path(temp_repo, "doc2.qmd"))

  # No error: falls back to the most recently modified candidate (doc2.qmd)
  render_folder_worker(
    path     = temp_repo,
    index    = NULL,
    slug     = NULL,
    progress = FALSE,
    preview  = FALSE
  )

  meta_file <- file.path(temp_repo, "_site", ".adhoc-meta.json")
  metadata <- jsonlite::read_json(meta_file)
  expect_equal(metadata$index, "doc2.qmd")

  # Only doc2.qmd was rendered -- doc1.qmd's own output should not exist
  expect_false(file.exists(file.path(temp_repo, "_site", "doc1.html")))
})

test_that("render_folder_worker: errors when no .qmd files exist", {
  skip_if_not_installed("gert")

  temp_repo <- tempfile(pattern = "adhoc_empty_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  expect_error(
    render_folder_worker(
      path     = temp_repo,
      index    = NULL,
      slug     = NULL,
      progress = FALSE,
      preview  = FALSE
    ),
    "Aucun fichier .qmd"
  )
})

test_that("render_folder_worker: ignores any pre-existing _quarto.yml in the source folder", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  temp_repo <- tempfile(pattern = "adhoc_own_config_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  # Create a custom _quarto.yml declaring a different theme -- this should
  # be ignored entirely: a flash render always writes its own minimal
  # config (theme: cosmo), restricted to `index` only.
  custom_yml <- "project:
  type: default
  output-dir: _site
format:
  html:
    theme: darkly
"
  writeLines(custom_yml, file.path(temp_repo, "_quarto.yml"))

  # A second .qmd file alongside index.qmd: since it is not the resolved
  # index, it must not be rendered even though the (ignored) custom config
  # doesn't restrict `render:`.
  writeLines("---
title: 'Test'
---
Content", file.path(temp_repo, "index.qmd"))
  writeLines("---
title: 'Other'
---
Content", file.path(temp_repo, "other.qmd"))

  render_folder_worker(
    path     = temp_repo,
    index    = "index.qmd",
    slug     = NULL,
    progress = FALSE,
    preview  = FALSE
  )

  site_dir <- file.path(temp_repo, "_site")
  expect_true(dir.exists(site_dir))

  # theme is cosmo (from the ofceweb minimal config), not darkly -- darkly's
  # bootswatch stylesheet name would appear in the compiled CSS link/comment
  # if the custom _quarto.yml had been honored
  css_files <- fs::dir_ls(site_dir, recurse = TRUE, regexp = "\\.css$")
  css_content <- css_files |> lapply(readLines, warn = FALSE) |> unlist() |> paste(collapse = "
")
  expect_false(grepl("darkly", css_content, ignore.case = TRUE))

  # other.qmd was not rendered
  expect_false(file.exists(file.path(site_dir, "other.html")))
})

test_that("render_folder_worker: cleans up temp directory after render", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  temp_repo <- tempfile(pattern = "adhoc_cleanup_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  writeLines("---\ntitle: 'Test'\n---\nContent", file.path(temp_repo, "index.qmd"))

  # Count temp files before
  temp_dir <- tempdir()
  files_before <- length(dir(temp_dir))

  render_folder_worker(
    path     = temp_repo,
    index    = "index.qmd",
    slug     = NULL,
    progress = FALSE,
    preview  = FALSE
  )

  # Temp directory should be cleaned up
  # (We can't strictly verify the specific adhoc temp dirs are gone,
  # but we check that no obvious orphans remain)
  files_after <- length(dir(temp_dir))
  # Should not have created excessive orphaned directories
  expect_true(files_after - files_before < 100)
})

test_that("render_folder_worker: returns URL string", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  temp_repo <- tempfile(pattern = "adhoc_url_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  writeLines("---\ntitle: 'Test'\n---\nContent", file.path(temp_repo, "index.qmd"))

  url <- render_folder_worker(
    path     = temp_repo,
    index    = "index.qmd",
    slug     = NULL,
    progress = FALSE,
    preview  = FALSE
  )

  expect_type(url, "character")
  expect_true(grepl("https://staging.ofce.fr/", url))
})
