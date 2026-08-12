test_that("check_blog() reports no error on a fully valid post with all dependencies present", {
  dir <- withr::local_tempdir()
  writeLines("", fs::path(dir, "references.bib"))
  writeLines("", fs::path(dir, "cover.png"))
  write_qmd(
    dir, "index.qmd",
    yaml_lines = c(
      "title: Mon post",
      "author: Alice",
      "date: 2024-01-01",
      "categories: [economie]",
      "bibliography: references.bib",
      "image: cover.png"
    ),
    body_lines = "Corps du post."
  )

  df <- check_blog(dir, verbose = FALSE)

  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df[df$status == "error", ]), 0L)
})

test_that("check_blog() errors when required frontmatter fields are missing", {
  dir <- withr::local_tempdir()
  write_qmd(dir, "index.qmd", yaml_lines = "title: Post incomplet")

  df <- check_blog(dir, verbose = FALSE)

  expect_equal(diag_status(df, "author"), "error")
  expect_equal(diag_status(df, "date"), "error")
  expect_equal(diag_status(df, "categories"), "error")
  expect_equal(diag_status(df, "title"), "ok")
})

test_that("check_blog() errors when a declared bibliography/image/csl file is missing", {
  dir <- withr::local_tempdir()
  write_qmd(
    dir, "index.qmd",
    yaml_lines = c(
      "title: Post",
      "author: Alice",
      "date: 2024-01-01",
      "categories: [economie]",
      "bibliography: absent.bib"
    )
  )

  df <- check_blog(dir, verbose = FALSE)

  expect_equal(diag_status(df, "bibliography"), "error")
})

test_that("check_blog() warns when a referenced local file dependency is missing", {
  dir <- withr::local_tempdir()
  write_qmd(
    dir, "index.qmd",
    yaml_lines = c(
      "title: Post",
      "author: Alice",
      "date: 2024-01-01",
      "categories: [economie]"
    ),
    body_lines = c(
      "```{r}",
      'readRDS("cache/manquant.rds")',
      "```"
    )
  )

  df <- check_blog(dir, verbose = FALSE)

  expect_equal(diag_status(df, "cache/manquant.rds"), "warning")
})

test_that("check_blog() does not warn about a referenced local file that exists", {
  dir <- withr::local_tempdir()
  fs::dir_create(fs::path(dir, "cache"))
  writeLines("", fs::path(dir, "cache", "present.rds"))
  write_qmd(
    dir, "index.qmd",
    yaml_lines = c(
      "title: Post",
      "author: Alice",
      "date: 2024-01-01",
      "categories: [economie]"
    ),
    body_lines = c(
      "```{r}",
      'readRDS("cache/present.rds")',
      "```"
    )
  )

  df <- check_blog(dir, verbose = FALSE)

  expect_false("cache/present.rds" %in% df$field[df$status == "warning"])
})

test_that("check_blog() propagates the .resolve_qmd() error when several .qmd files are present", {
  dir <- withr::local_tempdir()
  write_qmd(dir, "index.qmd", yaml_lines = "title: A")
  write_qmd(dir, "autre.qmd", yaml_lines = "title: B")

  expect_error(check_blog(dir, verbose = FALSE), "Plusieurs")
})

test_that("check_blog() errors when the YAML frontmatter cannot be parsed", {
  dir <- withr::local_tempdir()
  path <- fs::path(dir, "index.qmd")
  writeLines(c("---", "title: [unclosed", "  - broken", "---", "", "Corps."), path)

  df <- check_blog(path, verbose = FALSE)

  expect_equal(diag_status(df, "yaml"), "error")
})
