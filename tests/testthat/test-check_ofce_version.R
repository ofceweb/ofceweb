# check_ofce_version() is the blocking counterpart of check_quarto_version():
# it stops setup_wp()/setup_pb()/setup_prev()/setup_site() (via cli::cli_abort())
# right before they call ofce::setup_quarto(), rather than merely warning.
# utils::packageVersion() is mocked below so these tests don't depend on
# whichever ofce version happens to be installed on the machine running them.

test_that("check_ofce_version() passes silently when the installed version meets the minimum", {
  local_mocked_bindings(
    packageVersion = function(pkg) package_version("1.3.39"),
    .package = "utils"
  )
  expect_true(check_ofce_version(min = "1.3.39"))
})

test_that("check_ofce_version() passes silently when the installed version exceeds the minimum", {
  local_mocked_bindings(
    packageVersion = function(pkg) package_version("1.4.0"),
    .package = "utils"
  )
  expect_true(check_ofce_version(min = "1.3.39"))
})

test_that("check_ofce_version() aborts when the installed version is below the minimum", {
  local_mocked_bindings(
    packageVersion = function(pkg) package_version("1.3.38"),
    .package = "utils"
  )
  expect_error(check_ofce_version(min = "1.3.39"), "insuffisante")
})

test_that("check_ofce_version() aborts when the ofce package is not installed", {
  local_mocked_bindings(
    packageVersion = function(pkg) stop("there is no package called 'ofce'"),
    .package = "utils"
  )
  expect_error(check_ofce_version(min = "1.3.39"), "n'est pas install")
})
