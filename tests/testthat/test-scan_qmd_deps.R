create_qmd <- function(dir, name = "index.qmd", yaml_lines = character(), body_lines = character()) {
  path <- fs::path(dir, name)
  writeLines(c("---", yaml_lines, "---", "", body_lines), path)
  path
}

test_that("scan_qmd_deps() picks up bibliography/image/csl declared in YAML", {
  dir <- withr::local_tempdir()
  path <- create_qmd(
    dir,
    yaml_lines = c(
      "title: Post",
      "bibliography: references.bib",
      "image: cover.png",
      "csl: apa.csl"
    )
  )

  deps <- scan_qmd_deps(path)

  expect_setequal(deps, c("references.bib", "cover.png", "apa.csl"))
})

test_that("scan_qmd_deps() detects file references in common R data-loading calls", {
  dir <- withr::local_tempdir()
  path <- create_qmd(
    dir,
    yaml_lines = "title: Post",
    body_lines = c(
      "```{r}",
      'df <- readr::read_csv("data/values.csv")',
      'raw <- readRDS("cache/model.rds")',
      'lines <- readLines("notes.txt")',
      'tbl <- qs2::qs_read("data/table.qs")',
      "```"
    )
  )

  deps <- scan_qmd_deps(path)

  expect_true("data/values.csv" %in% deps)
  expect_true("cache/model.rds" %in% deps)
  expect_true("notes.txt" %in% deps)
  expect_true("data/table.qs" %in% deps)
})

test_that("scan_qmd_deps() detects markdown images and Quarto include shortcodes", {
  dir <- withr::local_tempdir()
  path <- create_qmd(
    dir,
    yaml_lines = "title: Post",
    body_lines = c(
      "![Légende](figures/plot.png)",
      "{{< include _shared.qmd >}}"
    )
  )

  deps <- scan_qmd_deps(path)

  expect_true("figures/plot.png" %in% deps)
  expect_true("_shared.qmd" %in% deps)
})

test_that("scan_qmd_deps() excludes URLs, absolute paths, and '../' references", {
  dir <- withr::local_tempdir()
  path <- create_qmd(
    dir,
    yaml_lines = "title: Post",
    body_lines = c(
      "![distant](https://example.com/img.png)",
      "![absolu](/www/logo.png)",
      "![parent](../shared/logo.png)",
      "![local](assets/logo.png)"
    )
  )

  deps <- scan_qmd_deps(path)

  expect_false(any(grepl("^https?://", deps)))
  expect_false(any(grepl("^/", deps)))
  expect_false(any(grepl("\\.\\./", deps)))
  expect_true("assets/logo.png" %in% deps)
})

test_that("scan_qmd_deps() de-duplicates repeated references", {
  dir <- withr::local_tempdir()
  path <- create_qmd(
    dir,
    yaml_lines = c("title: Post", "image: cover.png"),
    body_lines = c(
      "![Couverture](cover.png)",
      "![Encore](cover.png)"
    )
  )

  deps <- scan_qmd_deps(path)

  expect_equal(sum(deps == "cover.png"), 1L)
})

test_that("scan_qmd_deps() returns no dependencies for a post referencing nothing local", {
  dir <- withr::local_tempdir()
  path <- create_qmd(
    dir,
    yaml_lines = c("title: Post simple", "author: Alice"),
    body_lines = c("Rien à voir ici, juste du texte.")
  )

  deps <- scan_qmd_deps(path)

  expect_length(deps, 0L)
})
