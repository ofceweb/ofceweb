# check_pb() requires its target directory to already be a git repo (blocking
# precondition, checked first via git_repo_root() -- see R/git_utils.R). No
# other check_pb()-specific test file exists yet; this one is scoped to that
# one behaviour.

test_that("check_pb() blocks with a git:repo error when the directory is not a git repository", {
  dir <- withr::local_tempdir()

  df <- check_pb(dir, verbose = FALSE)

  expect_equal(nrow(df), 1L)
  expect_equal(df$field[1], "git:repo")
  expect_equal(df$status[1], "error")
})

test_that("check_pb() proceeds past the git-repo check for an actual git repository", {
  dir <- local_git_tempdir()

  df <- check_pb(dir, verbose = FALSE)

  expect_false("git:repo" %in% df$field)
  expect_true("_quarto.yml" %in% df$field)
  expect_equal(diag_status(df, "_quarto.yml"), "error")
})
