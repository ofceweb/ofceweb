test_that(".find_quarto_root() finds an ancestor _quarto.yml", {
  dir <- withr::local_tempdir()
  sub <- fs::path(dir, "a", "b")
  fs::dir_create(sub)
  fs::file_create(fs::path(dir, "_quarto.yml"))

  qmd <- fs::path(sub, "doc.qmd")
  fs::file_create(qmd)

  expect_equal(fs::path_norm(.find_quarto_root(qmd)), fs::path_norm(dir))
})

test_that(".find_quarto_root() returns NULL when no ancestor has _quarto.yml", {
  dir <- withr::local_tempdir()
  qmd <- fs::path(dir, "doc.qmd")
  fs::file_create(qmd)

  expect_null(.find_quarto_root(qmd))
})

test_that(".inject_temp_quarto_yml() writes a minimal, valid project YAML", {
  dir <- withr::local_tempdir()

  written <- .inject_temp_quarto_yml(dir)

  expect_equal(fs::path_norm(written), fs::path_norm(fs::path(dir, "_quarto.yml")))
  expect_true(fs::file_exists(written))

  yml <- yaml::read_yaml(written)
  expect_equal(yml$project$type, "default")
})

test_that(".inject_temp_quarto_yml() never overwrites an existing _quarto.yml", {
  dir <- withr::local_tempdir()
  existing <- fs::path(dir, "_quarto.yml")
  writeLines("project:\n  type: website", existing)

  result <- .inject_temp_quarto_yml(dir)

  expect_null(result)
  expect_equal(yaml::read_yaml(existing)$project$type, "website")
})

test_that(".inject_temp_quarto_yml() warns and returns NULL when writing fails", {
  dir <- withr::local_tempdir()
  # A nonexistent parent directory makes writeLines() fail.
  bad_dir <- fs::path(dir, "does", "not", "exist")

  expect_message(
    result <- .inject_temp_quarto_yml(bad_dir),
    "Impossible de cr"
  )
  expect_null(result)
})
