# Manifeste collectif du blog (#4139). Les tests construisent un faux blog
# dans un dossier temporaire : `_quarto.yml` et quelques posts, sans Quarto.

# Un post = un dossier `posts/{folder}` et un ou deux fichiers `.qmd`.
# `yaml` : lignes d'en-tête de la version française ; `yaml_en` : lignes de la
# traduction, ou NULL.
blog_post <- function(folder, file, yaml, yaml_en = NULL, draft = FALSE,
                      gow = FALSE, ecograph = FALSE) {
  list(folder = folder, file = file, yaml = yaml, yaml_en = yaml_en,
       draft = draft, gow = gow, ecograph = ecograph)
}

# Écrit le faux blog et rend le tibble `posts` attendu par blog_manifest(),
# avec les colonnes de posts_db() qu'il utilise.
local_blog <- function(posts, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  write_quarto_yml(dir, list(website = list(
    `site-url` = "https://www.ofce.fr/", `site-path` = "blog2024/"
  )))
  fs::dir_create(fs::path(dir, "posts"))
  writeLines("categories: []", fs::path(dir, "posts", "_metadata.yml"))
  rows <- lapply(posts, function(p) {
    pdir <- fs::path(dir, "posts", p$folder)
    fs::dir_create(pdir, recurse = TRUE)
    write_qmd(pdir, paste0(p$file, ".qmd"), yaml_lines = p$yaml)
    translated <- !is.null(p$yaml_en)
    if (translated) write_qmd(pdir, paste0(p$file, ".en.qmd"), yaml_lines = p$yaml_en)
    tibble::tibble(
      file_fr = paste0(p$folder, "/", p$file, ".qmd"),
      file_en = if (translated) paste0(p$folder, "/", p$file, ".en.qmd") else NA_character_,
      translated = translated,
      draft = p$draft,
      gow = p$gow,
      ecograph = p$ecograph
    )
  })
  list(root = dir, posts = do.call(rbind, rows))
}

entry <- function(res, id) {
  hit <- Filter(function(e) identical(e$id, id), res$manifest)
  if (length(hit) == 1L) hit[[1]] else NULL
}

ids <- function(res) vapply(res$manifest, function(e) e$id, character(1))

billet <- blog_post(
  "2026/20261117_GAMB", "Billet_IFE",
  yaml = c("title: Fiscalité foncière", "date: 2026-11-17",
           "author:", "  - name: Guillaume Allégre", "  - name: Montserrat Botey",
           "categories: [\"France\", \"Fiscalité\"]",
           "description: Un dossier sur la fiscalité foncière.",
           "image: fig-patri"),
  yaml_en = c("title: Taxing land", "date: 2026-11-17", "lang: fr",
              "author:", "  - name: Guillaume Allégre",
              "categories: [\"Taxation\"]",
              "description: A special issue.", "image: fig-patri")
)

ecographe <- blog_post(
  "2026/20261124_DG_eg", "20261124_DG_eg",
  yaml = c("title: Mer en surchauffe", "date: 2026-11-24",
           "author:", "  - name: Diane Giroud",
           "categories: [\"Environnement\", \"Changement climatique\", \"EcoGraph\"]",
           "description: Le changement climatique.", "nb: 9", "ecograph: true",
           "image: fig-ecograph.png"),
  ecograph = TRUE
)

gow <- blog_post(
  "2026/20260724_AS_gow", "20260724_AS_gow",
  yaml = c("title: Coup de chaud", "date: 2026-07-24",
           "author:", "  - name: Anissa Saumtally",
           "categories: [\"Énergie\", \"Écographe\"]",
           "description: Prix de l'électricité.", "nb: 31", "gow: true",
           "image: image.png"),
  gow = TRUE
)

ancien <- blog_post(
  "2023/20230118_VT", "20230118_VT",
  yaml = c("title: La réforme des retraites", "date: \"2023-01-18\"",
           "author:", "  - name: Vincent Touzé",
           "categories: [\"Retraite\", \"Écographe\"]",
           "subtitle: Quelques éléments", "image: image.jpg")
)

