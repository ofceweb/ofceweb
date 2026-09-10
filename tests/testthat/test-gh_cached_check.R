# gh_cached_check() is the shared caching primitive backing check_gh_login(),
# check_prev()'s FTP variable/secret checks, and adhoc_check_deploy_prereqs():
# a value is cached per key until check_gh_setup() runs again (bumping
# .gh_setup_generation$n), regardless of who calls check_gh_setup().

reset_gh_checks_cache <- function() {
  rm(list = ls(envir = .gh_checks_cache), envir = .gh_checks_cache)
}

test_that("gh_cached_check(): computes once and reuses the cached value on a hit", {
  reset_gh_checks_cache()
  calls <- 0L
  compute <- function() {
    calls <<- calls + 1L
    "value"
  }

  expect_equal(gh_cached_check("k1", compute), "value")
  expect_equal(gh_cached_check("k1", compute), "value")
  expect_equal(calls, 1L)
})

test_that("gh_cached_check(): different keys are cached independently", {
  reset_gh_checks_cache()
  expect_equal(gh_cached_check("a", function() "A"), "A")
  expect_equal(gh_cached_check("b", function() "B"), "B")
  # A still cached under its own key, unaffected by "b"
  expect_equal(gh_cached_check("a", function() "changed"), "A")
})

test_that("gh_cached_check(): invalidated once check_gh_setup() runs again", {
  reset_gh_checks_cache()
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
  withr::local_envvar(DEPLOY_PAT = "ghp_dummy")

  calls <- 0L
  compute <- function() {
    calls <<- calls + 1L
    calls
  }

  expect_equal(gh_cached_check("k", compute), 1L)
  expect_equal(gh_cached_check("k", compute), 1L) # still cached

  check_gh_setup(verbose = FALSE) # bumps .gh_setup_generation$n

  expect_equal(gh_cached_check("k", compute), 2L) # recomputed
})

test_that("gh_cached_check(): a compute() error is not cached", {
  reset_gh_checks_cache()
  attempt <- 0L
  compute_fails_once <- function() {
    attempt <<- attempt + 1L
    if (attempt == 1L) stop("boom")
    "recovered"
  }

  expect_error(gh_cached_check("err-key", compute_fails_once), "boom")
  # The failed attempt wasn't cached, so the second call recomputes and succeeds.
  expect_equal(gh_cached_check("err-key", compute_fails_once), "recovered")
  expect_equal(attempt, 2L)
})

test_that("check_gh_login(): caches the GitHub API result until check_gh_setup() reruns", {
  reset_gh_checks_cache()
  calls <- 0L
  local_mocked_bindings(
    gh = function(...) {
      calls <<- calls + 1L
      list(login = "jdoe")
    },
    .package = "gh"
  )

  expect_equal(check_gh_login(verbose = FALSE), "jdoe")
  expect_equal(check_gh_login(verbose = FALSE), "jdoe")
  expect_equal(calls, 1L)

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
  check_gh_setup(verbose = FALSE) # bumps the generation counter

  expect_equal(check_gh_login(verbose = FALSE), "jdoe")
  expect_equal(calls, 2L)
})
