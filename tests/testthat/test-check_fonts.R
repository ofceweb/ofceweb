test_that("font_dir() cible le dossier Fonts de l'installation Windows", {
  skip_on_os(c("mac", "linux"))
  expect_identical(
    as.character(fs::path_norm(font_dir())),
    as.character(fs::path_norm(file.path(Sys.getenv("WINDIR"), "Fonts")))
  )
  expect_identical(as.character(fs::path_file(font_dir())), "Fonts")
})

test_that("is_windows_admin() est toujours TRUE hors Windows", {
  skip_on_os("windows")
  expect_identical(is_windows_admin(), TRUE)
})

test_that("is_windows_admin() renvoie un logique de longueur 1 sous Windows", {
  skip_on_os(c("mac", "linux"))
  out <- is_windows_admin()
  expect_type(out, "logical")
  expect_length(out, 1)
})