test_that("le manifeste contient l'entrée du blog puis une entrée par fichier de post (S2)", {
  skip_if_not_installed("jsonvalidate")
  b <- local_blog(list(billet, ecographe, gow, ancien))
  res <- blog_manifest(b$posts, b$root)

  expect_equal(ids(res), c(
    "ofce-blog",
    "ofce-post-2026-20261117-gamb-fr", "ofce-post-2026-20261117-gamb-en",
    "ife-gow-2026-20261124-dg-eg-fr",
    "ofce-gow-2026-20260724-as-gow-fr",
    "ofce-post-2023-20230118-vt-fr"
  ))
  expect_true(res$validated)
  expect_equal(nrow(res$excluded), 0L)

  blog <- res$manifest[[1]]
  expect_equal(blog$title, "Le blog de l'OFCE")
  expect_equal(blog$type, "blog")
  expect_equal(blog$media, "site")
  expect_equal(blog$institution, "ofce")
  expect_equal(blog$lang, "fr")
  expect_null(blog$translation_id)
  expect_null(blog$parent)
  expect_equal(blog$url, "https://www.ofce.fr/blog2024/")
  expect_equal(blog$date_published, "2023-01-18")
  expect_equal(blog$authors, list())

  json <- as.character(jsonlite::toJSON(res$manifest, auto_unbox = TRUE, null = "null", digits = NA))
  expect_true(manifest_validate_text(json)$valid)
})

test_that("un billet traduit donne deux entrées liées (S3)", {
  skip_if_not_installed("jsonvalidate")
  b <- local_blog(list(billet))
  res <- blog_manifest(b$posts, b$root)

  fr <- entry(res, "ofce-post-2026-20261117-gamb-fr")
  en <- entry(res, "ofce-post-2026-20261117-gamb-en")
  expect_equal(fr$translation_id, "ofce-post-2026-20261117-gamb")
  expect_equal(en$translation_id, "ofce-post-2026-20261117-gamb")
  expect_equal(fr$lang, "fr")
  # La langue vient du nom du fichier, même si l'en-tête dit `lang: fr`.
  expect_equal(en$lang, "en")
  expect_equal(fr$url, "https://www.ofce.fr/blog2024/fr/2026/20261117_GAMB/")
  expect_equal(en$url, "https://www.ofce.fr/blog2024/en/2026/20261117_GAMB/")
  expect_equal(fr$pdf, "https://www.ofce.fr/blog2024/fr/2026/20261117_GAMB/Billet_IFE.fr.pdf")
  expect_equal(en$pdf, "https://www.ofce.fr/blog2024/en/2026/20261117_GAMB/Billet_IFE.en.pdf")
  expect_equal(fr$image, "https://www.ofce.fr/blog2024/fr/2026/20261117_GAMB/fig-patri.png")
  expect_equal(fr$institution, "ofce")
  expect_equal(fr$type, "post")
  expect_equal(fr$media, "html")
  expect_equal(fr$parent, "ofce-blog")
  expect_equal(fr$authors, list("Guillaume Allégre", "Montserrat Botey"))
  expect_equal(fr$categories, list("France", "Fiscalité"))
  expect_equal(en$categories, list("Taxation"))
  expect_equal(fr$abstract, "Un dossier sur la fiscalité foncière.")
  expect_equal(fr$keywords, list())
  expect_equal(fr$jel, list())
  expect_equal(fr$date_published, "2026-11-17")
  expect_true(fr$auto_update)
  expect_null(fr$nb)
})

test_that("un Écographe est un gow de l'IFE, sans libellé de série (S4)", {
  skip_if_not_installed("jsonvalidate")
  b <- local_blog(list(ecographe))
  res <- blog_manifest(b$posts, b$root)

  e <- entry(res, "ife-gow-2026-20261124-dg-eg-fr")
  expect_equal(e$institution, "ife")
  expect_equal(e$type, "gow")
  expect_equal(e$categories, list("Environnement", "Changement climatique"))
  expect_equal(e$nb, 9L)
  expect_null(e$translation_id)
  expect_equal(e$image, "https://www.ofce.fr/blog2024/fr/2026/20261124_DG_eg/fig-ecograph.png")
  expect_equal(e$pdf, "https://www.ofce.fr/blog2024/fr/2026/20261124_DG_eg/20261124_DG_eg.fr.pdf")
})

test_that("un GoW reste à l'OFCE ; un billet garde la catégorie Écographe (S5)", {
  skip_if_not_installed("jsonvalidate")
  b <- local_blog(list(gow, ancien))
  res <- blog_manifest(b$posts, b$root)

  g <- entry(res, "ofce-gow-2026-20260724-as-gow-fr")
  expect_equal(g$institution, "ofce")
  expect_equal(g$type, "gow")
  expect_equal(g$categories, list("Énergie"))
  expect_equal(g$nb, 31L)

  p <- entry(res, "ofce-post-2023-20230118-vt-fr")
  expect_equal(p$categories, list("Retraite", "Écographe"))
  expect_equal(p$subtitle, "Quelques éléments")
})

