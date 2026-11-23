skip_if_not_installed("jsonvalidate")

exemples_decl <- function(...) system.file("schema", "exemples-declaration", ..., package = "ofceweb")

declaration <- function(id = "ofce-wp-2026-6-fr", ...) {
  d <- list(
    id = id,
    manifest_url = "https://www.ofce.fr/wp/2026/6/v0/manifest.json",
    pdf_url = "https://www.ofce.fr/wp/2026/6/v0/OFCEWP2026-6.pdf",
    declared_at = "2026-06-15T14:32:00Z",
    declared_by = "xtimbeau",
    status = "published"
  )
  ch <- list(...)
  for (k in names(ch)) d[k] <- list(ch[[k]])
  d
}

# Crée un dépôt d'essai : `files` est une liste nommée chemin -> contenu
# (liste R écrite en JSON, ou texte brut).
local_registry <- function(files, env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  for (path in names(files)) {
    full <- file.path(root, path)
    dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
    content <- files[[path]]
    if (is.list(content)) content <- jsonlite::toJSON(content, auto_unbox = TRUE, null = "null", pretty = TRUE)
    writeLines(content, full, useBytes = TRUE)
  }
  root
}

expect_registry_error <- function(res, file, field, message) {
  e <- res$errors
  hit <- grepl(file, e$file, fixed = TRUE) &
    (if (is.na(field)) is.na(e$field) else e$field %in% field) &
    grepl(message, e$message, fixed = TRUE)
  expect_true(
    any(hit),
    info = paste0("attendu : ", file, " [", field, "] ", message, "\nreçu :\n",
                  paste(e$file, e$field, e$message, collapse = "\n"))
  )
}

expect_registry_valid <- function(res) {
  expect_true(res$valid, info = paste(res$errors$file, res$errors$field, res$errors$message, collapse = "\n"))
}

# --- Schéma et exemples (CA2) ------------------------------------------------

test_that("le schéma se charge et porte une description pour chaque champ", {
  schema <- jsonlite::read_json(manifest_schema_path("declaration-1.0.json"))
  expect_equal(schema[["$schema"]], "http://json-schema.org/draft-07/schema#")
  expect_match(schema[["$id"]], "^https://raw.githubusercontent.com/ofceweb/ofceweb/main/inst/schema/declaration-1.0.json$")
  expect_false(schema$additionalProperties)
  expect_setequal(unlist(schema$required), c("id", "manifest_url", "pdf_url", "declared_at", "declared_by", "status"))
  for (nm in names(schema$properties)) {
    expect_true(nzchar(schema$properties[[nm]]$description %||% ""), info = nm)
  }
})

test_that("chaque exemple valide est accepté", {
  files <- list.files(exemples_decl("valides"), full.names = TRUE)
  expect_gte(length(files), 3L)
  for (f in files) {
    rows <- declaration_check_text(paste(readLines(f, encoding = "UTF-8"), collapse = "\n"))
    expect_equal(nrow(rows), 0L, info = paste(basename(f), rows$field, rows$message))
  }
})

cas_decl <- yaml::read_yaml(exemples_decl("invalides.yml"))

test_that("invalides.yml et le dossier des exemples invalides se correspondent", {
  expect_setequal(names(cas_decl), list.files(exemples_decl("invalides")))
  for (nm in names(cas_decl)) {
    expect_true(length(cas_decl[[nm]]$errors) >= 1L, info = nm)
    expect_true(nzchar(cas_decl[[nm]]$description %||% ""), info = nm)
  }
})

test_that("chaque exemple invalide est rejeté avec l'erreur attendue", {
  for (nm in names(cas_decl)) {
    text <- paste(readLines(exemples_decl("invalides", nm), encoding = "UTF-8", warn = FALSE), collapse = "\n")
    rows <- declaration_check_text(text)
    expect_gt(nrow(rows), 0L, label = nm)
    for (err in cas_decl[[nm]]$errors) {
      field <- err$field %||% NA_character_
      hit <- (if (is.na(field)) is.na(rows$field) else rows$field %in% field) &
        grepl(err$message, rows$message, fixed = TRUE)
      expect_true(any(hit), info = paste0(nm, " : attendu [", field, "] ", err$message,
                                          "\nreçu :\n", paste(rows$field, rows$message, collapse = "\n")))
    }
  }
})

