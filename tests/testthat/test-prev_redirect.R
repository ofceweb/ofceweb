test_that("push_prev_staging_redirect() errors without _quarto.yml", {
  root <- tempfile()
  dir.create(root)
  expect_error(
    push_prev_staging_redirect(path = root),
    "Pas de.*_quarto.yml"
  )
})

test_that("push_prev_staging_redirect() errors without ofce_prev: true", {
  root <- tempfile()
  dir.create(root)
  yml_path <- file.path(root, "_quarto.yml")
  writeLines("project:\n  type: website", yml_path)
  expect_error(
    push_prev_staging_redirect(path = root),
    "ne fonctionne que sur un dépôt de prévision"
  )
})

test_that("push_prev_staging_redirect() errors without _quarto-staging.yml", {
  root <- tempfile()
  dir.create(root)
  yml_path <- file.path(root, "_quarto.yml")
  writeLines("ofce_prev: true", yml_path)
  expect_error(
    push_prev_staging_redirect(path = root),
    "Pas de.*_quarto-staging.yml"
  )
})

test_that("push_prev_staging_redirect() alerts when site-path is missing", {
  root <- tempfile()
  dir.create(root)
  yml_path <- file.path(root, "_quarto.yml")
  stg_path <- file.path(root, "_quarto-staging.yml")
  writeLines("ofce_prev: true", yml_path)
  writeLines("website: {}", stg_path)
  
  expect_message(
    push_prev_staging_redirect(path = root),
    "site-path.*absent"
  )
})

test_that("push_prev_staging_redirect() alerts when site-path has no version", {
  root <- tempfile()
  dir.create(root)
  yml_path <- file.path(root, "_quarto.yml")
  stg_path <- file.path(root, "_quarto-staging.yml")
  writeLines("ofce_prev: true", yml_path)
  writeLines("website:\n  site-path: 'prev2609'", stg_path)
  
  expect_message(
    push_prev_staging_redirect(path = root),
    "sans segment de version|redirection non nécessaire"
  )
})

test_that("push_prev_staging_redirect() alerts when version segment is malformed", {
  root <- tempfile()
  dir.create(root)
  yml_path <- file.path(root, "_quarto.yml")
  stg_path <- file.path(root, "_quarto-staging.yml")
  writeLines("ofce_prev: true", yml_path)
  writeLines("website:\n  site-path: 'prev2609/version1'", stg_path)
  
  expect_message(
    push_prev_staging_redirect(path = root),
    "ne se termine pas par un segment de version"
  )
})

test_that("build_redirect_html() generates correct HTML structure", {
  html <- ofceweb:::build_redirect_html(
    target = "/prev2609/",
    title = "Test redirection",
    link_label = "latest version (v2)"
  )
  
  # Check key components
  expect_match(html, '<meta http-equiv="refresh" content="0; url=/prev2609/">')
  expect_match(html, '<link rel="canonical" href="/prev2609/">')
  expect_match(html, '<title>Test redirection</title>')
  expect_match(html, 'href="/prev2609/"')
  expect_match(html, 'latest version \\(v2\\)')
  expect_match(html, 'window.location.replace\\("/prev2609/"\\)')
})

test_that("build_redirect_html() respects language parameter", {
  html <- ofceweb:::build_redirect_html(
    target = "/test/",
    title = "Test",
    link_label = "test",
    lang = "en"
  )
  expect_match(html, '<html lang="en">')
})
