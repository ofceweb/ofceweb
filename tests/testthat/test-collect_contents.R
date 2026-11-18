skip_if_not_installed("jsonvalidate")

# --- Fabrique de journaux et de manifestes ---------------------------------

exemples <- function(...) system.file("schema", "exemples", ..., package = "ofceweb")

murl <- function(id, v = "v0") paste0("https://www.ofce.fr/test/", id, "/", v, "/manifest.json")

# Manifeste unitaire valide, à partir de l'exemple minimal.
manifest <- function(id = "ofce-wp-2026-6-fr", ...) {
  m <- jsonlite::read_json(exemples("valides", "minimal.json"))
  m$id <- id
  m$url <- paste0("https://www.ofce.fr/test/", id, "/")
  ch <- list(...)
  for (k in names(ch)) m[k] <- list(ch[[k]])
  m
}

post <- function(id, date, ...) {
  manifest(id, type = "post", parent = "ofce-blog", date_published = date, ...)
}

blog <- function(...) manifest("ofce-blog", type = "blog", media = "site", parent = NULL, date_published = "2020-01-01", ...)

declaration <- function(id, status = "published", url = murl(id)) {
  list(
    id = id, manifest_url = url, pdf_url = NULL,
    declared_at = "2026-11-18T10:00:00Z", declared_by = "leopedemay", status = status
  )
}

as_json <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA))

# Journal d'essai : `decls` est une liste de déclarations (listes R), ou de
# textes bruts nommés par leur chemin.
local_journal <- function(decls = list(), raw = list(), env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(root, "registry"))
  write <- function(path, text) {
    full <- file.path(root, path)
    dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
    writeLines(text, full, useBytes = TRUE)
  }
  for (d in decls) write(file.path("registry", "2026", paste0(d$id, ".json")), as_json(d))
  for (p in names(raw)) write(p, raw[[p]])
  root
}

# Remplace le site : `pages` associe une URL à une liste R (servie en JSON),
# à un texte brut, ou à une condition (levée). Une URL absente répond 404.
local_site <- function(pages, now = "2026-11-18T12:00:00Z", env = parent.frame()) {
  local_mocked_bindings(
    manifest_read_url = function(url) {
      p <- pages[[url]]
      if (is.null(p)) stop("HTTP 404 Not Found.")
      if (inherits(p, "condition")) stop(p)
      if (is.character(p)) p else as_json(p)
    },
    collect_now = function() now,
    .env = env
  )
}

ids_of <- function(res) vapply(res$contents, function(r) r$id, "")
rec <- function(res, id) res$contents[[match(id, ids_of(res))]]

expect_anomaly <- function(res, type, id = NULL, message = NULL) {
  a <- res$anomalies
  hit <- a$type == type &
    (if (is.null(id)) TRUE else a$id %in% id) &
    (if (is.null(message)) TRUE else grepl(message, a$message, fixed = TRUE))
  expect_true(
    any(hit),
    info = paste0("attendu : ", type, " ", id, " ", message, "\nreçu :\n",
                  paste(a$type, a$id, a$message, collapse = "\n"))
  )
}

aggregator_fields <- c("author_ids", "children", "status", "manifest_url", "collected_at")

wp_ids <- c("ofce-wp-2025-23-fr", "ofce-wp-2025-24-fr", "ofce-wp-2026-10-en", "ofce-wp-2026-12-fr", "ofce-wp-2026-6-fr")

# --- S1 Collecte du journal --------------------------------------------------

