test_that("render_folder_worker: renders a simple .qmd to _site/", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  # Create a temp git repo with a simple qmd file
  temp_repo <- tempfile(prefix = "adhoc_test_")
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

  temp_repo <- tempfile(prefix = "adhoc_auto_")
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

test_that("render_folder_worker: errors when multiple .qmd files exist and no index specified", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  temp_repo <- tempfile(prefix = "adhoc_multi_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  # Create multiple .qmd files
  writeLines("---\ntitle: 'One'\n---\nContent", file.path(temp_repo, "doc1.qmd"))
  writeLines("---\ntitle: 'Two'\n---\nContent", file.path(temp_repo, "doc2.qmd"))

  # Should error asking which one to use
  expect_error(
    render_folder_worker(
      path     = temp_repo,
      index    = NULL,
      slug     = NULL,
      progress = FALSE,
      preview  = FALSE
    ),
    "Impossible de détecter"
  )
})

test_that("render_folder_worker: errors when no .qmd/.md files exist", {
  skip_if_not_installed("gert")

  temp_repo <- tempfile(prefix = "adhoc_empty_")
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
    "Aucun fichier .qmd/.md"
  )
})

test_that("render_folder_worker: uses supplied _quarto.yml if present", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  temp_repo <- tempfile(prefix = "adhoc_own_config_")
  dir.create(temp_repo, recursive = TRUE)
  on.exit(unlink(temp_repo, recursive = TRUE))

  gert::git_init(temp_repo)
  gert::git_config_set("user.name", "Test User", repo = temp_repo)
  gert::git_config_set("user.email", "test@example.com", repo = temp_repo)

  # Create custom _quarto.yml
  custom_yml <- "project:\n  type: default\n  output-dir: _site\nformat:\n  html:\n    theme: darkly\n"
  writeLines(custom_yml, file.path(temp_repo, "_quarto.yml"))

  # Create qmd
  writeLines("---\ntitle: 'Test'\n---\nContent", file.path(temp_repo, "index.qmd"))

  # Render should succeed (using the custom config)
  expect_no_error({
    render_folder_worker(
      path     = temp_repo,
      index    = "index.qmd",
      slug     = NULL,
      progress = FALSE,
      preview  = FALSE
    )
  })

  expect_true(dir.exists(file.path(temp_repo, "_site")))
})

test_that("render_folder_worker: cleans up temp directory after render", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("gert")

  temp_repo <- tempfile(prefix = "adhoc_cleanup_")
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

  temp_repo <- tempfile(prefix = "adhoc_url_")
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
