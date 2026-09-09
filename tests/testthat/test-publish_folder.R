# publish_folder() is a thin orchestrator: it should call render_folder_worker()
# then deploy_folder_worker(), forwarding the same `slug` to both, and return
# deploy_folder_worker()'s URL. Both workers are mocked out so this test
# exercises only the orchestration logic (order + argument propagation), not
# quarto rendering or any network/git side effects.

test_that("publish_folder(): calls render_folder_worker() then deploy_folder_worker(), sharing the same slug", {
  calls <- list()

  local_mocked_bindings(
    render_folder_worker = function(path, index, slug, progress, preview) {
      calls[[length(calls) + 1]] <<- list(fn = "render", path = path, slug = slug)
      invisible(NULL)
    },
    deploy_folder_worker = function(path, slug, encrypt, progress, trigger, full_deploy) {
      calls[[length(calls) + 1]] <<- list(fn = "deploy", path = path, slug = slug)
      invisible("https://staging.ofce.fr/some-repo/my-slug/")
    }
  )

  url <- publish_folder(
    path     = "some/path",
    slug     = "my-slug",
    progress = FALSE,
    as_job   = FALSE
  )

  # Both workers were called, exactly once each
  expect_length(calls, 2)

  # render_folder_worker() ran before deploy_folder_worker()
  expect_equal(calls[[1]]$fn, "render")
  expect_equal(calls[[2]]$fn, "deploy")

  # Both received the same slug and path
  expect_equal(calls[[1]]$slug, "my-slug")
  expect_equal(calls[[2]]$slug, "my-slug")
  expect_equal(calls[[1]]$path, "some/path")
  expect_equal(calls[[2]]$path, "some/path")

  # The deploy URL is passed through as the return value
  expect_equal(url, "https://staging.ofce.fr/some-repo/my-slug/")
})

test_that("publish_folder(): still shares a NULL slug across both workers when unset", {
  calls <- list()

  local_mocked_bindings(
    render_folder_worker = function(path, index, slug, progress, preview) {
      calls[[length(calls) + 1]] <<- list(fn = "render", slug = slug)
      invisible(NULL)
    },
    deploy_folder_worker = function(path, slug, encrypt, progress, trigger, full_deploy) {
      calls[[length(calls) + 1]] <<- list(fn = "deploy", slug = slug)
      invisible("https://staging.ofce.fr/some-repo/auto-slug/")
    }
  )

  publish_folder(path = "some/path", progress = FALSE, as_job = FALSE)

  expect_length(calls, 2)
  expect_equal(calls[[1]]$fn, "render")
  expect_equal(calls[[2]]$fn, "deploy")
  expect_null(calls[[1]]$slug)
  expect_null(calls[[2]]$slug)
})

test_that("publish_folder(): forwards encrypt/trigger/full_deploy/progress to deploy_folder_worker()", {
  captured <- NULL

  local_mocked_bindings(
    render_folder_worker = function(path, index, slug, progress, preview) invisible(NULL),
    deploy_folder_worker = function(path, slug, encrypt, progress, trigger, full_deploy) {
      captured <<- list(
        encrypt     = encrypt,
        progress    = progress,
        trigger     = trigger,
        full_deploy = full_deploy
      )
      invisible("https://staging.ofce.fr/some-repo/my-slug/")
    }
  )

  publish_folder(
    path        = "some/path",
    slug        = "my-slug",
    encrypt     = FALSE,
    progress    = FALSE,
    trigger     = FALSE,
    full_deploy = TRUE,
    as_job      = FALSE
  )

  expect_equal(captured$encrypt, FALSE)
  expect_equal(captured$progress, FALSE)
  expect_equal(captured$trigger, FALSE)
  expect_equal(captured$full_deploy, TRUE)
})