test_that("S1 : cinq WP déclarés donnent cinq enregistrements, sans anomalie", {
  root <- local_journal(lapply(wp_ids, declaration))
  pages <- stats::setNames(lapply(wp_ids, function(id) manifest(id, authors = list("Xavier Timbeau"))), vapply(wp_ids, murl, ""))
  local_site(pages)

  res <- expect_no_error(collect_contents(root))

  expect_s3_class(res, "ofceweb_contents_collection")
  expect_equal(ids_of(res), sort(wp_ids))
  expect_equal(nrow(res$anomalies), 0L)
  expect_equal(res$n_declarations, 5L)
  r <- rec(res, "ofce-wp-2026-6-fr")
  expect_equal(r$status, "published")
  expect_equal(r$manifest_url, murl("ofce-wp-2026-6-fr"))
  expect_equal(r$collected_at, "2026-11-18T12:00:00Z")
  expect_equal(r$author_ids, list(NULL))
  expect_equal(r$children, list())
  expect_equal(r$title, "Titre du document")
})

# --- S2, S3 Manifeste injoignable --------------------------------------------

test_that("S2 : un manifeste injoignable reprend l'enregistrement précédent (D10)", {
  id <- "ofce-wp-2026-6-fr"
  root <- local_journal(list(declaration(id, status = "retired", url = murl(id, "v1"))))
  local_site(list())
  old <- c(manifest(id), list(author_ids = list(), children = list(), status = "published",
                                manifest_url = murl(id, "v0"), collected_at = "2026-10-01T08:00:00Z"))

  res <- expect_no_error(collect_contents(root, previous = list(old)))

  r <- rec(res, id)
  expect_equal(r$collected_at, "2026-10-01T08:00:00Z")
  expect_equal(r$manifest_url, murl(id, "v0"))
  expect_equal(r$status, "retired")
  expect_anomaly(res, "manifest_unreachable", id, murl(id, "v1"))
  expect_anomaly(res, "manifest_unreachable", id, "404")
})

test_that("S3 : un manifeste injoignable sans base précédente est absent, les autres sont collectés", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr"), declaration("ofce-wp-2026-12-fr")))
  local_site(list(
    "https://www.ofce.fr/test/ofce-wp-2026-12-fr/v0/manifest.json" = manifest("ofce-wp-2026-12-fr"),
    "https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = simpleError("Timeout was reached")
  ))

  res <- expect_no_error(collect_contents(root))

  expect_equal(ids_of(res), "ofce-wp-2026-12-fr")
  expect_anomaly(res, "manifest_unreachable", "ofce-wp-2026-6-fr", "Timeout")
})

# --- S4 Manifeste invalide -----------------------------------------------------

test_that("S4 : un manifeste invalide ou non JSON est traité comme injoignable", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr"), declaration("ofce-wp-2026-12-fr")))
  local_site(list(
    "https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = manifest("ofce-wp-2026-6-fr", lang = "de"),
    "https://www.ofce.fr/test/ofce-wp-2026-12-fr/v0/manifest.json" = "<html>Not found</html>"
  ))
  old <- c(manifest("ofce-wp-2026-6-fr"), list(author_ids = list(), children = list(), status = "published",
                                               manifest_url = murl("ofce-wp-2026-6-fr"), collected_at = "2026-10-01T08:00:00Z"))

  res <- expect_no_error(collect_contents(root, previous = list(old)))

  expect_equal(ids_of(res), "ofce-wp-2026-6-fr")
  expect_equal(rec(res, "ofce-wp-2026-6-fr")$collected_at, "2026-10-01T08:00:00Z")
  expect_anomaly(res, "manifest_invalid", "ofce-wp-2026-6-fr", "lang")
  expect_anomaly(res, "manifest_invalid", "ofce-wp-2026-12-fr", "JSON illisible")
})

# --- S5 Déclaration refusée --------------------------------------------------

test_that("S5 : une déclaration refusée par check_registry() est ignorée", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr", status = "publie"), declaration("ofce-wp-2026-12-fr")))
  local_site(list(
    "https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = manifest("ofce-wp-2026-6-fr"),
    "https://www.ofce.fr/test/ofce-wp-2026-12-fr/v0/manifest.json" = manifest("ofce-wp-2026-12-fr")
  ))

  res <- expect_no_error(collect_contents(root))

  expect_equal(ids_of(res), "ofce-wp-2026-12-fr")
  expect_anomaly(res, "declaration_invalid", "ofce-wp-2026-6-fr", "status")
  expect_equal(res$anomalies$file[res$anomalies$type == "declaration_invalid"][1], "registry/2026/ofce-wp-2026-6-fr.json")
})

