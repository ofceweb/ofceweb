# adhoc_check_deploy_prereqs() is the preflight gate run at the top of
# deploy_folder_worker(): it delegates GitHub/git diagnostics to the shared
# check_gh_setup() (never blocking), then requires a GitHub token and checks
# that the FTP_SERVER secret is visible to the repo (proxy for "authorized
# to publish"). These tests mock out check_gh_setup(), gh_slug_from_remote()
# and gh_secret_present() so no real network/git calls happen.
#
# The result is cached (in the shared .gh_checks_cache -- also used by
# check_gh_login() and check_prev()'s FTP checks, see git_utils.R) per repo,
# keyed on .gh_setup_generation$n (bumped by every check_gh_setup() call).
# The cache is reset before each test so entries can't leak across tests
# that reuse the same repo slug as a cache key.

reset_prereqs_cache <- function() {
  rm(list = ls(envir = .gh_checks_cache), envir = .gh_checks_cache)
}

test_that("adhoc_check_deploy_prereqs(): succeeds when token present and FTP_SERVER visible", {
  reset_prereqs_cache()
  withr::local_envvar(DEPLOY_PAT = "ghp_dummy")

  local_mocked_bindings(
    check_gh_setup     = function(root, verbose = TRUE) invisible(NULL),
    gh_slug_from_remote = function(root = ".") "ofce/some-repo",
    gh_secret_present   = function(owner, repo, pat, name) {
      expect_equal(owner, "ofce")
      expect_equal(repo, "some-repo")
      expect_equal(pat, "ghp_dummy")
      expect_equal(name, "FTP_SERVER")
      TRUE
    }
  )

  expect_true(adhoc_check_deploy_prereqs("some/root", progress = FALSE))
})

test_that("adhoc_check_deploy_prereqs(): aborts (with a config hint) when no GitHub token is available", {
  reset_prereqs_cache()
  withr::local_envvar(DEPLOY_PAT = NA)
  local_mocked_bindings(
    check_gh_setup = function(root, verbose = TRUE) invisible(NULL)
  )
  local_mocked_bindings(
    gitcreds_get = function(...) stop("no credentials"),
    .package = "gitcreds"
  )

  err <- tryCatch(
    adhoc_check_deploy_prereqs("some/root", progress = FALSE),
    error = function(e) e
  )
  expect_match(conditionMessage(err), "[Aa]ucun token")
  # The failure message points to the published prerequisites article and
  # tells the user how to recheck.
  expect_match(conditionMessage(err), "prerequisites", fixed = TRUE)
  expect_match(conditionMessage(err), "check_gh_setup", fixed = TRUE)
})

test_that("adhoc_check_deploy_prereqs(): aborts when no 'origin' remote is found", {
  reset_prereqs_cache()
  withr::local_envvar(DEPLOY_PAT = "ghp_dummy")
  local_mocked_bindings(
    check_gh_setup      = function(root, verbose = TRUE) invisible(NULL),
    gh_slug_from_remote = function(root = ".") NA_character_
  )

  expect_error(
    adhoc_check_deploy_prereqs("some/root", progress = FALSE),
    "origin"
  )
})

test_that("adhoc_check_deploy_prereqs(): aborts (with a config hint) when FTP_SERVER is confirmed absent", {
  reset_prereqs_cache()
  withr::local_envvar(DEPLOY_PAT = "ghp_dummy")
  local_mocked_bindings(
    check_gh_setup      = function(root, verbose = TRUE) invisible(NULL),
    gh_slug_from_remote = function(root = ".") "someuser/personal-repo",
    gh_secret_present   = function(owner, repo, pat, name) FALSE
  )

  err <- tryCatch(
    adhoc_check_deploy_prereqs("some/root", progress = FALSE),
    error = function(e) e
  )
  expect_match(conditionMessage(err), "FTP_SERVER")
  expect_match(conditionMessage(err), "prerequisites", fixed = TRUE)
  expect_match(conditionMessage(err), "check_gh_setup", fixed = TRUE)
})

test_that("adhoc_check_deploy_prereqs(): warns (non-blocking) when FTP_SERVER can't be checked", {
  reset_prereqs_cache()
  withr::local_envvar(DEPLOY_PAT = "ghp_dummy")
  local_mocked_bindings(
    check_gh_setup      = function(root, verbose = TRUE) invisible(NULL),
    gh_slug_from_remote = function(root = ".") "ofce/other-repo",
    gh_secret_present   = function(owner, repo, pat, name) stop("API unreachable")
  )

  expect_message(
    result <- adhoc_check_deploy_prereqs("some/root", progress = FALSE),
    "FTP_SERVER"
  )
  expect_true(result)
})

test_that("adhoc_check_deploy_prereqs(): caches a passing result per repo, invalidated by check_gh_setup()", {
  reset_prereqs_cache()
  withr::local_envvar(DEPLOY_PAT = "ghp_dummy")

  # Use the *real* check_gh_setup() here (with its own dependencies mocked)
  # so it genuinely bumps .gh_setup_generation$n, exercising the actual
  # cache invalidation mechanism rather than a stand-in.
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

  call_count <- 0
  local_mocked_bindings(
    gh_slug_from_remote = function(root = ".") "ofce/cached-repo",
    gh_secret_present   = function(owner, repo, pat, name) {
      call_count <<- call_count + 1L
      TRUE
    }
  )

  expect_true(adhoc_check_deploy_prereqs("some/root", progress = FALSE))
  expect_equal(call_count, 1L)

  # Second call for the same repo: cache hit, no new FTP_SERVER lookup. The
  # "already validated" notice is progress-gated like other informational
  # messages here, so request progress = TRUE to observe it.
  expect_message(
    expect_true(adhoc_check_deploy_prereqs("some/root", progress = TRUE)),
    "d\u00e9j\u00e0 valid\u00e9s"
  )
  expect_equal(call_count, 1L)

  # A direct check_gh_setup() call (e.g. the user re-verifying after fixing
  # something) bumps the generation and invalidates the cached entry.
  check_gh_setup("some/root", verbose = FALSE)

  expect_true(adhoc_check_deploy_prereqs("some/root", progress = FALSE))
  expect_equal(call_count, 2L)
})
