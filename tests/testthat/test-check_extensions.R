# Unit tests for check_stray_ofce_extensions() — the warn-only detector for
# OFCE Quarto extensions left over from before the migration to
# ofce::setup_quarto().

test_that("check_stray_ofce_extensions() returns character(0) when _extensions/ is absent", {
  dir <- withr::local_tempdir()
  expect_identical(check_stray_ofce_extensions(dir), character())
})

test_that("check_stray_ofce_extensions() ignores a clean, canonical install", {
  dir <- withr::local_tempdir()
  # Mimic what ofce::setup_quarto() actually installs.
  for (ext in c("ofce", "wp", "note", "ofce-website")) {
    p <- fs::path(dir, "_extensions", "ofce", ext)
    fs::dir_create(p, recurse = TRUE)
    writeLines("title: x", fs::path(p, "_extension.yml"))
  }

  expect_identical(check_stray_ofce_extensions(dir), character())
  expect_no_message(check_stray_ofce_extensions(dir))
})

test_that("check_stray_ofce_extensions() flags legacy flat OFCE extension folders", {
  dir <- withr::local_tempdir()
  legacy <- fs::path(dir, "_extensions", "wp")
  fs::dir_create(legacy, recurse = TRUE)
  writeLines("title: old wp", fs::path(legacy, "_extension.yml"))

  stray <- check_stray_ofce_extensions(dir)

  expect_length(stray, 1L)
  expect_equal(fs::path_norm(stray), fs::path_norm(legacy))
  expect_message(check_stray_ofce_extensions(dir), "p\u00e9rim\u00e9e")
})

test_that("check_stray_ofce_extensions() flags ofce/pb but not other ofce/* extensions", {
  dir <- withr::local_tempdir()
  for (ext in c("pb", "ofce")) {
    p <- fs::path(dir, "_extensions", "ofce", ext)
    fs::dir_create(p, recurse = TRUE)
    writeLines("title: x", fs::path(p, "_extension.yml"))
  }

  stray <- check_stray_ofce_extensions(dir)

  expect_length(stray, 1L)
  expect_true(grepl("ofce/pb$", as.character(stray)))
})

test_that("check_stray_ofce_extensions() ignores non-extension dirs and third-party nested extensions", {
  dir <- withr::local_tempdir()
  # A directory that merely happens to be named like a legacy extension but
  # has no _extension.yml should not be flagged.
  fs::dir_create(fs::path(dir, "_extensions", "wp"), recurse = TRUE)
  # A third-party dependency nested inside a canonical OFCE extension.
  nested <- fs::path(dir, "_extensions", "ofce", "wp", "_extensions", "fontawesome")
  fs::dir_create(nested, recurse = TRUE)
  writeLines("title: fontawesome", fs::path(nested, "_extension.yml"))

  expect_identical(check_stray_ofce_extensions(dir), character())
})

test_that("check_stray_ofce_extensions() never deletes anything", {
  dir <- withr::local_tempdir()
  legacy <- fs::path(dir, "_extensions", "social-share")
  fs::dir_create(legacy, recurse = TRUE)
  ext_file <- fs::path(legacy, "_extension.yml")
  writeLines("title: old", ext_file)

  suppressMessages(check_stray_ofce_extensions(dir))

  expect_true(fs::file_exists(ext_file))
})
