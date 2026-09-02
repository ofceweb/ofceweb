test_that("resolve_stage_target() returns canonical values unchanged", {
  expect_equal(resolve_stage_target("gh-pages"), "gh-pages")
  expect_equal(resolve_stage_target("ftp"), "ftp")
})

test_that("resolve_stage_target() maps the legacy 'ofce' alias to 'ftp'", {
  expect_equal(resolve_stage_target("ofce"), "ftp")
  expect_equal(resolve_stage_target("ofce", org = "someoneelse"), "ftp")
})

test_that("resolve_stage_target() resolves 'auto' to 'ftp' for the ofce org (case-insensitive)", {
  expect_equal(resolve_stage_target("auto", org = "ofce"), "ftp")
  expect_equal(resolve_stage_target("auto", org = "OFCE"), "ftp")
})

test_that("resolve_stage_target() resolves 'auto' to 'gh-pages' for any other org or unknown org", {
  expect_equal(resolve_stage_target("auto", org = "someoneelse"), "gh-pages")
  expect_equal(resolve_stage_target("auto", org = NA_character_), "gh-pages")
  expect_equal(resolve_stage_target("auto"), "gh-pages")
})

test_that("resolve_stage_target() rejects unrecognized values", {
  expect_error(resolve_stage_target("bogus"))
})
