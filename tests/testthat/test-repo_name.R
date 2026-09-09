# validate_repo_name() aborts when the local folder name doesn't match the
# canonical name expected for blog/ife/home (webblog/ife_webhome/webhome).
# wp/pb/prev/site are deliberately not covered (see R/repo_type.R).

test_that("validate_repo_name() passes for a correctly named blog repo", {
  dir <- fs::path(withr::local_tempdir(), "webblog")
  fs::dir_create(dir)
  expect_no_error(validate_repo_name("blog", dir))
})

test_that("validate_repo_name() passes for a correctly named ife repo", {
  dir <- fs::path(withr::local_tempdir(), "ife_webhome")
  fs::dir_create(dir)
  expect_no_error(validate_repo_name("ife", dir))
})

test_that("validate_repo_name() passes for a correctly named home repo", {
  dir <- fs::path(withr::local_tempdir(), "webhome")
  fs::dir_create(dir)
  expect_no_error(validate_repo_name("home", dir))
})

test_that("validate_repo_name() aborts for a mismatched blog folder name", {
  dir <- withr::local_tempdir() # random name, not "webblog"
  expect_error(validate_repo_name("blog", dir), "webblog")
})

test_that("validate_repo_name() aborts for a mismatched ife folder name", {
  dir <- withr::local_tempdir()
  expect_error(validate_repo_name("ife", dir), "ife_webhome")
})

test_that("validate_repo_name() aborts for a mismatched home folder name", {
  dir <- withr::local_tempdir()
  expect_error(validate_repo_name("home", dir), "webhome")
})

test_that("validate_repo_name() is a no-op for wp/pb/prev/site", {
  dir <- withr::local_tempdir()
  expect_no_error(validate_repo_name("wp", dir))
  expect_no_error(validate_repo_name("pb", dir))
  expect_no_error(validate_repo_name("prev", dir))
  expect_no_error(validate_repo_name("site", dir))
})

test_that("render() aborts via validate_repo_name() for a mismatched blog folder, both auto-detected and forced type=", {
  dir <- withr::local_tempdir() # not named "webblog"
  write_quarto_yml(dir, list(title = "Un blog"))
  fs::dir_create(fs::path(dir, "posts"))

  local_mocked_bindings(
    render_blog = function(...) stop("should not be called")
  )

  expect_error(suppressMessages(render(dir)), "webblog")
  expect_error(suppressMessages(render(dir, type = "blog")), "webblog")
})