test_that("pdf_url: null est valide", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration(pdf_url = NULL)))
  expect_registry_valid(check_registry(root))
})

# --- Journal (CA3) -----------------------------------------------------------

test_that("S1 : une déclaration conforme et bien rangée passe", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration()))
  res <- check_registry(root)
  expect_registry_valid(res)
  expect_equal(res$n_declarations, 1L)
})

test_that("S3, S4 : published et retired passent", {
  root <- local_registry(list(
    "registry/2026/ofce-wp-2026-6-fr.json" = declaration(status = "retired"),
    "registry/2025/ofce-wp-2025-23-fr.json" = declaration("ofce-wp-2025-23-fr", status = "published")
  ))
  expect_registry_valid(check_registry(root))
})

test_that("un registre vide ou absent est valide", {
  expect_registry_valid(check_registry(withr::local_tempdir()))
  root <- local_registry(list("README.md" = "# contentdb"))
  dir.create(file.path(root, "registry"))
  res <- check_registry(root)
  expect_registry_valid(res)
  expect_equal(res$n_declarations, 0L)
})

test_that("S5 : un status hors liste nomme le fichier, le champ et la valeur", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration(status = "publie")))
  res <- check_registry(root)
  expect_false(res$valid)
  expect_registry_error(res, "registry/2026/ofce-wp-2026-6-fr.json", "status", "\"publie\"")
})

test_that("S6 : l'id doit être égal au nom du fichier", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration("ofce-wp-2026-7-fr")))
  res <- check_registry(root)
  expect_false(res$valid)
  expect_registry_error(res, "registry/2026/ofce-wp-2026-6-fr.json", "id", "égal au nom du fichier")
  expect_registry_error(res, "registry/2026/ofce-wp-2026-6-fr.json", "id", "ofce-wp-2026-7-fr")
})

test_that("un fichier hors de registry/{annee}/ est refusé", {
  root <- local_registry(list(
    "registry/ofce-wp-2026-6-fr.json" = declaration(),
    "registry/26/ofce-wp-2026-7-fr.json" = declaration("ofce-wp-2026-7-fr"),
    "registry/2026/sous/ofce-wp-2026-8-fr.json" = declaration("ofce-wp-2026-8-fr"),
    "registry/2026/ofce-wp-2026-9-fr.txt" = "texte"
  ))
  res <- check_registry(root)
  expect_false(res$valid)
  for (f in c("registry/ofce-wp-2026-6-fr.json", "registry/26/ofce-wp-2026-7-fr.json",
              "registry/2026/sous/ofce-wp-2026-8-fr.json", "registry/2026/ofce-wp-2026-9-fr.txt")) {
    expect_registry_error(res, f, NA_character_, "registry/{annee}/{id}.json")
  }
})

test_that("un même id sous deux années est refusé, les deux fichiers nommés", {
  root <- local_registry(list(
    "registry/2025/ofce-wp-2026-6-fr.json" = declaration(),
    "registry/2026/ofce-wp-2026-6-fr.json" = declaration()
  ))
  res <- check_registry(root)
  expect_false(res$valid)
  dup <- res$errors[grepl("plusieurs", res$errors$message), ]
  expect_equal(nrow(dup), 1L)
  expect_match(dup$message, "registry/2025/ofce-wp-2026-6-fr.json", fixed = TRUE)
  expect_match(dup$message, "registry/2026/ofce-wp-2026-6-fr.json", fixed = TRUE)
})

test_that("un fichier hors de registry/ n'est pas contrôlé", {
  root <- local_registry(list(
    "README.md" = "pas du JSON",
    ".github/workflows/check-registry.yml" = "on: push",
    "registry/2026/ofce-wp-2026-6-fr.json" = declaration()
  ))
  expect_registry_valid(check_registry(root))
})

