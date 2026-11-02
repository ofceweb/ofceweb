# sync_back_thumbnail() works on paths relative to the blog root
# ("_fr/fr/...", "_fr/_sav_graph/...", "posts/..."), so tests build that
# layout in a temp dir and setwd() into it.
build_thumbnail_layout <- function(dir, name = "2026/mon-article",
                                   labels = c("fig-a", "fig-b")) {
  origin <- fs::path(dir, "_fr", "fr", name)
  source <- fs::path(dir, "posts", name)
  fs::dir_create(c(origin, source))
  fs::file_create(fs::path(origin, "image.png"))
  sav <- fs::path(dir, "_fr", "_sav_graph", "fr-2026")
  fs::dir_create(sav)
  for (i in seq_along(labels)) {
    f <- fs::path(sav, stringr::str_c("mon-article-index-", labels[[i]], ".ggplot"))
    fs::file_create(f)
    Sys.setFileTime(f, Sys.time() + i)
  }
  tibble::tibble(
    origin = fs::path("_fr", "fr", name),
    source = fs::path("posts", name),
    name = name,
    from_cache = FALSE,
    yaml = list(list(image = "image.png")))
}

test_that("sync_back_thumbnail() copies a generated image back to posts/ and names the first figure", {
  dir <- withr::local_tempdir()
  cached <- build_thumbnail_layout(dir)
  withr::local_dir(dir)

  expect_message(
    n <- sync_back_thumbnail(cached, "fr"),
    "image créée à partir du #fig-a du document")
  expect_equal(n, 1L)
  expect_true(fs::file_exists("posts/2026/mon-article/image.png"))
})

test_that("sync_back_thumbnail() never overwrites an image already in posts/", {
  dir <- withr::local_tempdir()
  cached <- build_thumbnail_layout(dir)
  writeLines("auteur", fs::path(dir, "posts/2026/mon-article/image.png"))
  withr::local_dir(dir)

  expect_equal(suppressMessages(sync_back_thumbnail(cached, "fr")), 0L)
  expect_equal(readLines("posts/2026/mon-article/image.png"), "auteur")
})

test_that("sync_back_thumbnail() skips posts served from cache or without saved graphs", {
  dir <- withr::local_tempdir()
  cached <- build_thumbnail_layout(dir, labels = character())
  withr::local_dir(dir)

  expect_equal(suppressMessages(sync_back_thumbnail(cached, "fr")), 0L)
  cached$from_cache <- TRUE
  expect_equal(suppressMessages(sync_back_thumbnail(cached, "fr")), 0L)
  expect_false(fs::file_exists("posts/2026/mon-article/image.png"))
})

test_that("sync_back_thumbnail() uses the chunk chosen by image: fig-{label} and refreshes it", {
  dir <- withr::local_tempdir()
  cached <- build_thumbnail_layout(dir)
  cached$yaml <- list(list(image = "fig-b.png"))
  fs::file_move(fs::path(dir, "_fr/fr/2026/mon-article/image.png"),
                fs::path(dir, "_fr/fr/2026/mon-article/fig-b.png"))
  writeLines("ancienne", fs::path(dir, "posts/2026/mon-article/fig-b.png"))
  withr::local_dir(dir)

  expect_message(
    n <- sync_back_thumbnail(cached, "fr"),
    "image créée à partir du #fig-b du document")
  expect_equal(n, 1L)
  expect_false(identical(readLines("posts/2026/mon-article/fig-b.png", warn = FALSE), "ancienne"))
})
