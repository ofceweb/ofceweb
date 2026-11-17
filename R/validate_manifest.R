#' Valide un manifeste de contenu (modèle de données v1)
#'
#' Contrôle un manifeste unitaire (un objet JSON) ou un manifeste collectif
#' (un tableau JSON de manifestes, comme celui du blog) et rend **toutes** les
#' erreurs trouvées, en français, chacune rattachée au champ concerné. La
#' fonction ne lève pas d'erreur R sur un manifeste invalide ou illisible :
#' elle rend un verdict, pour qu'une collecte puisse continuer avec les autres
#' manifestes.
#'
#' La validation se fait en deux temps :
#'
#' 1. le schéma JSON Schema `manifest-1.0.json` (draft-07), livré dans
#'    `system.file("schema", package = "ofceweb")` et publié à
#'    <https://raw.githubusercontent.com/ofceweb/ofceweb/main/inst/schema/manifest-1.0.json>,
#'    contrôle chaque champ. Il est appliqué avec `ajv`, le même outil que
#'    hors de R : le verdict est le même ;
#' 2. deux règles qui relient plusieurs champs, que le schéma ne sait pas
#'    exprimer : `date_modified` postérieure ou égale à `date_published`, et
#'    `id` qui commence par la valeur d'`institution` suivie d'un tiret.
#'
#' Un manifeste collectif est contrôlé entrée par entrée avec le schéma
#' unitaire ; chaque erreur indique la position de l'entrée et son `id`.
#'
#' Le package `jsonvalidate` est nécessaire. Il n'est pas installé avec
#' ofceweb : la fonction propose de l'installer au premier appel.
#'
#' @param x Manifeste à valider : chemin d'un fichier JSON, URL (`http://` ou
#'   `https://`), ou liste R (une liste nommée pour un manifeste unitaire, une
#'   liste non nommée de manifestes pour un manifeste collectif). Dans une liste
#'   R, les champs tableaux (`authors`, `categories`, `keywords`, `jel`…)
#'   doivent être des `list()`, comme dans `wp_manifest()`, pour être écrits en
#'   tableaux JSON même avec un seul élément ; `NULL` est écrit `null`.
#'
#' @returns Une liste de classe `ofceweb_manifest_validation` :
#'   * `valid` : `TRUE` si le manifeste est conforme ;
#'   * `errors` : un tibble à une ligne par erreur, de colonnes `entry`
#'     (position de l'entrée dans un manifeste collectif, `NA` pour un
#'     manifeste unitaire), `id` (l'`id` du manifeste concerné, s'il en a un),
#'     `field` (le champ concerné, `NA` pour une erreur qui porte sur tout le
#'     manifeste) et `message`.
#'
#' @examples
#' \dontrun{
#' ex <- system.file("schema", "exemples", "valides", "wp-2025-23.json",
#'                   package = "ofceweb")
#' validate_manifest(ex)
#' validate_manifest("https://www.ofce.fr/wp/2025/23/v1/manifest.json")
#'
#' res <- validate_manifest(list(schema_version = "1.0", id = NULL))
#' res$valid
#' res$errors
#' }
#' @export
validate_manifest <- function(x) {
  input <- manifest_input_text(x)
  if (!is.null(input$error)) return(manifest_validation_result(manifest_error_rows(NA_character_, input$error)))

  parsed <- tryCatch(
    jsonlite::parse_json(input$text, simplifyVector = FALSE),
    error = function(e) e
  )
  if (inherits(parsed, "error")) {
    msg <- trimws(gsub("\\s+", " ", conditionMessage(parsed)))
    return(manifest_validation_result(manifest_error_rows(NA_character_, paste0("JSON illisible : ", msg))))
  }

  validator <- manifest_validator()

  # Tableau JSON au premier niveau : manifeste collectif, contrôlé entrée par
  # entrée. Un objet JSON a des noms (`named list()` pour `{}`).
  if (is.list(parsed) && is.null(names(parsed))) {
    if (length(parsed) == 0L) {
      return(manifest_validation_result(manifest_error_rows(
        NA_character_, "le manifeste collectif est vide : au moins une entrée est attendue."
      )))
    }
    errors <- lapply(seq_along(parsed), function(i) {
      entry_json <- manifest_to_json(parsed[[i]])
      e <- manifest_check_one(entry_json, parsed[[i]], validator)
      if (nrow(e) > 0L) e$entry <- i
      e
    })
    return(manifest_validation_result(do.call(rbind, errors)))
  }

  manifest_validation_result(manifest_check_one(input$text, parsed, validator))
}

#' @export
print.ofceweb_manifest_validation <- function(x, ...) {
  if (isTRUE(x$valid)) {
    cli::cli_alert_success("Manifeste valide.")
    return(invisible(x))
  }
  n <- nrow(x$errors)
  cli::cli_alert_danger("Manifeste invalide : {n} erreur{?s}.")
  for (i in seq_len(n)) {
    e <- x$errors[i, ]
    where <- c(
      if (!is.na(e$entry)) paste0("entrée ", e$entry, if (!is.na(e$id)) paste0(" (", e$id, ")")),
      if (!is.na(e$field)) e$field
    )
    prefix <- if (length(where)) paste0(paste(where, collapse = ", "), " : ") else ""
    cli::cli_bullets(c(x = paste0(cli::format_inline("{prefix}"), cli::format_inline("{e$message}"))))
  }
  invisible(x)
}

