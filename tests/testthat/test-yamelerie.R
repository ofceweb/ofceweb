test_that("get_yaml() parses YAML frontmatter delimited by '---'", {
  path <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c(
    "---",
    "title: Mon post",
    "author: Alice",
    "---",
    "",
    "# Corps du document"
  ), path)

  yml <- get_yaml(path)

  expect_type(yml, "list")
  expect_equal(yml$title, "Mon post")
  expect_equal(yml$author, "Alice")
})

test_that("get_yaml() treats the whole file as YAML when there is no '---' delimiter", {
  path <- withr::local_tempfile(fileext = ".yml")
  writeLines(c("title: Sans frontmatter", "value: 42"), path)

  yml <- get_yaml(path)

  expect_equal(yml$title, "Sans frontmatter")
  expect_equal(yml$value, 42)
})

test_that("get_yaml() errors when only one '---' delimiter is found", {
  path <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("---", "title: Incomplet", "# Corps sans second délimiteur"), path)

  expect_error(get_yaml(path), "second delimiter")
})

test_that("put_yaml() writes a fresh file with '---' delimiters by default", {
  path <- withr::local_tempfile(fileext = ".qmd")

  put_yaml(list(title = "Nouveau", author = "Bob"), path)
  lines <- readLines(path)

  expect_equal(lines[1], "---")
  expect_true(any(grepl("^title:", lines)))
  expect_true(any(grepl("^author:", lines)))
  expect_true("---" %in% lines[-1])
})

test_that("put_yaml() preserves body content below the existing frontmatter", {
  path <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c(
    "---",
    "title: Ancien",
    "---",
    "",
    "Corps existant à préserver."
  ), path)

  put_yaml(list(title = "Mis à jour"), path)
  lines <- readLines(path)

  expect_true(any(grepl("title: Mis à jour", lines)))
  expect_true("Corps existant à préserver." %in% lines)
})

test_that("put_yaml() inserts extra lines right after the closing delimiter", {
  path <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c("---", "title: Ancien", "---", "", "Corps."), path)

  put_yaml(list(title = "Ancien"), path, insert = c("<!-- inséré -->"))
  lines <- readLines(path)

  expect_true("<!-- inséré -->" %in% lines)
  expect_true("Corps." %in% lines)
})

test_that("put_yaml() with pure = TRUE omits the '---' delimiters", {
  path <- withr::local_tempfile(fileext = ".yml")

  put_yaml(list(title = "Pur"), path, pure = TRUE)
  lines <- readLines(path)

  expect_false("---" %in% lines)
  expect_true(any(grepl("^title:", lines)))
})
