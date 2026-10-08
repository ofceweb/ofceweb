build_rendered_site <- function(dir, website) {
  write_quarto_yml(dir, list(website = website))
  fs::dir_create(fs::path(dir, "_site", c("fr/2024/post_a", "en/2024/post_a")))
  fs::file_create(fs::path(dir, "_site", c(
    "index.html", "fr/2024/post_a/index.html", "en/2024/post_a/index.html"
  )))
}

test_that("build_sitemap() prefixes every URL with site-url + site-path", {
  dir <- withr::local_tempdir()
  build_rendered_site(dir, list(
    `site-url` = "https://www.ofce.fr/", `site-path` = "blog2024/"
  ))
  withr::local_dir(dir)

  urls <- suppressMessages(build_sitemap(dir, progress = FALSE))

  expect_setequal(urls$loc, c(
    "https://www.ofce.fr/blog2024/index.html",
    "https://www.ofce.fr/blog2024/fr/2024/post_a/index.html",
    "https://www.ofce.fr/blog2024/en/2024/post_a/index.html"
  ))
  xml <- readLines(fs::path(dir, "_site", "sitemap.xml"))
  expect_equal(sum(grepl("<loc>https://www.ofce.fr/blog2024/", xml, fixed = TRUE)), 3)
})

test_that("build_sitemap() uses site-url alone when site-path is absent", {
  dir <- withr::local_tempdir()
  build_rendered_site(dir, list(`site-url` = "https://example.org"))
  withr::local_dir(dir)

  urls <- suppressMessages(build_sitemap(dir, progress = FALSE))

  expect_setequal(urls$loc, c(
    "https://example.org/index.html",
    "https://example.org/fr/2024/post_a/index.html",
    "https://example.org/en/2024/post_a/index.html"
  ))
})
