# Unit tests for the output-file collision helpers used by render_flash().
# Integration with a real quarto render lives in test-adhoc_site-integration.R.

test_that("adhoc_guess_output_ext: extension guessing by format name", {
  expect_equal(adhoc_guess_output_ext("wp-pdf"), ".pdf")
  expect_equal(adhoc_guess_output_ext("pdf"), ".pdf")
  expect_equal(adhoc_guess_output_ext("wp-typst"), ".typ")
  expect_equal(adhoc_guess_output_ext("docx"), ".docx")
  expect_equal(adhoc_guess_output_ext("word-note"), ".docx")
  expect_equal(adhoc_guess_output_ext("pres-revealjs"), ".html")
  expect_equal(adhoc_guess_output_ext("wp-html"), ".html")
  expect_equal(adhoc_guess_output_ext("ofce-html"), ".html")
})

test_that("adhoc_collide_outputs: detects duplicates, keeps original spelling", {
  outputs <- c(a = "doc.html", b = "doc.html", c = "other.html")
  hits <- adhoc_collide_outputs(outputs)
  expect_type(hits, "list")
  expect_length(hits, 1L)
  expect_equal(hits[[1]]$file, "doc.html")
  expect_setequal(hits[[1]]$formats, c("a", "b"))
})

test_that("adhoc_collide_outputs: NULL when all distinct", {
  outputs <- c(a = "doc.html", b = "slides.html", c = "doc.pdf")
  expect_null(adhoc_collide_outputs(outputs))
})

test_that("adhoc_collide_outputs: backslash and case normalization", {
  # The slash normalization is unconditional; the case-fold only on Windows.
  outputs <- c(a = "sub\\doc.html", b = "sub/doc.html")
  hits <- adhoc_collide_outputs(outputs)
  expect_length(hits, 1L)

  outputs <- c(a = "Doc.html", b = "doc.html")
  hits <- adhoc_collide_outputs(outputs)
  if (.Platform$OS.type == "windows") {
    expect_length(hits, 1L)
    expect_equal(hits[[1]]$file, "Doc.html") # original spelling kept for the message
  } else {
    expect_null(hits)
  }
})

test_that("adhoc_collide_outputs: three-way collision is one entry", {
  outputs <- c(a = "doc.html", b = "doc.html", c = "DOC.html", d = "x.pdf")
  hits <- adhoc_collide_outputs(outputs)
  expect_length(hits, 1L)
  if (.Platform$OS.type == "windows") {
    expect_setequal(hits[[1]]$formats, c("a", "b", "c"))
  } else {
    expect_setequal(hits[[1]]$formats, c("a", "b"))
  }
})

# ---------------------------------------------------------------------------
# adhoc_output_collisions_heuristic(): frontmatter-only, no quarto involved.
# ---------------------------------------------------------------------------

write_collision_qmd <- function(lines, ext = ".qmd") {
  path <- tempfile(fileext = ext)
  writeLines(c("---", lines, "---", "", "Body.", ""), path)
  path
}

test_that("adhoc_output_collisions_heuristic: flags implicit same-default collision", {
  path <- write_collision_qmd(c(
    "title: 'Slides'",
    "format:",
    "  pres-revealjs: default",
    "  wp-html:",
    "    self-contained: true"
  ))
  hits <- adhoc_output_collisions_heuristic(path)
  expect_type(hits, "list")
  expect_length(hits, 1L)
  expect_setequal(hits[[1]]$formats, c("pres-revealjs", "wp-html"))
  expect_match(hits[[1]]$file, "\\.html$")
})

test_that("adhoc_output_collisions_heuristic: NULL when explicit output files differ", {
  path <- write_collision_qmd(c(
    "title: 'Distinct'",
    "format:",
    "  pres-revealjs:",
    "    output-file: slides.html",
    "  wp-html:",
    "    output-file: document.html"
  ))
  expect_null(adhoc_output_collisions_heuristic(path))
})

test_that("adhoc_output_collisions_heuristic: NULL when extensions differ", {
  # Two formats, no explicit output-file, but distinct guessed extensions.
  path <- write_collision_qmd(c(
    "title: 'Mixed'",
    "format:",
    "  wp-html: default",
    "  wp-pdf: default"
  ))
  expect_null(adhoc_output_collisions_heuristic(path))
})

test_that("adhoc_output_collisions_heuristic: single format or no format never collides", {
  expect_null(adhoc_output_collisions_heuristic(
    write_collision_qmd(c("title: 'One'", "format: pres-revealjs"))
  ))
  expect_null(adhoc_output_collisions_heuristic(
    write_collision_qmd(c("format:", "  pres-revealjs: default"))
  ))
  expect_null(adhoc_output_collisions_heuristic(
    write_collision_qmd(c("title: 'No format'")
  )))
})

# ---------------------------------------------------------------------------
# adhoc_output_collisions(): the cheap gate (single/no format) returns NULL
# without ever invoking quarto. The 2+ format paths are exercised end-to-end
# in test-adhoc_site-integration.R with a real quarto inspect.
# ---------------------------------------------------------------------------

test_that("adhoc_output_collisions: single or absent format short-circuits to NULL", {
  expect_null(adhoc_output_collisions(
    write_collision_qmd(c("title: 'One'", "format: wp-html"))
  ))
  expect_null(adhoc_output_collisions(
    write_collision_qmd(c("title: 'No format'")
  )))
  expect_null(adhoc_output_collisions(
    write_collision_qmd(c("format:", "  wp-html: default"))
  ))
})

test_that("adhoc_quarto_bin: returns a non-empty, non-NA string", {
  bin <- adhoc_quarto_bin()
  expect_type(bin, "character")
  expect_length(bin, 1L)
  expect_false(is.na(bin))
  expect_true(nzchar(bin))
})
