# Unit tests for update_quarto_ife() — installs or updates the quarto-ife
# Quarto extension from the latest published tag. The tag listing
# (quarto_ife_remote_tags()) and the installation (quarto_ife_install()) are
# mocked: no network, git or Quarto call is made.

# Writes `_extensions/ife/ife/_extension.yml` at `version` under `dir`, as
# `quarto add ofceweb/quarto-ife@v<version>` would.
fake_quarto_ife <- function(dir, version) {
  p <- fs::path(dir, "_extensions", "ife", "ife")
  fs::dir_create(p, recurse = TRUE)
  writeLines(c("title: Format IFE", paste0("version: ", version)),
             fs::path(p, "_extension.yml"))
}

test_that("quarto_ife_latest_tag() picks the highest vX.Y.Z tag numerically", {
  expect_identical(
    quarto_ife_latest_tag(c("v0.9.0", "v0.10.0", "v0.2.1")),
    "0.10.0"
  )
})

test_that("quarto_ife_latest_tag() ignores tags not of the form vX.Y.Z", {
  expect_identical(
    quarto_ife_latest_tag(c("v0.1.0", "v2.0.0-rc1", "latest", "1.0.0", "v0.2")),
    "0.1.0"
  )
  expect_error(quarto_ife_latest_tag(c("latest", "v1")), "version")
  expect_error(quarto_ife_latest_tag(character()), "version")
})

test_that("quarto_ife_installed_version() reads the installed version, NULL if absent", {
  dir <- withr::local_tempdir()
  expect_null(quarto_ife_installed_version(dir))
  fake_quarto_ife(dir, "0.1.0")
  expect_identical(quarto_ife_installed_version(dir), "0.1.0")
})

test_that("update_quarto_ife() installs the latest version when the extension is absent", {
  dir <- withr::local_tempdir()
  installed_with <- NULL
  local_mocked_bindings(
    quarto_ife_remote_tags = function() c("v0.1.0", "v0.2.0"),
    quarto_ife_install = function(path, version) {
      installed_with <<- version
      fake_quarto_ife(path, version)
    }
  )

  expect_message(res <- update_quarto_ife(dir), "0.2.0")
  expect_identical(installed_with, "0.2.0")
  expect_identical(res, "0.2.0")
})

test_that("update_quarto_ife() updates an older installed version", {
  dir <- withr::local_tempdir()
  fake_quarto_ife(dir, "0.1.0")
  local_mocked_bindings(
    quarto_ife_remote_tags = function() c("v0.1.0", "v0.2.0"),
    quarto_ife_install = function(path, version) fake_quarto_ife(path, version)
  )

  expect_identical(update_quarto_ife(dir, quiet = TRUE), "0.2.0")
})

test_that("update_quarto_ife() does not reinstall the version already in place", {
  dir <- withr::local_tempdir()
  fake_quarto_ife(dir, "0.2.0")
  local_mocked_bindings(
    quarto_ife_remote_tags = function() c("v0.1.0", "v0.2.0"),
    quarto_ife_install = function(path, version) stop("must not be called")
  )

  expect_identical(update_quarto_ife(dir, quiet = TRUE), "0.2.0")
})

test_that("update_quarto_ife(only_if_absent = TRUE) leaves an installed extension untouched", {
  dir <- withr::local_tempdir()
  fake_quarto_ife(dir, "0.1.0")
  local_mocked_bindings(
    quarto_ife_remote_tags = function() stop("must not be called"),
    quarto_ife_install = function(path, version) stop("must not be called")
  )

  expect_identical(update_quarto_ife(dir, only_if_absent = TRUE, quiet = TRUE), "0.1.0")
})

test_that("update_quarto_ife(only_if_absent = TRUE) installs a missing extension", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    quarto_ife_remote_tags = function() "v0.2.0",
    quarto_ife_install = function(path, version) fake_quarto_ife(path, version)
  )

  expect_identical(update_quarto_ife(dir, only_if_absent = TRUE, quiet = TRUE), "0.2.0")
})

test_that("update_quarto_ife() warns and keeps the installed version when tags cannot be read", {
  dir <- withr::local_tempdir()
  fake_quarto_ife(dir, "0.1.0")
  local_mocked_bindings(
    quarto_ife_remote_tags = function() stop("Could not resolve host: github.com"),
    quarto_ife_install = function(path, version) stop("must not be called")
  )

  expect_message(res <- update_quarto_ife(dir), "0\\.1\\.0")
  expect_identical(res, "0.1.0")
})

test_that("update_quarto_ife() warns and keeps the installed version when installation fails", {
  dir <- withr::local_tempdir()
  fake_quarto_ife(dir, "0.1.0")
  local_mocked_bindings(
    quarto_ife_remote_tags = function() "v0.2.0",
    quarto_ife_install = function(path, version) stop("quarto not found")
  )

  expect_message(res <- update_quarto_ife(dir), "0\\.1\\.0")
  expect_identical(res, "0.1.0")
})

test_that("update_quarto_ife() warns when installation does not leave the expected version", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    quarto_ife_remote_tags = function() "v0.2.0",
    quarto_ife_install = function(path, version) invisible(NULL)
  )

  expect_message(res <- update_quarto_ife(dir), "aucune")
  expect_null(res)
})
