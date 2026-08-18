# Shared fixture builders for check_wp() / check_blog() tests.
# testthat auto-sources files matching ^helper.*\\.R$ before running tests.

# Writes a .qmd with YAML frontmatter + body to `dir/name`, returns the path.
write_qmd <- function(dir, name = "index.qmd", yaml_lines = character(), body_lines = "Corps.") {
  path <- fs::path(dir, name)
  writeLines(c("---", yaml_lines, "---", "", body_lines), path)
  path
}

# Writes a project-level `_quarto.yml` from a list, returns the path.
write_quarto_yml <- function(dir, yml) {
  path <- fs::path(dir, "_quarto.yml")
  yaml::write_yaml(yml, path)
  path
}

# Builds a minimal but fully valid *published* WP repo in `dir`: no
# check_wp() errors or warnings are expected against this fixture. Individual
# tests then delete/alter one element to trigger a specific diagnostic.
build_valid_wp_repo <- function(dir) {
  write_quarto_yml(dir, list(
    ofce_wp  = TRUE,
    annee    = 2024L,
    wp       = 12L,
    version  = "v1",
    date     = "2024-01-01",
    citation = list(type = "report"),
    author   = "Jane Doe",
    format   = list(`wp-html` = "default", `wp-pdf` = "default"),
    website  = list(
      `site-path`   = "2024/12/v1",
      `other-links` = list(
        list(text = "Annexes", href = "annexes.html"),
        list(text = "News",    href = "news.html")
      )
    )
  ))

  write_qmd(dir, "index.qmd", yaml_lines = "title: WP")
  write_qmd(dir, "annexes.qmd", yaml_lines = "title: Annexes")

  writeLines("", fs::path(dir, "references.bib"))
  writeLines("", fs::path(dir, "news.qmd"))
  writeLines("", fs::path(dir, "renv.lock"))

  fs::dir_create(fs::path(dir, ".github", "workflows"), recurse = TRUE)
  writeLines("", fs::path(dir, ".github", "workflows", "ftp_deploy.yml"))

  invisible(dir)
}

diag_status <- function(df, field) {
  df$status[df$field == field]
}

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

# prev_version_up(), wp_version_up() and site_version_up() touch the GitHub
# API (FTP server-dir variables) and, for wp_version_up()/site_version_up(),
# regenerate the manifest / rescan the site / push a redirect — all stubbed
# so the tests exercise only the YAML editing logic.
local_stub_version_up_side_effects <- function(env = parent.frame()) {
  local_mocked_bindings(
    set_gh_var         = function(...) invisible(NULL),
    wp_manifest        = function(...) invisible(NULL),
    rescan_site        = function(...) invisible(NULL),
    push_site_redirect = function(...) invisible(NULL),
    .env = env
  )
}