test_that("S5 : un id déclaré dans deux fichiers est ignoré dans les deux", {
  d <- declaration("ofce-wp-2026-6-fr")
  root <- local_journal(raw = list(
    "registry/2025/ofce-wp-2026-6-fr.json" = as_json(d),
    "registry/2026/ofce-wp-2026-6-fr.json" = as_json(d)
  ))
  local_site(list("https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = manifest("ofce-wp-2026-6-fr")))

  res <- collect_contents(root)

  expect_equal(length(res$contents), 0L)
  expect_anomaly(res, "declaration_invalid", "ofce-wp-2026-6-fr", "plusieurs fichiers")
})

# --- S6 Contenu retiré -----------------------------------------------------------

test_that("S6 : une déclaration retired dont le manifeste répond est collectée", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr", status = "retired")))
  local_site(list("https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = manifest("ofce-wp-2026-6-fr")))

  res <- collect_contents(root)

  expect_equal(rec(res, "ofce-wp-2026-6-fr")$status, "retired")
  expect_equal(nrow(res$anomalies), 0L)
})

# --- S7 à S9 Blog ------------------------------------------------------------------

blog_url <- murl("ofce-blog")

test_that("S7 : le manifeste collectif du blog donne un enregistrement par entrée", {
  root <- local_journal(list(declaration("ofce-blog")))
  local_site(stats::setNames(list(list(
    blog(),
    post("ofce-post-2026-2-fr", "2026-06-01"),
    post("ofce-post-2026-1-fr", "2026-05-01")
  )), blog_url))

  res <- collect_contents(root)

  expect_equal(ids_of(res), c("ofce-blog", "ofce-post-2026-1-fr", "ofce-post-2026-2-fr"))
  expect_equal(rec(res, "ofce-blog")$children, list("ofce-post-2026-1-fr", "ofce-post-2026-2-fr"))
  p <- rec(res, "ofce-post-2026-1-fr")
  expect_equal(p$status, "published")
  expect_equal(p$manifest_url, blog_url)
  expect_equal(p$children, list())
  expect_equal(nrow(res$anomalies), 0L)
})

test_that("S7 : children départage une même date par l'id", {
  root <- local_journal(list(declaration("ofce-blog")))
  local_site(stats::setNames(list(list(
    blog(), post("ofce-post-2026-b-fr", "2026-05-01"), post("ofce-post-2026-a-fr", "2026-05-01")
  )), blog_url))

  expect_equal(rec(collect_contents(root), "ofce-blog")$children, list("ofce-post-2026-a-fr", "ofce-post-2026-b-fr"))
})

previous_blog <- function() {
  wrap <- function(m) c(m, list(author_ids = list(), children = list(), status = "published",
                                manifest_url = blog_url, collected_at = "2026-10-01T08:00:00Z"))
  list(
    wrap(blog()),
    wrap(post("ofce-post-2026-1-fr", "2026-05-01")),
    wrap(post("ofce-post-2026-2-fr", "2026-05-02")),
    wrap(post("ofce-post-2026-3-fr", "2026-05-03"))
  )
}

test_that("S8 : un post absent du nouveau manifeste disparaît de la base", {
  root <- local_journal(list(declaration("ofce-blog")))
  local_site(stats::setNames(list(list(
    blog(), post("ofce-post-2026-1-fr", "2026-05-01"), post("ofce-post-2026-2-fr", "2026-05-02")
  )), blog_url))

  res <- collect_contents(root, previous = previous_blog())

  expect_equal(ids_of(res), c("ofce-blog", "ofce-post-2026-1-fr", "ofce-post-2026-2-fr"))
  expect_equal(rec(res, "ofce-post-2026-1-fr")$collected_at, "2026-11-18T12:00:00Z")
})

test_that("S9 : un blog injoignable reprend tous ses enregistrements", {
  root <- local_journal(list(declaration("ofce-blog")))
  local_site(list())

  res <- collect_contents(root, previous = previous_blog())

  expect_equal(length(res$contents), 4L)
  expect_true(all(vapply(res$contents, function(r) r$collected_at, "") == "2026-10-01T08:00:00Z"))
  expect_equal(rec(res, "ofce-blog")$children, list("ofce-post-2026-1-fr", "ofce-post-2026-2-fr", "ofce-post-2026-3-fr"))
  expect_anomaly(res, "manifest_unreachable", "ofce-blog")
})

test_that("S9, D11 : un seul post invalide rend tout le blog invalide", {
  root <- local_journal(list(declaration("ofce-blog")))
  local_site(stats::setNames(list(list(
    blog(), post("ofce-post-2026-1-fr", "2026-05-01"), post("ofce-post-2026-9-fr", "2026-05-09", lang = "de")
  )), blog_url))

  res <- collect_contents(root, previous = previous_blog())

  expect_equal(length(res$contents), 4L)
  expect_false("ofce-post-2026-9-fr" %in% ids_of(res))
  expect_anomaly(res, "manifest_invalid", "ofce-blog", "ofce-post-2026-9-fr")
})

test_that("cas limite : le statut de la déclaration du blog s'applique aux posts repris (D10)", {
  root <- local_journal(list(declaration("ofce-blog", status = "retired")))
  local_site(list())

  res <- collect_contents(root, previous = previous_blog())

  expect_true(all(vapply(res$contents, function(r) r$status, "") == "retired"))
})

# --- S10 Identifiant incohérent ----------------------------------------------------

test_that("S10 : un manifeste dont l'id diffère de la déclaration est invalide", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr")))
  local_site(list("https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = manifest("ofce-wp-2026-7-fr")))

  res <- collect_contents(root)

  expect_equal(length(res$contents), 0L)
  expect_anomaly(res, "id_mismatch", "ofce-wp-2026-6-fr", "ofce-wp-2026-7-fr")
})

test_that("S10 : un manifeste collectif sans entrée de l'id déclaré est incohérent", {
  root <- local_journal(list(declaration("ofce-blog")))
  local_site(stats::setNames(list(list(post("ofce-post-2026-1-fr", "2026-05-01"))), blog_url))

  res <- collect_contents(root)

  expect_equal(length(res$contents), 0L)
  expect_anomaly(res, "id_mismatch", "ofce-blog")
})

test_that("cas limite : la forme du manifeste est acceptée telle quelle", {
  root <- local_journal(list(declaration("ofce-blog"), declaration("ofce-wp-2026-6-fr")))
  local_site(list(
    "https://www.ofce.fr/test/ofce-blog/v0/manifest.json" = blog(),
    "https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = list(manifest("ofce-wp-2026-6-fr"))
  ))

  res <- collect_contents(root)

  expect_equal(ids_of(res), c("ofce-blog", "ofce-wp-2026-6-fr"))
  expect_equal(nrow(res$anomalies), 0L)
})

# --- S11 Doublons --------------------------------------------------------------------

test_that("S11 : un post qui a l'id d'un contenu déclaré est écarté", {
  root <- local_journal(list(declaration("ofce-blog"), declaration("ofce-wp-2026-6-fr")))
  local_site(list(
    "https://www.ofce.fr/test/ofce-blog/v0/manifest.json" = list(blog(), post("ofce-wp-2026-6-fr", "2026-05-01", title = "Post")),
    "https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = manifest("ofce-wp-2026-6-fr", title = "WP")
  ))

  res <- collect_contents(root)

  expect_equal(rec(res, "ofce-wp-2026-6-fr")$title, "WP")
  expect_equal(rec(res, "ofce-blog")$children, list())
  expect_anomaly(res, "duplicate_id", "ofce-wp-2026-6-fr")
})

test_that("S11 : deux posts au même id, le premier est gardé", {
  root <- local_journal(list(declaration("ofce-blog")))
  local_site(stats::setNames(list(list(
    blog(), post("ofce-post-2026-1-fr", "2026-05-01", title = "Premier"), post("ofce-post-2026-1-fr", "2026-05-02", title = "Second")
  )), blog_url))

  res <- collect_contents(root)

  expect_equal(ids_of(res), c("ofce-blog", "ofce-post-2026-1-fr"))
  expect_equal(rec(res, "ofce-post-2026-1-fr")$title, "Premier")
  expect_anomaly(res, "duplicate_id", "ofce-post-2026-1-fr")
})

# --- S12 Parent non résolu -----------------------------------------------------------

test_that("S12 : un parent non résolu est gardé et signalé", {
  id <- "ofce-revue-2026-1-fr"
  root <- local_journal(list(declaration(id)))
  local_site(stats::setNames(list(manifest(id, parent = "ofce-revue-2026-194-fr")), murl(id)))

  res <- collect_contents(root)

  expect_equal(rec(res, id)$parent, "ofce-revue-2026-194-fr")
  expect_anomaly(res, "parent_unresolved", id, "ofce-revue-2026-194-fr")
})

# --- S13 Champs historiques, CA3 -------------------------------------------------------

test_that("S13, CA3 : un enregistrement ne garde que les champs v1 et ceux de l'agrégateur", {
  id <- "ofce-wp-2026-6-fr"
  root <- local_journal(list(declaration(id)))
  local_site(stats::setNames(list(manifest(id, stage = "published", `source-repo` = "ofce/wp", wp = 6, subtitle = "Sous-titre")), murl(id)))

  r <- rec(collect_contents(root), id)

  expect_false(any(c("stage", "source-repo", "wp") %in% names(r)))
  schema <- jsonlite::read_json(system.file("schema", "manifest-1.0.json", package = "ofceweb"))
  v1 <- setdiff(names(schema$properties), aggregator_fields)
  present <- names(manifest(id, subtitle = "Sous-titre"))
  expect_equal(names(r), c(v1[v1 %in% present], aggregator_fields))
})

# --- S14 Reproductibilité ----------------------------------------------------------------

test_that("S14 : deux collectes identiques ne diffèrent que par collected_at", {
  root <- local_journal(list(declaration("ofce-blog"), declaration("ofce-wp-2026-6-fr")))
  pages <- list(
    "https://www.ofce.fr/test/ofce-blog/v0/manifest.json" = list(blog(), post("ofce-post-2026-1-fr", "2026-05-01")),
    "https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = manifest("ofce-wp-2026-6-fr")
  )
  strip <- function(res) lapply(res$contents, function(r) r[names(r) != "collected_at"])

  local_site(pages, now = "2026-11-18T12:00:00Z")
  a <- collect_contents(root)
  local_site(pages, now = "2026-11-19T06:00:00Z")
  b <- collect_contents(root)

  expect_equal(strip(a), strip(b))
  expect_equal(rec(b, "ofce-blog")$collected_at, "2026-11-19T06:00:00Z")
})

# --- Cas limites -------------------------------------------------------------------------

test_that("cas limite : un journal vide donne une base vide", {
  root <- local_journal()
  local_site(list())

  res <- collect_contents(root)

  expect_equal(res$contents, list())
  expect_equal(nrow(res$anomalies), 0L)
  path <- withr::local_tempfile(fileext = ".json")
  write_contents(res, path)
  expect_equal(trimws(paste(readLines(path), collapse = "")), "[]")
})

test_that("cas limite : une base précédente illisible est signalée, absente est ignorée", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr")))
  local_site(stats::setNames(list(manifest("ofce-wp-2026-6-fr")), murl("ofce-wp-2026-6-fr")))
  bad <- withr::local_tempfile(fileext = ".json")
  writeLines("{ pas du json", bad)
  not_array <- withr::local_tempfile(fileext = ".json")
  writeLines('{"id": "x"}', not_array)

  res <- expect_no_error(collect_contents(root, previous = bad))
  expect_equal(ids_of(res), "ofce-wp-2026-6-fr")
  expect_anomaly(res, "previous_invalid")

  expect_anomaly(collect_contents(root, previous = not_array), "previous_invalid")

  res <- collect_contents(root, previous = file.path(tempdir(), "absente.json"))
  expect_equal(nrow(res$anomalies), 0L)
})

test_that("cas limite : un enregistrement précédent hors du journal n'est pas repris", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr")))
  local_site(stats::setNames(list(manifest("ofce-wp-2026-6-fr")), murl("ofce-wp-2026-6-fr")))
  old <- c(manifest("ofce-wp-2026-99-fr"), list(author_ids = list(), children = list(), status = "published",
                                                manifest_url = murl("ofce-wp-2026-99-fr"), collected_at = "2026-10-01T08:00:00Z"))

  expect_equal(ids_of(collect_contents(root, previous = list(old))), "ofce-wp-2026-6-fr")
})

test_that("cas limite : authors vide donne author_ids vide", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr")))
  local_site(stats::setNames(list(manifest("ofce-wp-2026-6-fr")), murl("ofce-wp-2026-6-fr")))

  expect_equal(rec(collect_contents(root), "ofce-wp-2026-6-fr")$author_ids, list())
})

# --- CA2 Écriture de contents.json ------------------------------------------------------

test_that("CA2 : write_contents() écrit un tableau trié par id, aux tableaux préservés", {
  root <- local_journal(list(declaration("ofce-blog"), declaration("ofce-wp-2026-6-fr")))
  local_site(list(
    "https://www.ofce.fr/test/ofce-blog/v0/manifest.json" = list(blog(), post("ofce-post-2026-1-fr", "2026-05-01")),
    "https://www.ofce.fr/test/ofce-wp-2026-6-fr/v0/manifest.json" = manifest("ofce-wp-2026-6-fr", authors = list("Xavier Timbeau"), jel = list("E37"))
  ))
  res <- collect_contents(root)
  path <- withr::local_tempfile(fileext = ".json")

  expect_equal(write_contents(res, path), path)

  text <- paste(readLines(path, encoding = "UTF-8"), collapse = "\n")
  back <- jsonlite::parse_json(text)
  ids <- vapply(back, function(r) r$id, "")
  expect_equal(ids, sort(ids, method = "radix"))
  expect_false(anyDuplicated(ids) > 0)
  expect_equal(back, res$contents)
  wp <- back[[match("ofce-wp-2026-6-fr", ids)]]
  expect_equal(wp$authors, list("Xavier Timbeau"))
  expect_equal(wp$author_ids, list(NULL))
  expect_equal(wp$jel, list("E37"))
  expect_match(text, '"author_ids": \\[\\s*null\\s*\\]')
  expect_match(text, '"translation_id": null')
  expect_equal(back[[match("ofce-blog", ids)]]$children, list("ofce-post-2026-1-fr"))
  expect_match(text, '"children": \\[\\s*"ofce-post-2026-1-fr"\\s*\\]')
  expect_equal(write_contents(res$contents, path), path)
})

# --- CA5 Forme des anomalies --------------------------------------------------------------

test_that("CA5 : chaque anomalie a un type connu, son fichier et un message", {
  root <- local_journal(list(declaration("ofce-wp-2026-6-fr", status = "publie"), declaration("ofce-wp-2026-12-fr")))
  local_site(list())

  res <- collect_contents(root)
  a <- res$anomalies

  expect_named(a, c("type", "id", "file", "message"))
  expect_true(all(a$type %in% c("declaration_invalid", "manifest_unreachable", "manifest_invalid", "id_mismatch",
                                "duplicate_id", "parent_unresolved", "previous_invalid")))
  expect_false(any(is.na(a$file)))
  expect_true(all(nzchar(a$message)))
  msgs <- capture_messages(print(res))
  expect_match(msgs[1], "2 anomalies")
  expect_length(msgs, 3L)
})
