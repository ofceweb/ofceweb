test_that("safe_here: matches here::here() when no marker is present", {
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE))

  file.create(file.path(temp_dir, ".here"))
  subdir <- file.path(temp_dir, "sub")
  dir.create(subdir)

  oldwd <- getwd()
  on.exit(setwd(oldwd), add = TRUE)
  setwd(subdir)

  expect_equal(safe_here("a", "b.R"), here::here("a", "b.R"))
})

test_that("write_safe_here_marker + safe_here: resolves against the recorded root", {
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE))

  origin_root <- tempfile()
  dir.create(origin_root, recursive = TRUE)
  on.exit(unlink(origin_root, recursive = TRUE), add = TRUE)

  write_safe_here_marker(temp_dir, origin_root)
  expect_true(file.exists(file.path(temp_dir, ".safe_here-root")))

  oldwd <- getwd()
  on.exit(setwd(oldwd), add = TRUE)
  setwd(temp_dir)

  expect_equal(
    as.character(safe_here("sub", "file.R")),
    as.character(fs::path(origin_root, "sub", "file.R"))
  )
})

test_that("write_safe_here_marker: writes nothing when origin_root is NA", {
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE))

  write_safe_here_marker(temp_dir, NA_character_)
  expect_false(file.exists(file.path(temp_dir, ".safe_here-root")))
})

test_that("find_safe_here_marker: found via upward search from a nested directory", {
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE))

  origin_root <- tempfile()
  dir.create(origin_root, recursive = TRUE)
  on.exit(unlink(origin_root, recursive = TRUE), add = TRUE)

  write_safe_here_marker(temp_dir, origin_root)

  nested <- file.path(temp_dir, "presentation", "chunks")
  dir.create(nested, recursive = TRUE)

  marker <- find_safe_here_marker(nested)
  expect_equal(marker, as.character(fs::path(temp_dir, ".safe_here-root")))
})

test_that("find_safe_here_marker: NULL when no marker exists up to filesystem root", {
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE))

  expect_null(find_safe_here_marker(temp_dir))
})

test_that("safe_here: reaches a file outside the marker's own directory tree", {
  # Simulates the render_flash() scenario: the marker (and safe_here() call)
  # live in a temp copy, but the recorded root is a *different*, untouched
  # directory containing a file that was never copied into the temp tree.
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE))

  origin_root <- tempfile()
  dir.create(origin_root, recursive = TRUE)
  on.exit(unlink(origin_root, recursive = TRUE), add = TRUE)
  outside_dir <- file.path(origin_root, "outside")
  dir.create(outside_dir)
  writeLines("ok", file.path(outside_dir, "shared.R"))

  write_safe_here_marker(temp_dir, origin_root)

  oldwd <- getwd()
  on.exit(setwd(oldwd), add = TRUE)
  setwd(temp_dir)

  resolved <- safe_here("outside", "shared.R")
  expect_true(file.exists(resolved))
  expect_false(file.exists(file.path(temp_dir, "outside", "shared.R")))
})
