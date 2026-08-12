test_that("check_wp() reports no error/warning on a fully valid published WP repo", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)

  df <- check_wp(dir, verbose = FALSE)

  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df[df$status == "error", ]), 0L)
  expect_equal(nrow(df[df$status == "warning", ]), 0L)
})

test_that("check_wp() errors when _quarto.yml is absent", {
  dir <- withr::local_tempdir()

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(nrow(df), 1L)
  expect_equal(df$field[1], "_quarto.yml")
  expect_equal(df$status[1], "error")
})

test_that("check_wp() errors when _quarto.yml is not valid YAML", {
  dir <- withr::local_tempdir()
  writeLines(c("title: [unclosed", "  - broken"), fs::path(dir, "_quarto.yml"))

  df <- check_wp(dir, verbose = FALSE)

  expect_true("_quarto.yml" %in% df$field)
  expect_equal(diag_status(df, "_quarto.yml"), "error")
})

test_that("check_wp() warns when ofce_wp: true is missing", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$ofce_wp <- NULL
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "ofce_wp"), "warning")
})

test_that("check_wp() errors when date/citation are missing", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$date     <- NULL
  yml$citation <- NULL
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "date"), "error")
  expect_equal(diag_status(df, "citation"), "error")
})

test_that("check_wp() errors when annee is missing", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$annee <- NULL
  yml$wp    <- NULL
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "annee"), "error")
})

test_that("check_wp() errors when annee is present but wp is missing", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$wp        <- NULL
  yml$website$`site-path` <- NULL
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "wp"), "error")
})

test_that("check_wp() errors when author and authors are both missing", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$author <- NULL
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "author"), "error")
})

test_that("check_wp() errors when index.qmd is absent", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  fs::file_delete(fs::path(dir, "index.qmd"))

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "index.qmd"), "error")
})

test_that("check_wp() errors when neither wp-html nor a PDF format is declared", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$format <- NULL
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "format:wp-html"), "error")
  expect_equal(diag_status(df, "format:pdf"), "error")
})

test_that("check_wp() warns when references.bib and news.qmd are absent", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  fs::file_delete(fs::path(dir, "references.bib"))
  fs::file_delete(fs::path(dir, "news.qmd"))

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "references.bib"), "warning")
  expect_equal(diag_status(df, "news.qmd"), "warning")
})

test_that("check_wp() errors when .github/workflows is entirely absent", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  fs::dir_delete(fs::path(dir, ".github"))

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, ".github/workflows"), "error")
})

test_that("check_wp() errors when workflows/ exists but ftp_deploy.yml is missing", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  fs::file_delete(fs::path(dir, ".github", "workflows", "ftp_deploy.yml"))

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, ".github/workflows"), "error")
})

test_that("check_wp() warns when renv.lock is absent", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  fs::file_delete(fs::path(dir, "renv.lock"))

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "renv.lock"), "warning")
})

test_that("check_wp() errors when annee is invalid for a published WP", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$annee <- "abc"
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_true("error" %in% diag_status(df, "annee"))
})

test_that("check_wp() errors when site-path is absent for a published WP", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- NULL
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "site-path"), "error")
})

test_that("check_wp() errors when site-path has the wrong number of segments", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2024"
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "site-path"), "error")
})

test_that("check_wp() errors when the year segment of site-path is inconsistent with annee", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2023/12/v1"
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "site-path/annee"), "error")
})

test_that("check_wp() errors when the WP-number segment of site-path is inconsistent with wp", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2024/99/v1"
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "site-path/wp"), "error")
})

test_that("check_wp() errors when the version segment of site-path is inconsistent with version", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2024/12/v2"
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "site-path/version"), "error")
})

test_that("check_wp() warns when a non-index .qmd is not referenced in other-links", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`other-links` <- NULL
  write_quarto_yml(dir, yml)

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "annexes.qmd"), "warning")
})

test_that("check_wp() errors when two documents declare the same PDF output-file", {
  dir <- withr::local_tempdir()
  build_valid_wp_repo(dir)
  write_qmd(dir, "index.qmd", yaml_lines = c(
    "title: WP",
    "format:",
    "  wp-pdf:",
    "    output-file: rapport.pdf"
  ))
  write_qmd(dir, "annexes.qmd", yaml_lines = c(
    "title: Annexes",
    "format:",
    "  wp-pdf:",
    "    output-file: rapport.pdf"
  ))

  df <- check_wp(dir, verbose = FALSE)

  expect_equal(diag_status(df, "output-file"), "error")
})