# --- Lecture -----------------------------------------------------------------

# Rend list(text = <JSON>) ou list(error = <message>). Le texte d'un fichier ou
# d'une URL est validé tel quel : l'aller-retour par jsonlite peut changer
# `null` et `[]`.
manifest_input_text <- function(x) {
  if (is.list(x)) return(list(text = manifest_to_json(x)))

  if (!is.character(x) || length(x) != 1L || is.na(x))
    cli::cli_abort("{.arg x} doit être un chemin de fichier, une URL ou une liste R.")

  if (grepl("^https?://", x)) {
    text <- tryCatch(manifest_read_url(x), error = function(e) e)
    if (inherits(text, "error"))
      return(list(error = paste0("lecture impossible de l'URL ", x, " : ", conditionMessage(text))))
    return(list(text = text))
  }

  if (!file.exists(x)) return(list(error = paste0("fichier introuvable : ", x)))
  list(text = paste(readLines(x, encoding = "UTF-8", warn = FALSE), collapse = "\n"))
}

manifest_read_url <- function(url) {
  resp <- httr2::req_perform(httr2::request(url))
  httr2::resp_body_string(resp, encoding = "UTF-8")
}

# Liste R -> texte JSON (conventions d'AGENTS.md : scalaires sans tableau,
# NULL écrit null).
manifest_to_json <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA))
}

# --- Validation --------------------------------------------------------------

.manifest_cache <- new.env(parent = emptyenv())

manifest_schema_path <- function(name = "manifest-1.0.json") {
  system.file("schema", name, package = "ofceweb", mustWork = TRUE)
}

# Validateur ajv créé une fois par session.
manifest_validator <- function() {
  rlang::check_installed("jsonvalidate", reason = "pour valider un manifeste.")
  if (is.null(.manifest_cache$validator)) {
    .manifest_cache$validator <- jsonvalidate::json_validator(manifest_schema_path(), engine = "ajv")
  }
  .manifest_cache$validator
}

# Un manifeste unitaire : schéma, puis règles entre champs. `parsed` est la
# version R du même JSON, pour les règles R et l'`id`.
manifest_check_one <- function(json, parsed, validator) {
  res <- validator(json, verbose = TRUE, greedy = TRUE)
  rows <- if (isTRUE(as.logical(res))) manifest_error_rows() else manifest_translate_errors(attr(res, "errors"), parsed)
  rows <- rbind(rows, manifest_cross_rules(parsed))
  id <- if (is.list(parsed) && is.character(parsed[["id"]]) && length(parsed[["id"]]) == 1L) parsed[["id"]] else NA_character_
  rows$id <- rep(id, nrow(rows))
  rows
}

# Règles qui relient plusieurs champs (hors JSON Schema).
manifest_cross_rules <- function(m) {
  out <- manifest_error_rows()
  if (!is.list(m) || is.null(names(m))) return(out)
  is_str <- function(v) is.character(v) && length(v) == 1L
  date_re <- "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$"

  dp <- m[["date_published"]]
  dm <- m[["date_modified"]]
  if (is_str(dp) && is_str(dm) && grepl(date_re, dp) && grepl(date_re, dm) && dm < dp) {
    out <- rbind(out, manifest_error_rows("date_modified", sprintf(
      "doit être postérieure ou égale à date_published : date_modified vaut %s, date_published vaut %s.",
      dm, dp
    )))
  }

  id <- m[["id"]]
  inst <- m[["institution"]]
  if (is_str(id) && is_str(inst) && !startsWith(id, paste0(inst, "-"))) {
    out <- rbind(out, manifest_error_rows("id", sprintf(
      "doit commencer par « %s- », la valeur d'institution suivie d'un tiret (reçu : %s).",
      inst, id
    )))
  }
  out
}

# --- Traduction des erreurs d'ajv --------------------------------------------

manifest_type_labels <- c(
  string = "une chaîne de caractères", array = "une liste", object = "un objet",
  boolean = "un booléen (true ou false)", null = "null", number = "un nombre",
  integer = "un entier"
)

# Message attendu pour les champs qui admettent aussi `null` (anyOf).
manifest_nullable_expected <- c(
  translation_id = "un identifiant (minuscules, segments alphanumériques séparés par des tirets) ou null",
  parent         = "un identifiant (minuscules, segments alphanumériques séparés par des tirets) ou null",
  date_modified  = "une date au format AAAA-MM-JJ ou null",
  pdf            = "une URL absolue en https ou null",
  image          = "une URL absolue en https ou null",
  repo           = "une URL absolue en https ou null"
)

