# wp_manifest() writes a `source-repo` field derived from the git `origin`
# remote — used by ftp_deploy.yml to detect a different repo reusing an
# already-published WP number.

build_manifest_repo <- function(dir, wp = 1L, annee = 2026L) {
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = wp,
    annee   = annee,
    lang    = "fr",
    version = "v0",
    website = list(
      title       = "Un WP",
      `site-url`  = "https://www.ofce.fr/",
      `site-path` = sprintf("%d/%d/v0", annee, wp)
    )
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un WP")
  invisible(dir)
}

test_that("wp_manifest() sets source-repo from the origin remote", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir)

  gert::git_init(path = dir)
  gert::git_remote_add(url = "https://github.com/ofce/wp2026-1.git", name = "origin", repo = dir)

  m <- wp_manifest(dir)

  expect_equal(m$`source-repo`, "ofce/wp2026-1")

  written <- jsonlite::fromJSON(fs::path(dir, "manifest.json"))
  expect_equal(written$`source-repo`, "ofce/wp2026-1")
})

test_that("wp_manifest() leaves source-repo unset without an origin remote", {
  dir <- withr::local_tempdir()
  build_manifest_repo(dir)
  # No git repo at all here — gh_slug_from_remote() must fail gracefully.

  m <- wp_manifest(dir)

  expect_null(m$`source-repo`)
})
