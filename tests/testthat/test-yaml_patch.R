# Unit tests for the comment-preserving YAML text-patching primitives used
# by setup_wp(), setup_prev(), setup_site() and update_navbar().

test_that("yaml_patch_scalar() updates an existing top-level scalar in place", {
  lines <- c("# top comment", "lang: fr", "wp: 10")
  out <- yaml_patch_scalar(lines, "wp", 11L)
  expect_equal(out, c("# top comment", "lang: fr", "wp: 11"))
})

test_that("yaml_patch_scalar() updates an existing nested scalar in place", {
  lines <- c(
    "website:",
    "  title: Old Title",
    "  site-url: https://example.com/"
  )
  out <- yaml_patch_scalar(lines, "website.title", "New Title")
  expect_equal(out, c(
    "website:",
    "  title: New Title",
    "  site-url: https://example.com/"
  ))
})

test_that("yaml_patch_scalar() creates a missing top-level key at end of file", {
  lines <- c("lang: fr", "wp: 10")
  out <- yaml_patch_scalar(lines, "citation.url", "https://example.com/")
  expect_equal(out, c(
    "lang: fr", "wp: 10",
    "citation:",
    "  url: https://example.com/"
  ))
})

test_that("yaml_patch_scalar() creates a missing nested key inside an existing block", {
  lines <- c(
    "website:",
    "  title: T",
    "  site-url: https://example.com/"
  )
  out <- yaml_patch_scalar(lines, "website.repo-url", "https://github.com/ofce/x/")
  expect_equal(out, c(
    "website:",
    "  title: T",
    "  site-url: https://example.com/",
    "  repo-url: https://github.com/ofce/x/"
  ))
})

test_that("yaml_patch_scalar() no-op leaves lines identical when value is unchanged", {
  lines <- c("# comment", "wp: 10", "annee: 2026")
  out <- yaml_patch_scalar(lines, "wp", 10L)
  expect_identical(out, lines)
})

test_that("yaml_patch_scalar() preserves comments and blank lines elsewhere", {
  lines <- c(
    "# header comment",
    "lang: fr",
    "",
    "# website section",
    "website:",
    "  title: Old",
    "  # pinned repo",
    "  repo-url: https://github.com/ofce/x/"
  )
  out <- yaml_patch_scalar(lines, "website.title", "New")
  expect_equal(out, c(
    "# header comment",
    "lang: fr",
    "",
    "# website section",
    "website:",
    "  title: New",
    "  # pinned repo",
    "  repo-url: https://github.com/ofce/x/"
  ))
})

test_that("yaml_patch_delete() removes only the target scalar line", {
  lines <- c("lang: fr", "wp: 10", "annee: 2026")
  out <- yaml_patch_delete(lines, "wp")
  expect_equal(out, c("lang: fr", "annee: 2026"))
})

test_that("yaml_patch_delete() removes a mapping key and its whole subtree", {
  lines <- c(
    "lang: fr",
    "comments:",
    "  hypothesis: true",
    "wp: 10"
  )
  out <- yaml_patch_delete(lines, "comments")
  expect_equal(out, c("lang: fr", "wp: 10"))
})

test_that("yaml_patch_delete() is a no-op when the path doesn't exist", {
  lines <- c("lang: fr", "wp: 10")
  out <- yaml_patch_delete(lines, "website.site-path")
  expect_identical(out, lines)
})

test_that("yaml_patch_block() replaces an existing structural subtree", {
  lines <- c(
    "website:",
    "  navbar:",
    "    left:",
    "      - text: A",
    "    logo: /old.png"
  )
  out <- yaml_patch_block(lines, "website.navbar.left", list(list(text = "B", href = "b.html")))
  expect_equal(out, c(
    "website:",
    "  navbar:",
    "    left:",
    "      - text: B",
    "        href: b.html",
    "    logo: /old.png"
  ))
})

test_that("yaml_patch_block() creates a fully missing intermediate chain, correctly nested", {
  lines <- c("website:", "  title: T")
  out <- yaml_patch_block(lines, "website.navbar.left", list(list(text = "A", href = "a.html")))
  expect_equal(out, c(
    "website:",
    "  title: T",
    "  navbar:",
    "    left:",
    "      - text: A",
    "        href: a.html"
  ))
})