test_that("cas limites des en-têtes", {
  skip_if_not_installed("jsonvalidate")
  brouillon <- blog_post("2026/20260101_BR", "20260101_BR",
                         yaml = c("title: Brouillon", "date: 2026-01-01", "author: X", "categories: []"),
                         draft = TRUE)
  minimal <- blog_post("2026/20260102_MI", "20260102_MI",
                       yaml = c("title: Minimal", "date: 2026-01-02", "author: Jean Dupont",
                                "categories: [\"France\"]"))
  deux <- blog_post("2026/20260103_DD", "20260103_DD",
                    yaml = c("title: Deux drapeaux", "date: 2026-01-03", "author: X",
                             "categories: [\"Écographe\"]", "gow: true", "ecograph: true"),
                    gow = TRUE, ecograph = TRUE)
  b <- local_blog(list(brouillon, minimal, deux))
  res <- blog_manifest(b$posts, b$root)

  expect_false("ofce-post-2026-20260101-br-fr" %in% ids(res))

  m <- entry(res, "ofce-post-2026-20260102-mi-fr")
  expect_null(m$abstract)
  expect_null(m$subtitle)
  expect_null(m$image)
  expect_equal(m$authors, list("Jean Dupont"))

  d <- entry(res, "ife-gow-2026-20260103-dd-fr")
  expect_equal(d$institution, "ife")
  expect_equal(d$categories, list())

  # Un seul élément reste un tableau JSON une fois écrit.
  path <- fs::path(b$root, "_site", "manifest.json")
  fs::dir_create(fs::path_dir(path))
  suppressMessages(write_blog_manifest(b$posts, b$root))
  txt <- paste(readLines(path, encoding = "UTF-8"), collapse = "\n")
  expect_match(txt, '"authors": \\[\\s*"Jean Dupont"\\s*\\]')
  expect_match(txt, '"categories": \\[\\s*"France"\\s*\\]')
  expect_match(txt, '"translation_id": null')
})

test_that("une entrée invalide est écartée et signalée, le manifeste reste valide (S8)", {
  skip_if_not_installed("jsonvalidate")
  sans_titre <- blog_post("2026/20260105_ST", "20260105_ST",
                          yaml = c("date: 2026-01-05", "author: X", "categories: []"))
  mauvais_id <- blog_post("2026/a__b", "a__b",
                          yaml = c("title: Mauvais id", "date: 2026-01-06", "author: X", "categories: []"))
  b <- local_blog(list(billet, sans_titre, mauvais_id))
  fs::dir_create(fs::path(b$root, "_site"))

  expect_warning(
    res <- suppressMessages(write_blog_manifest(b$posts, b$root)),
    "20260105_ST"
  )
  expect_false("ofce-post-2026-20260105-st-fr" %in% ids(res))
  expect_false(any(grepl("a--b", ids(res))))
  expect_setequal(res$excluded$file, c("2026/20260105_ST/20260105_ST.qmd", "2026/a__b/a__b.qmd"))
  expect_true(all(nzchar(res$excluded$message)))
  expect_true("title" %in% res$excluded$field)

  expect_true(validate_manifest(fs::path(b$root, "_site", "manifest.json"))$valid)
})

test_that("deux posts au même id : le second est écarté", {
  skip_if_not_installed("jsonvalidate")
  # `_` devient `-` : les deux dossiers donnent le même id.
  a <- blog_post("2026/20260107_x", "x",
                 yaml = c("title: Premier", "date: 2026-01-07", "author: X", "categories: []"))
  b2 <- blog_post("2026/20260107-x", "y",
                  yaml = c("title: Second", "date: 2026-01-07", "author: X", "categories: []"))
  b <- local_blog(list(a, b2))
  res <- blog_manifest(b$posts, b$root)

  expect_equal(sum(ids(res) == "ofce-post-2026-20260107-x-fr"), 1L)
  expect_equal(entry(res, "ofce-post-2026-20260107-x-fr")$title, "Premier")
  expect_equal(res$excluded$file, "2026/20260107-x/y.qmd")
  expect_equal(res$excluded$field, "id")
})

