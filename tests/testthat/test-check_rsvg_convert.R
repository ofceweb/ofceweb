test_that("check_rsvg_convert() returns TRUE and stays quiet-friendly when found", {
  local_mocked_bindings(
    Sys.which = function(...) "/usr/bin/rsvg-convert",
    .package = "base"
  )
  expect_true(check_rsvg_convert(verbose = FALSE))
})

test_that("check_rsvg_convert() returns FALSE when the binary is absent", {
  local_mocked_bindings(
    Sys.which = function(...) "",
    .package = "base"
  )
  expect_false(check_rsvg_convert(verbose = FALSE))
})

test_that("check_rsvg_convert() warns with install instructions when verbose and absent", {
  local_mocked_bindings(
    Sys.which = function(...) "",
    .package = "base"
  )
  expect_message(check_rsvg_convert(verbose = TRUE), "rsvg-convert")
})