test_that("yaml_patch_block() with value = NULL deletes the key", {
  lines <- c("website:", "  other-links:", "    - text: A", "  title: T")
  out <- yaml_patch_block(lines, "website.other-links", NULL)
  expect_equal(out, c("website:", "  title: T"))
})

test_that("yaml_patch_scalar_or_delete() deletes when value is NULL, sets otherwise", {
  lines <- c("wp: 10", "annee: 2026")
  expect_equal(yaml_patch_scalar_or_delete(lines, "wp", NULL), c("annee: 2026"))
  expect_equal(yaml_patch_scalar_or_delete(lines, "wp", 12L), c("wp: 12", "annee: 2026"))
})

test_that("yaml_scalar_repr() quotes ambiguous or special-character strings", {
  expect_equal(yaml_scalar_repr("plain"), "plain")
  expect_equal(yaml_scalar_repr("has: colon"), "'has: colon'")
  expect_equal(yaml_scalar_repr("has # hash"), "'has # hash'")
  expect_equal(yaml_scalar_repr("true"), "'true'")
  expect_equal(yaml_scalar_repr("2026"), "'2026'")
  expect_equal(yaml_scalar_repr(TRUE), "true")
  expect_equal(yaml_scalar_repr(FALSE), "false")
  expect_equal(yaml_scalar_repr(10L), "10")
})

test_that("yaml_scalar_repr() round-trips embedded quotes and unicode", {
  val <- "it's a café"
  repr <- yaml_scalar_repr(val)
  parsed <- yaml::yaml.load(paste0("x: ", repr))
  expect_equal(parsed$x, val)
})

test_that("yaml_scalar_repr() falls back to an escaped double-quoted string for multiline values", {
  val <- "line1\nline2"
  repr <- yaml_scalar_repr(val)
  expect_false(grepl("\n", repr, fixed = TRUE))
  parsed <- yaml::yaml.load(paste0("x: ", repr))
  expect_equal(parsed$x, val)
})

test_that("yaml_patch_frontmatter_scalar() patches a .qmd frontmatter key, preserving the body and comments", {
  path <- withr::local_tempfile(fileext = ".qmd")
  writeLines(c(
    "---",
    "title: Old",
    "format:",
    "  # keep toc on",
    "  wp-pdf:",
    "    toc: true",
    "---",
    "",
    "Body text."
  ), path)

  yaml_patch_frontmatter_scalar(path, "format.wp-pdf.output-file", "OFCEWP2026-1.pdf")
  lines <- readLines(path)

  expect_true(any(grepl("output-file: OFCEWP2026-1.pdf", lines, fixed = TRUE)))
  expect_true(any(grepl("keep toc on", lines)))
  expect_true(any(grepl("toc: true", lines)))
  expect_true("Body text." %in% lines)
})

test_that("a realistic multi-field _quarto.yml patch sequence preserves unrelated comments and layout", {
  lines <- c(
    "# Quarto config for this working paper",
    "lang: fr",
    "comments:",
    "  # keep hypothesis comments on for drafts",
    "  hypothesis: true",
    "ofce_wp: true",
    "annee: 2026",
    "wp: 10",
    "",
    "# --- website section ---",
    "website:",
    "  title: Old Title",
    "  site-url: https://www.ofce.fr/",
    "  site-path: 2026/010/v0",
    ""
  )

  out <- lines
  out <- yaml_patch_scalar(out, "website.title", "New Title")
  out <- yaml_patch_scalar(out, "annee", 2027L)
  out <- yaml_patch_scalar(out, "website.site-path", "2026/10/v1")
  out <- yaml_patch_scalar(out, "citation.url", "https://www.ofce.fr/2026/10/")

  expect_true(any(grepl("^# Quarto config", out)))
  expect_true(any(grepl("keep hypothesis comments", out)))
  expect_true(any(grepl("^# --- website section", out)))
  expect_true(any(grepl("^$", out))) # blank line preserved

  parsed <- yaml::yaml.load(paste(out, collapse = "\n"))
  expect_equal(parsed$website$title, "New Title")
  expect_equal(parsed$annee, 2027L)
  expect_equal(parsed$website$`site-path`, "2026/10/v1")
  expect_equal(parsed$citation$url, "https://www.ofce.fr/2026/10/")
  expect_true(isTRUE(parsed$comments$hypothesis)) # untouched field still correct
})