test_that("sans jsonvalidate, le manifeste est écrit sans contrôle, avec un avertissement (D11)", {
  sans_titre <- blog_post("2026/20260105_ST", "20260105_ST",
                          yaml = c("date: 2026-01-05", "author: X", "categories: []"))
  b <- local_blog(list(billet, sans_titre))
  fs::dir_create(fs::path(b$root, "_site"))
  local_mocked_bindings(blog_manifest_can_validate = function() FALSE)

  expect_warning(
    res <- suppressMessages(write_blog_manifest(b$posts, b$root)),
    "sans contrôle"
  )
  expect_false(res$validated)
  written <- jsonlite::read_json(fs::path(b$root, "_site", "manifest.json"))
  expect_true("ofce-post-2026-20260105-st-fr" %in% vapply(written, function(e) e$id, character(1)))
})

test_that("une erreur inattendue n'arrête pas le rendu et n'écrit pas de manifeste", {
  b <- local_blog(list(billet))
  fs::dir_create(fs::path(b$root, "_site"))
  local_mocked_bindings(blog_manifest = function(...) stop("panne"))

  expect_warning(
    res <- suppressMessages(write_blog_manifest(b$posts, b$root)),
    "non écrit"
  )
  expect_null(res)
  expect_false(fs::file_exists(fs::path(b$root, "_site", "manifest.json")))
})

test_that("un post ajouté apparaît, un post supprimé disparaît (S6, S7)", {
  skip_if_not_installed("jsonvalidate")
  b <- local_blog(list(billet, gow))
  avant <- ids(blog_manifest(b$posts[1, ], b$root))
  apres <- ids(blog_manifest(b$posts, b$root))
  expect_false("ofce-gow-2026-20260724-as-gow-fr" %in% avant)
  expect_true("ofce-gow-2026-20260724-as-gow-fr" %in% apres)
  expect_false("ofce-gow-2026-20260724-as-gow-fr" %in% ids(blog_manifest(b$posts[1, ], b$root)))
})

test_that("post_image_name() complète un nom fig-{label}", {
  expect_equal(post_image_name("fig-patri"), "fig-patri.png")
  expect_equal(post_image_name("fig-patri.png"), "fig-patri.png")
  expect_equal(post_image_name("image.jpg"), "image.jpg")
  expect_null(post_image_name(NULL))
})

test_that("le PDF d'un fichier x.fr.qmd est celui que le rendu publie", {
  expect_equal(post_pdf_name("2024/20240404_CBFS/20240404_CBFS.fr.qmd", "fr"), "20240404_CBFS.fr.fr.pdf")
  expect_equal(post_pdf_name("2024/20240404_CBFS/20240404_CBFS.en.qmd", "en"), "20240404_CBFS.en.pdf")
  expect_equal(post_pdf_name("2026/20261117_GAMB/Billet_IFE.qmd", "fr"), "Billet_IFE.fr.pdf")

  skip_if_not_installed("jsonvalidate")
  cbfs <- blog_post(
    "2024/20240404_CBFS", "20240404_CBFS.fr",
    yaml = c("title: Un billet", "date: 2024-04-04", "author: X", "categories: []"),
    yaml_en = c("title: A post", "date: 2024-04-04", "author: X", "categories: []")
  )
  b <- local_blog(list(cbfs))
  # local_blog() nomme la traduction `{file}.en.qmd` : on la renomme comme
  # dans le blog réel (`20240404_CBFS.en.qmd`).
  pdir <- fs::path(b$root, "posts", "2024/20240404_CBFS")
  fs::file_move(fs::path(pdir, "20240404_CBFS.fr.en.qmd"), fs::path(pdir, "20240404_CBFS.en.qmd"))
  b$posts$file_en <- "2024/20240404_CBFS/20240404_CBFS.en.qmd"
  res <- blog_manifest(b$posts, b$root)

  expect_equal(
    entry(res, "ofce-post-2024-20240404-cbfs-fr")$pdf,
    "https://www.ofce.fr/blog2024/fr/2024/20240404_CBFS/20240404_CBFS.fr.fr.pdf"
  )
  expect_equal(
    entry(res, "ofce-post-2024-20240404-cbfs-en")$pdf,
    "https://www.ofce.fr/blog2024/en/2024/20240404_CBFS/20240404_CBFS.en.pdf"
  )
})
