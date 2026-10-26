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

test_that("check_pb() passes the local pb_series (default 'ofce') to the registry diagnostic", {
  dir <- local_git_tempdir()
  gert::git_remote_add(url = "https://github.com/ofce/pb-x.git", name = "origin", repo = dir)
  write_quarto_yml(dir, list(pb = 3L, pb_series = "ife"))
  local_mocked_bindings(fetch_pb_entries = function(...) list(
    list(pb = 3L, pb_series = "ofce", type = "repo", `source-repo` = "ofce/pb-x")
  ))

  df <- check_pb(dir, verbose = FALSE)
  expect_equal(diag_status(df, "registry"), "warning")
  expect_match(df$message[df$field == "registry"], "3/ife", fixed = TRUE)

  # pb_series absent -> treated as "ofce" -> matches the registry entry
  write_quarto_yml(dir, list(pb = 3L))
  df <- check_pb(dir, verbose = FALSE)
  expect_equal(diag_status(df, "registry"), "ok")
})
