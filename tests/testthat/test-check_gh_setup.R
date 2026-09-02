test_that("check_gh_setup() reports all ok when gh/token/identity are all present", {
  withr::local_envvar(DEPLOY_PAT = "ghp_dummy")
  local_mocked_bindings(
    Sys.which = function(...) "/usr/bin/gh",
    system2   = function(...) 0L,
    .package = "base"
  )
  local_mocked_bindings(
    git_config_get = function(name, repo = ".") {
      if (name == "user.name") "Jane Doe" else "jane@example.com"
    },
    .package = "gert"
  )

  df <- check_gh_setup(verbose = FALSE)

  expect_s3_class(df, "data.frame")
  expect_setequal(df$field, c("gh:cli", "gh:auth", "gh:deploy_pat", "git:identity"))
  expect_true(all(df$status == "ok"))
})

test_that("check_gh_setup() warns (non-blocking) when gh/token/identity are all absent", {
  withr::local_envvar(DEPLOY_PAT = NA)
  local_mocked_bindings(
    Sys.which = function(...) "",
    system2   = function(...) 1L,
    .package = "base"
  )
  local_mocked_bindings(
    gitcreds_get = function(...) stop("no credentials"),
    .package = "gitcreds"
  )
  local_mocked_bindings(
    git_config_get        = function(...) NULL,
    git_config_global_get = function(...) NULL,
    .package = "gert"
  )

  df <- check_gh_setup(verbose = FALSE)

  expect_true(all(df$status == "warning"))
  expect_true(all(grepl("prerequisites", df$message)))
})

test_that("check_gh_setup() falls back to gitcreds when DEPLOY_PAT is unset", {
  withr::local_envvar(DEPLOY_PAT = NA)
  local_mocked_bindings(
    Sys.which = function(...) "",
    system2   = function(...) 1L,
    .package = "base"
  )
  local_mocked_bindings(
    gitcreds_get = function(...) list(password = "gho_from_keystore"),
    .package = "gitcreds"
  )
  local_mocked_bindings(
    git_config_get        = function(...) NULL,
    git_config_global_get = function(...) NULL,
    .package = "gert"
  )

  df <- check_gh_setup(verbose = FALSE)

  expect_equal(df$status[df$field == "gh:deploy_pat"], "ok")
  expect_match(df$message[df$field == "gh:deploy_pat"], "gitcreds")
})

test_that("check_gh_setup() falls back to global git config when local identity is unset", {
  withr::local_envvar(DEPLOY_PAT = NA)
  local_mocked_bindings(
    Sys.which = function(...) "",
    system2   = function(...) 1L,
    .package = "base"
  )
  local_mocked_bindings(
    gitcreds_get = function(...) stop("no credentials"),
    .package = "gitcreds"
  )
  local_mocked_bindings(
    git_config_get        = function(...) NULL,
    git_config_global_get = function(name) if (name == "user.name") "Jane Doe" else "jane@example.com",
    .package = "gert"
  )

  df <- check_gh_setup(verbose = FALSE)

  expect_equal(df$status[df$field == "git:identity"], "ok")
})
