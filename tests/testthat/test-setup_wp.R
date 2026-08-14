# setup_wp() touches git, the GitHub API, and (via ofce::setup_quarto())
# the network; those calls are stubbed so the tests exercise only the
# _quarto.yml editing logic.
local_stub_wp_side_effects <- function(env = parent.frame()) {
  local_mocked_bindings(
    init_gh_pages_branch = function(...) invisible(NULL),
    set_gh_var           = function(...) invisible(NULL),
    .env = env
  )
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(name = character(), url = character()),
    .package = "gert",
    .env = env
  )
  local_mocked_bindings(
    setup_quarto = function(...) invisible(NULL),
    .package = "ofce",
    .env = env
  )
}

# Minimal published-WP repo carrying a legacy zero-padded site-path.
build_legacy_padded_wp_repo <- function(dir, wp = 7L, annee = 2026L) {
  write_quarto_yml(dir, list(
    ofce_wp = TRUE,
    wp      = wp,
    annee   = annee,
    lang    = "fr",
    version = "v0",
    website = list(
      title       = "Un WP hérité",
      `site-url`  = "https://www.ofce.fr/",
      `site-path` = sprintf("%d/%03d/v0", annee, wp)
    )
  ))
  write_qmd(dir, "index.qmd", yaml_lines = "title: Un WP hérité")
  invisible(dir)
}

test_that("setup_wp() rewrites a legacy zero-padded site-path to the unpadded form", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)

  suppressMessages(setup_wp(dir))
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))

  expect_equal(yml$website$`site-path`, "2026/7/v0")
  # citation.url is derived from site-path and must follow it.
  expect_equal(yml$citation$url, "https://www.ofce.fr/2026/7/")
})

test_that("setup_wp() warns that the deployment URL changes when the site-path is rewritten", {
  local_stub_wp_side_effects()
  withr::local_options(cli.width = 300)
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)

  msgs <- capture_messages(setup_wp(dir))

  expect_true(any(grepl("site-path modifi", msgs)))
  expect_true(any(grepl("URL diff", msgs)))
  expect_true(any(grepl("2026/007/v0", msgs, fixed = TRUE)))
  expect_true(any(grepl("2026/7/v0", msgs, fixed = TRUE)))
})

test_that("setup_wp() does not warn when the site-path is already unpadded", {
  local_stub_wp_side_effects()
  withr::local_options(cli.width = 300)
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)
  yml <- yaml::read_yaml(fs::path(dir, "_quarto.yml"))
  yml$website$`site-path` <- "2026/7/v0"
  write_quarto_yml(dir, yml)

  msgs <- capture_messages(setup_wp(dir))

  expect_false(any(grepl("site-path modifi", msgs)))
})

test_that("setup_wp() installs Quarto extensions via ofce::setup_quarto()", {
  calls <- list()
  local_mocked_bindings(
    init_gh_pages_branch = function(...) invisible(NULL),
    set_gh_var           = function(...) invisible(NULL)
  )
  local_mocked_bindings(
    git_remote_list = function(...) data.frame(name = character(), url = character()),
    .package = "gert"
  )
  local_mocked_bindings(
    setup_quarto = function(dir, ...) { calls[[length(calls) + 1L]] <<- dir; invisible(NULL) },
    .package = "ofce"
  )
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)

  suppressMessages(setup_wp(dir))

  expect_length(calls, 1L)
  expect_equal(fs::path_norm(calls[[1L]]), fs::path_norm(dir))
})

test_that("setup_wp() warns about legacy stray extensions left on disk", {
  local_stub_wp_side_effects()
  dir <- withr::local_tempdir()
  build_legacy_padded_wp_repo(dir)
  # Simulate a leftover flat `wp` extension from before the migration to
  # ofce::setup_quarto().
  legacy_ext <- fs::path(dir, "_extensions", "wp")
  fs::dir_create(legacy_ext, recurse = TRUE)
  writeLines("title: old", fs::path(legacy_ext, "_extension.yml"))

  msgs <- capture_messages(setup_wp(dir))

  expect_true(any(grepl("p\u00e9rim\u00e9e", msgs)))
  expect_true(any(grepl("_extensions/wp", msgs, fixed = TRUE)))
  # No automatic deletion.
  expect_true(fs::file_exists(fs::path(legacy_ext, "_extension.yml")))
})
