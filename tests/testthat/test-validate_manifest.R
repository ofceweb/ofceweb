skip_if_not_installed("jsonvalidate")

exemples <- function(...) system.file("schema", "exemples", ..., package = "ofceweb")

minimal <- function() jsonlite::read_json(exemples("valides", "minimal.json"))

# Le manifeste minimal, modifié champ par champ ; NULL écrit `null`.
minimal_with <- function(...) {
  m <- minimal()
  ch <- list(...)
  for (k in names(ch)) m[k] <- list(ch[[k]])
  m
}

expect_valid <- function(x) {
  res <- validate_manifest(x)
  expect_true(res$valid, info = paste(res$errors$field, res$errors$message, collapse = "\n"))
  expect_equal(nrow(res$errors), 0L)
  invisible(res)
}

expect_error_on <- function(res, field, message) {
  hit <- (if (is.na(field)) is.na(res$errors$field) else res$errors$field %in% field) &
    grepl(message, res$errors$message, fixed = TRUE)
  expect_true(
    any(hit),
    info = paste0("attendu : [", field, "] ", message, "\nreçu :\n",
                  paste(res$errors$field, res$errors$message, collapse = "\n"))
  )
}

# --- Schéma et exemples valides (CA1, CA4, S1, S7) ----------------------------

test_that("le schéma se charge et porte une description pour chaque champ", {
  schema <- jsonlite::read_json(manifest_schema_path())
  expect_equal(schema[["$schema"]], "http://json-schema.org/draft-07/schema#")
  expect_match(schema[["$id"]], "^https://raw.githubusercontent.com/ofceweb/ofceweb/main/inst/schema/manifest-1.0.json$")
  for (nm in names(schema$properties)) {
    expect_true(nzchar(schema$properties[[nm]]$description %||% ""), info = nm)
  }
  expect_true(is.function(manifest_validator()))
})

test_that("chaque exemple valide est valide (S1)", {
  files <- list.files(exemples("valides"), full.names = TRUE)
  expect_gte(length(files), 5L)
  for (f in files) expect_valid(f)
})

test_that("le manifeste réel d'un WP, avec ses champs historiques, est valide (S1, S7)", {
  m <- jsonlite::read_json(exemples("valides", "wp-2025-23.json"))
  expect_true(all(c("wp", "annee", "version", "stage", "pdf-path", "source-repo", "ofceweb-version") %in% names(m)))
  expect_valid(exemples("valides", "wp-2025-23.json"))
})

test_that("un manifeste issu de wp_manifest() n'a pas d'erreur sur ses champs historiques (S7)", {
  m <- minimal_with(
    wp = 6L, annee = 2026L, version = "v1", stage = FALSE,
    `pdf-path` = "wp/2026/6/v1/OFCEWP2026-6.pdf", `source-repo` = "ofceweb/wp2026-6",
    `ofceweb-version` = "1.0.6", pb = 12L, pb_series = "ife"
  )
  expect_valid(m)
})

# --- Exemples invalides (CA3, CA4) -------------------------------------------

cas <- yaml::read_yaml(exemples("invalides.yml"))

test_that("invalides.yml et le dossier des exemples invalides se correspondent", {
  expect_setequal(names(cas), list.files(exemples("invalides")))
  for (nm in names(cas)) {
    expect_true(length(cas[[nm]]$errors) >= 1L, info = nm)
    expect_true(nzchar(cas[[nm]]$description %||% ""), info = nm)
  }
})

test_that("chaque exemple invalide est rejeté avec l'erreur attendue", {
  for (nm in names(cas)) {
    res <- validate_manifest(exemples("invalides", nm))
    expect_false(res$valid, info = nm)
    for (e in cas[[nm]]$errors) {
      expect_error_on(res, e$field %||% NA_character_, e$message)
      if (!is.null(e$entry)) {
        hit <- res$errors$entry %in% e$entry & res$errors$field %in% e$field
        expect_true(any(hit), info = paste(nm, "entrée", e$entry))
      }
    }
    expect_equal(nrow(res$errors), length(cas[[nm]]$errors), info = nm)
  }
})

# --- Scénarios ---------------------------------------------------------------

test_that("S2 : un champ obligatoire manquant est nommé", {
  m <- minimal(); m$jel <- NULL
  res <- validate_manifest(m)
  expect_false(res$valid)
  expect_equal(res$errors$field, "jel")
  expect_match(res$errors$message, "champ obligatoire manquant")
})