manifest_show_value <- function(v) {
  if (is.null(v)) return("null")
  s <- as.character(jsonlite::toJSON(v, auto_unbox = TRUE, null = "null", digits = NA))
  if (nchar(s) > 60L) s <- paste0(substr(s, 1L, 57L), "...")
  s
}

manifest_translate_errors <- function(err, parsed) {
  if (is.null(err) || nrow(err) == 0L) return(manifest_error_rows())

  path <- err$instancePath
  # Un anyOf qui échoue est accompagné des erreurs de chacune de ses branches :
  # on ne garde que l'anyOf. L'erreur `if` double celle de `then`.
  anyof_paths <- path[err$keyword == "anyOf"]
  keep <- err$keyword != "if" & !(path %in% anyof_paths & err$keyword != "anyOf")
  err <- err[keep, , drop = FALSE]

  rows <- lapply(seq_len(nrow(err)), function(i) {
    manifest_translate_one(
      keyword = err$keyword[i],
      path = err$instancePath[i],
      params = lapply(err$params, function(col) col[[i]]),
      data = manifest_value_at(parsed, err$instancePath[i]),
      original = err$message[i]
    )
  })
  do.call(rbind, c(list(manifest_error_rows()), rows))
}

# Valeur du manifeste à un chemin JSON Pointer (`/authors/0`), lue dans la
# version R du manifeste : la colonne `data` d'ajv simplifie les objets.
manifest_value_at <- function(parsed, path) {
  segs <- strsplit(sub("^/", "", path), "/", fixed = TRUE)[[1]]
  v <- parsed
  for (s in segs[nzchar(segs)]) {
    if (!is.list(v)) return(NULL)
    v <- if (grepl("^[0-9]+$", s) && is.null(names(v))) v[[as.integer(s) + 1L]] else v[[s]]
  }
  v
}

manifest_translate_one <- function(keyword, path, params, data, original) {
  segs <- strsplit(sub("^/", "", path), "/", fixed = TRUE)[[1]]
  field <- if (length(segs) && nzchar(segs[1])) segs[1] else NA_character_
  item <- if (length(segs) >= 2L && grepl("^[0-9]+$", segs[2])) as.integer(segs[2]) + 1L else NA_integer_
  received <- manifest_show_value(data)
  recu <- paste0(" (reçu : ", received, ")")
  pre <- if (!is.na(item)) paste0("élément ", item, " : ") else ""

  msg <- switch(
    keyword,
    required = {
      field <- params$missingProperty
      if (identical(field, "pdf")) "champ obligatoire manquant quand media vaut pdf." else "champ obligatoire manquant."
    },
    anyOf = paste0("doit être ", manifest_nullable_expected[[field]] %||% "d'une forme admise", recu, "."),
    const = paste0("doit valoir \"", params$allowedValue, "\"", recu, "."),
    enum = paste0(
      pre, "valeur ", received, " non admise ; valeurs admises : ",
      paste(unlist(params$allowedValues), collapse = ", "), "."
    ),
    type = {
      if (identical(field, "id") && is.null(data)) {
        "l'id vaut null : un brouillon n'est pas conforme, le format v1 ne s'applique qu'aux contenus publiés."
      } else if (identical(field, "pdf")) {
        paste0("doit être une URL absolue en https quand media vaut pdf", recu, ".")
      } else {
        types <- strsplit(as.character(params$type), ",", fixed = TRUE)[[1]]
        labels <- unname(ifelse(types %in% names(manifest_type_labels), manifest_type_labels[types], types))
        paste0(pre, "doit être ", paste(labels, collapse = " ou "), recu, ".")
      }
    },
    pattern = paste0(pre, manifest_pattern_message(field), recu, "."),
    minLength = paste0(pre, "ne doit pas être vide."),
    minItems = paste0("doit contenir au moins ", params$limit, " élément(s)."),
    not = ,
    `false schema` = "champ réservé à l'agrégateur : il ne doit pas figurer dans un manifeste source.",
    paste0(pre, original, recu, ".")
  )
  manifest_error_rows(field, msg)
}

manifest_pattern_message <- function(field) {
  switch(
    field %||% "",
    id = "doit être en minuscules, fait de segments alphanumériques séparés par des tirets (ex. ofce-wp-2026-6-fr)",
    jel = "code JEL invalide : une majuscule suivie d'au plus deux chiffres est attendue (ex. E37)",
    date_published = ,
    date_modified = "doit être une date au format AAAA-MM-JJ",
    url = ,
    pdf = ,
    image = ,
    repo = "doit être une URL absolue en https",
    "ne respecte pas le format attendu"
  )
}

# --- Résultat ----------------------------------------------------------------

manifest_error_rows <- function(field = character(0), message = character(0)) {
  tibble::tibble(
    entry = rep(NA_integer_, length(message)),
    id = rep(NA_character_, length(message)),
    field = as.character(field),
    message = as.character(message)
  )
}

manifest_validation_result <- function(errors) {
  errors <- tibble::as_tibble(errors)
  structure(list(valid = nrow(errors) == 0L, errors = errors), class = "ofceweb_manifest_validation")
}