test_that("S7 : une suppression dans registry/ est refusée et nommée", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration()))
  res <- check_registry(root, deleted = c("registry/2025/ofce-wp-2025-23-fr.json", "README.md", ""))
  expect_false(res$valid)
  expect_equal(nrow(res$errors), 1L)
  expect_registry_error(res, "registry/2025/ofce-wp-2025-23-fr.json", NA_character_, "supprimé")
  expect_registry_error(res, "registry/2025/ofce-wp-2025-23-fr.json", NA_character_, "status: retired")
})

test_that("un JSON illisible est signalé sans erreur R", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = "{ \"id\": "))
  res <- check_registry(root)
  expect_false(res$valid)
  expect_registry_error(res, "registry/2026/ofce-wp-2026-6-fr.json", NA_character_, "JSON illisible")
})

test_that("S8 : toutes les erreurs de tous les fichiers sont rapportées ensemble", {
  root <- local_registry(list(
    "registry/2026/ofce-wp-2026-6-fr.json" = declaration(status = "publie", declared_at = "15/06/2026"),
    "registry/2026/ofce-wp-2026-7-fr.json" = declaration("ofce-wp-2026-7-fr", commentaire = "x"),
    "registry/2026/ofce-wp-2026-8-fr.json" = declaration("ofce-wp-2026-9-fr")
  ))
  res <- check_registry(root, deleted = "registry/2025/ofce-wp-2025-1-fr.json")
  expect_false(res$valid)
  expect_equal(nrow(res$errors), 5L)
  expect_registry_error(res, "ofce-wp-2026-6-fr.json", "status", "publie")
  expect_registry_error(res, "ofce-wp-2026-6-fr.json", "declared_at", "15/06/2026")
  expect_registry_error(res, "ofce-wp-2026-7-fr.json", "commentaire", "champ inconnu")
  expect_registry_error(res, "ofce-wp-2026-8-fr.json", "id", "égal au nom du fichier")
  expect_registry_error(res, "ofce-wp-2025-1-fr.json", NA_character_, "supprimé")
})

test_that("le résultat a la forme attendue", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration(status = "x")))
  res <- check_registry(root)
  expect_s3_class(res, "ofceweb_registry_check")
  expect_named(res$errors, c("file", "field", "message"))
})

test_that("un chemin Windows dans deleted est reconnu", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration()))
  res <- check_registry(root, deleted = "registry\\2025\\ofce-wp-2025-23-fr.json")
  expect_registry_error(res, "registry/2025/ofce-wp-2025-23-fr.json", NA_character_, "supprimé")
})

# --- Affichage ----------------------------------------------------------------

test_that("print affiche le verdict", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration()))
  expect_message(print(check_registry(root)), "1 déclaration")
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration(status = "publie")))
  out <- cli::cli_fmt(print(check_registry(root)))
  expect_true(any(grepl("registry/2026/ofce-wp-2026-6-fr.json", out, fixed = TRUE)))
  expect_true(any(grepl("status", out, fixed = TRUE)))
})

test_that("print n'interprète pas une valeur contenant {x}", {
  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration(status = "{x}")))
  out <- cli::cli_fmt(print(check_registry(root)))
  expect_true(any(grepl("{x}", out, fixed = TRUE)))
})

# --- Point d'entrée de la CI ----------------------------------------------------

test_that("check_registry_ci lit les suppressions et sort en erreur si le journal est invalide", {
  status <- NULL
  local_mocked_bindings(registry_ci_exit = function(s) status <<- s)

  root <- local_registry(list("registry/2026/ofce-wp-2026-6-fr.json" = declaration()))
  suppressMessages(check_registry_ci(root, deleted_file = file.path(root, "absent.txt")))
  expect_null(status)

  empty <- file.path(root, "vide.txt")
  writeLines(character(), empty)
  suppressMessages(check_registry_ci(root, deleted_file = empty))
  expect_null(status)
  suppressMessages(check_registry_ci(root))
  expect_null(status)

  del <- file.path(root, "deleted.txt")
  writeLines(c("registry/2025/ofce-wp-2025-23-fr.json", ""), del)
  out <- cli::cli_fmt(check_registry_ci(root, deleted_file = del))
  expect_equal(status, 1L)
  expect_true(any(grepl("ofce-wp-2025-23-fr.json", out, fixed = TRUE)))
})