test_that("S3 : une valeur hors liste cite la valeur reçue et les valeurs admises", {
  res <- validate_manifest(minimal_with(lang = "de"))
  expect_equal(res$errors$field, "lang")
  expect_match(res$errors$message, '"de"', fixed = TRUE)
  expect_match(res$errors$message, "fr, en", fixed = TRUE)

  res <- validate_manifest(minimal_with(type = "article"))
  expect_equal(res$errors$field, "type")
  expect_match(res$errors$message, '"article"', fixed = TRUE)
  expect_match(res$errors$message, "working-paper", fixed = TRUE)
})

test_that("S4 : date_modified antérieure à date_published cite les deux champs et leurs valeurs", {
  res <- validate_manifest(minimal_with(date_published = "2026-06-15", date_modified = "2026-05-01"))
  expect_false(res$valid)
  expect_equal(res$errors$field, "date_modified")
  expect_match(res$errors$message, "date_modified vaut 2026-05-01", fixed = TRUE)
  expect_match(res$errors$message, "date_published vaut 2026-06-15", fixed = TRUE)

  expect_valid(minimal_with(date_published = "2026-06-15", date_modified = "2026-06-15"))
  expect_valid(minimal_with(date_modified = NULL))
})

test_that("S5 : l'id doit commencer par l'institution suivie d'un tiret", {
  res <- validate_manifest(minimal_with(institution = "cepii", id = "ofce-wp-2026-6-fr"))
  expect_equal(res$errors$field, "id")
  expect_match(res$errors$message, "cepii-", fixed = TRUE)
})

test_that("S6 : un champ réservé à l'agrégateur est rejeté", {
  for (k in c("author_ids", "children", "status", "manifest_url", "collected_at")) {
    m <- minimal(); m[[k]] <- "x"
    res <- validate_manifest(m)
    expect_false(res$valid, info = k)
    expect_error_on(res, k, "réservé à l'agrégateur")
  }
})

test_that("S8 : un brouillon dont l'id vaut null est invalide", {
  res <- validate_manifest(minimal_with(id = NULL))
  expect_false(res$valid)
  expect_error_on(res, "id", "brouillon")
  expect_true(is.na(res$errors$id))
})

test_that("S9 : toutes les erreurs sont rapportées ensemble", {
  m <- minimal_with(lang = "de", title = "", url = "http://x")
  res <- validate_manifest(m)
  expect_setequal(res$errors$field, c("lang", "title", "url"))
})

test_that("S10 : un manifeste collectif est contrôlé entrée par entrée", {
  expect_valid(exemples("valides", "blog-collectif.json"))

  coll <- jsonlite::read_json(exemples("valides", "blog-collectif.json"))
  coll[[2]]$lang <- "de"
  coll[[3]]$id <- NULL
  res <- validate_manifest(coll)
  expect_false(res$valid)
  expect_equal(res$errors$entry, c(2L, 3L))
  expect_equal(res$errors$id, c("ofce-post-2026-42-fr", NA))
  expect_equal(res$errors$field, c("lang", "id"))
})

test_that("S10 : un manifeste collectif vide est invalide", {
  res <- validate_manifest(list())
  expect_false(res$valid)
  expect_match(res$errors$message, "vide")
})

# --- Formes d'entrée et résultat (CA2) ---------------------------------------

test_that("le résultat a la forme attendue", {
  res <- validate_manifest(minimal_with(lang = "de"))
  expect_s3_class(res, "ofceweb_manifest_validation")
  expect_named(res$errors, c("entry", "id", "field", "message"))
  expect_type(res$errors$entry, "integer")
  expect_true(is.na(res$errors$entry))
  expect_equal(res$errors$id, "ofce-wp-2026-6-fr")
})

test_that("une URL est lue puis validée telle quelle", {
  txt <- paste(readLines(exemples("valides", "wp-2025-23.json"), encoding = "UTF-8"), collapse = "\n")
  local_mocked_bindings(manifest_read_url = function(url) txt)
  expect_valid("https://www.ofce.fr/wp/2025/23/v1/manifest.json")
})

test_that("une URL illisible rend un verdict invalide sans erreur R", {
  local_mocked_bindings(manifest_read_url = function(url) stop("HTTP 404 Not Found."))
  res <- expect_no_error(validate_manifest("https://www.ofce.fr/absent/manifest.json"))
  expect_false(res$valid)
  expect_match(res$errors$message, "lecture impossible")
  expect_true(is.na(res$errors$field))
})

test_that("un fichier introuvable ou illisible rend un verdict invalide sans erreur R", {
  res <- expect_no_error(validate_manifest(tempfile(fileext = ".json")))
  expect_false(res$valid)
  expect_match(res$errors$message, "introuvable")

  f <- withr::local_tempfile(fileext = ".json")
  writeLines("pas du json", f)
  res <- expect_no_error(validate_manifest(f))
  expect_false(res$valid)
  expect_match(res$errors$message, "JSON illisible")
})

