# copy_post() operates on relative paths from the current working
# directory ("posts", "_fr/fr", ...), so tests build a minimal blog-repo
# skeleton in a temp dir and setwd() into it.
build_minimal_blog_repo <- function(dir, post_folder = "2026/mon-article") {
  fs::dir_create(fs::path(dir, "posts", post_folder), recurse = TRUE)
  write_yaml_lines <- function(path, lines) writeLines(lines, path)

  write_yaml_lines(fs::path(dir, "posts", "_metadata.yml"), c("categories: []"))

  write_qmd(
    fs::path(dir, "posts", post_folder), "index.fr.qmd",
    yaml_lines = c("title: Mon article", "date: 2026-01-01")
  )
  # copy_post() falls back to a shared placeholder image
  # (_utils/dta/logement.jpg) when a post has none of its own -- provide a
  # post-local image instead so the test doesn't depend on that shared asset.
  fs::file_create(fs::path(dir, "posts", post_folder, "photo.jpg"))
  invisible(dir)
}

test_that("copy_post() writes a version-less stable_url into the rendered copy's front matter", {
  dir <- withr::local_tempdir()
  build_minimal_blog_repo(dir, post_folder = "2026/mon-article")

  oldwd <- getwd()
  withr::defer(setwd(oldwd))
  setwd(dir)

  posts <- tibble::tibble(
    file_fr         = "2026/mon-article/index.fr.qmd",
    file_en         = NA_character_,
    title_fr        = "Mon article",
    title_en        = NA_character_,
    translated      = FALSE,
    description_fr  = NA_character_,
    description_en  = NA_character_,
    categories_fr   = list(character()),
    pdf_link_fr     = "2026/mon-article/index.fr.pdf",
    pdf_link_en     = NA_character_,
    gow             = FALSE
  )

  copy_post(posts, lang = "fr", typst = FALSE, progress = FALSE)

  new_qmd <- fs::path(dir, "_fr", "fr", "2026", "mon-article", "index.qmd")
  expect_true(fs::file_exists(new_qmd))

  yml <- get_yaml(new_qmd)
  expect_equal(
    yml$stable_url,
    "https://ofce.sciences-po.fr/blog2024/fr/2026/mon-article/"
  )
})
