create_qmd_file <- function(dir, name = "index.qmd", lines = c("---", "title: Post", "---", "", "Corps.")) {
  path <- fs::path(dir, name)
  writeLines(lines, path)
  path
}

# ---- .resolve_qmd() ---------------------------------------------------------

test_that(".resolve_qmd() returns the path unchanged when given a .qmd file directly", {
  dir  <- withr::local_tempdir()
  path <- create_qmd_file(dir)

  resolved <- ofceweb:::.resolve_qmd(path)

  expect_equal(fs::path_norm(resolved), fs::path_norm(path))
})

test_that(".resolve_qmd() errors when the direct path is not a .qmd file", {
  dir  <- withr::local_tempdir()
  path <- fs::path(dir, "notes.txt")
  writeLines("texte", path)

  expect_error(ofceweb:::.resolve_qmd(path), "n'est pas un")
})

test_that(".resolve_qmd() errors when the path does not exist", {
  dir  <- withr::local_tempdir()
  path <- fs::path(dir, "absent.qmd")

  expect_error(ofceweb:::.resolve_qmd(path), "introuvable")
})

test_that(".resolve_qmd() finds the single .qmd in a directory", {
  dir <- withr::local_tempdir()
  create_qmd_file(dir, "index.qmd")

  resolved <- ofceweb:::.resolve_qmd(dir)

  expect_equal(fs::path_file(resolved), "index.qmd")
})

test_that(".resolve_qmd() ignores files whose name starts with '_'", {
  dir <- withr::local_tempdir()
  create_qmd_file(dir, "_metadata.qmd")
  create_qmd_file(dir, "index.qmd")

  resolved <- ofceweb:::.resolve_qmd(dir)

  expect_equal(fs::path_file(resolved), "index.qmd")
})

test_that(".resolve_qmd() errors when no .qmd is found in the directory", {
  dir <- withr::local_tempdir()
  writeLines("texte", fs::path(dir, "notes.txt"))

  expect_error(ofceweb:::.resolve_qmd(dir), "Aucun")
})

test_that(".resolve_qmd() errors when several .qmd files are found in the directory", {
  dir <- withr::local_tempdir()
  create_qmd_file(dir, "index.qmd")
  create_qmd_file(dir, "annexe.qmd")

  expect_error(ofceweb:::.resolve_qmd(dir), "Plusieurs")
})

# ---- .detect_packages() -----------------------------------------------------

test_that(".detect_packages() detects packages loaded via library()/require()", {
  dir  <- withr::local_tempdir()
  path <- create_qmd_file(dir, lines = c(
    "---", "title: Post", "---", "",
    "```{r}",
    "library(dplyr)",
    "require('ggplot2')",
    "```"
  ))

  pkgs <- ofceweb:::.detect_packages(path)

  expect_setequal(pkgs, c("dplyr", "ggplot2"))
})

test_that(".detect_packages() detects packages referenced via '::'", {
  dir  <- withr::local_tempdir()
  path <- create_qmd_file(dir, lines = c(
    "---", "title: Post", "---", "",
    "```{r}",
    "purrr::map(1:3, identity)",
    "stringr::str_detect('a', 'a')",
    "```"
  ))

  pkgs <- ofceweb:::.detect_packages(path)

  expect_setequal(pkgs, c("purrr", "stringr"))
})

test_that(".detect_packages() excludes base R packages", {
  dir  <- withr::local_tempdir()
  path <- create_qmd_file(dir, lines = c(
    "---", "title: Post", "---", "",
    "```{r}",
    "library(stats)",
    "utils::head(1:3)",
    "purrr::map(1:3, identity)",
    "```"
  ))

  pkgs <- ofceweb:::.detect_packages(path)

  expect_setequal(pkgs, "purrr")
})

test_that(".detect_packages() de-duplicates repeated package references", {
  dir  <- withr::local_tempdir()
  path <- create_qmd_file(dir, lines = c(
    "---", "title: Post", "---", "",
    "```{r}",
    "library(dplyr)",
    "dplyr::filter(mtcars, cyl == 4)",
    "dplyr::mutate(mtcars, x = 1)",
    "```"
  ))

  pkgs <- ofceweb:::.detect_packages(path)

  expect_equal(pkgs, "dplyr")
})

test_that(".detect_packages() returns an empty vector when no packages are referenced", {
  dir  <- withr::local_tempdir()
  path <- create_qmd_file(dir, lines = c(
    "---", "title: Post", "---", "",
    "Rien à voir ici, juste du texte."
  ))

  pkgs <- ofceweb:::.detect_packages(path)

  expect_length(pkgs, 0L)
})