test_that("une liste R conserve null et [] à l'écriture", {
  # Liste vide -> [] (valide) ; NULL -> null (valide pour translation_id)
  m <- minimal_with(categories = list(), translation_id = NULL)
  expect_valid(m)
  expect_match(manifest_to_json(m), '"categories":[]', fixed = TRUE)
  expect_match(manifest_to_json(m), '"translation_id":null', fixed = TRUE)
})

test_that("une entrée de manifeste collectif conserve null et [] à la réécriture", {
  txt <- '[{"a":null,"b":[],"c":["x"],"d":{},"e":1.5,"f":true}]'
  parsed <- jsonlite::parse_json(txt, simplifyVector = FALSE)
  expect_equal(manifest_to_json(parsed[[1]]), '{"a":null,"b":[],"c":["x"],"d":{},"e":1.5,"f":true}')
})

test_that("un argument d'une autre nature est refusé", {
  expect_error(validate_manifest(42), "chemin de fichier")
})

# --- Cas limites -------------------------------------------------------------

test_that("cas limites valides de la spécification", {
  # Listes obligatoires vides, translation_id null
  expect_valid(minimal_with(categories = list(), keywords = list(), jel = list(), translation_id = NULL))
  # department absent ou vide
  expect_valid(minimal())
  expect_valid(minimal_with(department = list()))
  # thème ou zone hors des listes fermées (D6)
  expect_valid(minimal_with(categories = list("thème inconnu"), region = "mars"))
  # id du blog sans segment de langue (D5)
  expect_valid(minimal_with(id = "ofce-blog", type = "blog", media = "site"))
  # codes JEL d'une lettre, ou une lettre et un chiffre
  expect_valid(minimal_with(jel = list("E", "E3", "E37")))
})

test_that("cas limites invalides de la spécification", {
  cases <- list(
    list(minimal_with(schema_version = "2.0"), "schema_version"),
    list(minimal_with(media = "pdf"), "pdf"),
    list(minimal_with(url = "/wp/2026/6/"), "url"),
    list(minimal_with(repo = "http://github.com/x"), "repo"),
    list(minimal_with(jel = list("e37")), "jel"),
    list(minimal_with(authors = list(list(name = "X", affiliation = "OFCE"))), "authors"),
    list(minimal_with(title = ""), "title"),
    list(minimal_with(department = list("DXX")), "department"),
    list(minimal_with(date_published = "15/06/2026"), "date_published")
  )
  for (cs in cases) {
    res <- validate_manifest(cs[[1]])
    expect_false(res$valid, info = cs[[2]])
    expect_equal(res$errors$field, cs[[2]], info = cs[[2]])
  }
})

test_that("chaque type d'erreur d'ajv a sa traduction française", {
  res <- validate_manifest(list(
    schema_version = "2.0", id = "ofce-x", institution = "ofce", type = "x",
    media = "pdf", pdf = NULL, lang = "fr", title = "", authors = list(1),
    categories = list(), keywords = list(), jel = list("e3"),
    date_published = "2026-1-1", date_modified = "x", url = "http://x",
    auto_update = "oui", status = "retired", parent = "A B"
  ))
  msg <- res$errors$message
  expect_false(any(grepl("must ", msg, fixed = TRUE)), info = paste(msg, collapse = "\n"))
  expect_true(all(c(
    "translation_id", "schema_version", "type", "pdf", "title", "authors", "jel",
    "date_published", "date_modified", "url", "auto_update", "status", "parent"
  ) %in% res$errors$field))
})

test_that("print affiche le verdict", {
  expect_message(print(validate_manifest(minimal())), "Manifeste valide")
  expect_message(print(validate_manifest(minimal_with(lang = "de"))), "1 erreur")
})

# Les valeurs viennent du manifeste : cli ne doit ni les évaluer ni planter
# sur leurs accolades.
print_output <- function(res) {
  out <- capture.output(print(res), type = "message")
  paste(cli::ansi_strip(out), collapse = " ")
}

test_that("print affiche des auteurs écrits en objets", {
  res <- validate_manifest(exemples("invalides", "authors-objets.json"))
  out <- expect_no_error(print_output(res))
  expect_match(out, '"name":"Xavier Timbeau"', fixed = TRUE)
})

test_that("print n'interprète pas une valeur contenant {x}", {
  x <- "VALEUR-EVALUEE"
  res <- validate_manifest(list(minimal_with(lang = "{x}", id = "ofce-{x}")))
  out <- expect_no_error(print_output(res))
  expect_match(out, 'valeur "{x}" non admise', fixed = TRUE)
  expect_match(out, "(ofce-{x})", fixed = TRUE)
  expect_no_match(out, "VALEUR-EVALUEE", fixed = TRUE)
})
