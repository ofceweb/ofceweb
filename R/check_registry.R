#' Contrôle le journal des déclarations de la base des contenus
#'
#' Vérifie toutes les déclarations du dossier `registry/` d'un dépôt comme
#' `ofceweb/contentdb`, et rend **toutes** les erreurs trouvées, en français,
#' chacune rattachée à son fichier et à son champ. La fonction ne lève pas
#' d'erreur R sur une déclaration fautive : elle rend un verdict.
#'
#' Une déclaration est un fichier `registry/{annee}/{id}.json`, où `{annee}`
#' est l'année de première publication du contenu. Un fichier par contenu :
#' une nouvelle déclaration du même contenu modifie ce fichier, l'historique
#' Git sert de journal, et aucun fichier n'est jamais supprimé.
#'
#' La fonction vérifie :
#'
#' 1. chaque fichier avec le schéma JSON Schema `declaration-1.0.json`
#'    (draft-07), livré dans `system.file("schema", package = "ofceweb")` et
#'    publié à
#'    <https://raw.githubusercontent.com/ofceweb/ofceweb/main/inst/schema/declaration-1.0.json> :
#'    six champs obligatoires, leurs formats, aucun champ inconnu ;
#' 2. le rangement : chaque fichier de `registry/` est un `.json` rangé dans
#'    un dossier d'année à quatre chiffres, et son `id` est égal au nom du
#'    fichier sans `.json` ;
#' 3. l'unicité : un même `id` n'est déclaré que dans un seul fichier ;
#' 4. les suppressions : aucun fichier de `registry/` ne figure dans
#'    `deleted`. Un fichier déplacé d'une année à l'autre y figure sous son
#'    ancien chemin, et compte donc comme une suppression.
#'
#' Elle ne vérifie pas que le manifeste pointé par `manifest_url` répond ni
#' qu'il est valide : c'est le rôle de la collecte. Les fichiers hors de
#' `registry/` ne sont pas contrôlés.
#'
#' Un dossier `registry/` vide est un journal valide, sans déclaration. En
#' revanche, si `root` n'existe pas ou ne contient pas de dossier
#' `registry/`, la fonction s'arrête par une erreur de classe
#' `ofceweb_registry_not_found` qui nomme le dossier attendu : c'est presque
#' toujours un appel depuis le mauvais dossier, et un verdict « valide »
#' serait trompeur. C'est la seule erreur R de la fonction ; une déclaration
#' fautive donne toujours un verdict.
#'
#' Le package `jsonvalidate` est nécessaire. Il n'est pas installé avec
#' ofceweb : la fonction propose de l'installer au premier appel.
#'
#' @param root Racine du dépôt, qui doit contenir le dossier `registry/`.
#' @param deleted Chemins des fichiers supprimés par le push ou la pull
#'   request contrôlés, relatifs à la racine du dépôt (par exemple la sortie
#'   de `git diff --no-renames --name-only --diff-filter=D`). Les chemins hors
#'   de `registry/` sont ignorés.
#'
#' @returns Une liste de classe `ofceweb_registry_check` :
#'   * `valid` : `TRUE` si le journal est conforme ;
#'   * `n_declarations` : le nombre de fichiers trouvés dans `registry/` ;
#'   * `errors` : un tibble à une ligne par erreur, de colonnes `file` (chemin
#'     relatif à la racine), `field` (le champ concerné, `NA` pour une erreur
#'     qui porte sur tout le fichier) et `message`.
#'
#' @seealso [check_registry_ci()] pour la CI de `contentdb`,
#'   [validate_manifest()] pour contrôler un manifeste.
#'
#' @examples
#' \dontrun{
#' # Depuis la racine d'un clone de ofceweb/contentdb
#' check_registry(".")
#'
#' res <- check_registry(".", deleted = "registry/2026/ofce-wp-2026-6-fr.json")
#' res$valid
#' res$errors
#' }
#' @export
check_registry <- function(root = ".", deleted = character()) {
  path <- normalizePath(root, winslash = "/", mustWork = FALSE)
  if (!dir.exists(root)) {
    cli::cli_abort(
      "Dossier introuvable : {path}. Lancez le contrôle depuis la racine d'un clone de contentdb.",
      class = "ofceweb_registry_not_found"
    )
  }
  reg <- file.path(root, "registry")
  if (!dir.exists(reg)) {
    cli::cli_abort(
      "Aucun dossier registry/ dans {path} : lancez le contrôle depuis la racine d'un clone de contentdb.",
      class = "ofceweb_registry_not_found"
    )
  }
  files <- sort(list.files(reg, recursive = TRUE))
  rel <- file.path("registry", files)

  well_placed <- grepl("^registry/[0-9]{4}/[^/]+\\.json$", rel)
  rows <- list(registry_error_rows(
    rel[!well_placed],
    NA_character_,
    rep("fichier mal rangé : une déclaration se range dans registry/{annee}/{id}.json, avec une année sur quatre chiffres.",
        sum(!well_placed))
  ))

  for (f in rel[well_placed]) {
    text <- paste(readLines(file.path(root, f), encoding = "UTF-8", warn = FALSE), collapse = "\n")
    r <- declaration_check_text(text, expected_id = sub("\\.json$", "", basename(f)))
    rows <- c(rows, list(registry_error_rows(rep(f, nrow(r)), r$field, r$message)))
  }

  ids <- sub("\\.json$", "", basename(rel[well_placed]))
  for (id in unique(ids[duplicated(ids)])) {
    dup <- rel[well_placed][ids == id]
    rows <- c(rows, list(registry_error_rows(dup[1], "id", sprintf(
      "%s est déclaré dans plusieurs fichiers : %s. Un contenu n'a qu'un fichier, rangé sous son année de première publication.",
      id, paste(dup, collapse = ", ")
    ))))
  }

  deleted <- gsub("\\\\", "/", trimws(as.character(deleted)))
  deleted <- deleted[startsWith(deleted, "registry/")]
  rows <- c(rows, list(registry_error_rows(
    deleted,
    NA_character_,
    rep("fichier supprimé : une déclaration ne se supprime ni ne se déplace jamais ; un retrait passe par status: retired.",
        length(deleted))
  )))

  errors <- do.call(rbind, rows)
  structure(
    list(valid = nrow(errors) == 0L, n_declarations = length(rel), errors = errors),
    class = "ofceweb_registry_check"
  )
}

#' Point d'entrée de la CI de `contentdb`
#'
#' Lance [check_registry()], affiche le résultat, et termine la session R avec
#' le code de sortie 1 si le journal n'est pas conforme. C'est la seule
#' fonction qu'appelle le workflow de `ofceweb/contentdb` : le dépôt ne
#' contient aucune logique. Si `root` n'existe pas ou n'a pas de dossier
#' `registry/`, l'erreur de [check_registry()] arrête la session, et
#' `Rscript` sort aussi en échec.
#'
#' @param root Racine du dépôt, qui doit contenir le dossier `registry/`.
#' @param deleted_file Fichier texte qui liste les fichiers supprimés, un
#'   chemin par ligne, relatif à la racine du dépôt. Un fichier absent ou vide,
#'   ou `NULL`, signifie qu'aucun fichier n'a été supprimé.
#'
#' @returns Le résultat de [check_registry()], invisible, quand le journal
#'   est conforme.
#'
#' @examples
#' \dontrun{
#' # Dans le workflow de contentdb, après
#' # git diff --no-renames --name-only --diff-filter=D <avant> <après> -- registry/ > deleted.txt
#' ofceweb::check_registry_ci(".", "deleted.txt")
#' }
#' @export
check_registry_ci <- function(root = ".", deleted_file = NULL) {
  deleted <- if (!is.null(deleted_file) && file.exists(deleted_file)) {
    readLines(deleted_file, encoding = "UTF-8", warn = FALSE)
  } else {
    character()
  }
  deleted <- deleted[nzchar(trimws(deleted))]
  res <- check_registry(root, deleted = deleted)
  print(res)
  if (!res$valid) registry_ci_exit(1L)
  invisible(res)
}

registry_ci_exit <- function(status) quit(save = "no", status = status)

#' @export
print.ofceweb_registry_check <- function(x, ...) {
  if (isTRUE(x$valid)) {
    n <- x$n_declarations
    if (n == 0L) {
      cli::cli_alert_success("Journal vide : aucune déclaration.")
    } else {
      cli::cli_alert_success("Journal valide : {n} déclaration{?s}.")
    }
    return(invisible(x))
  }
  n <- nrow(x$errors)
  cli::cli_alert_danger("Journal invalide : {n} erreur{?s}.")
  for (i in seq_len(n)) {
    e <- x$errors[i, ]
    where <- paste0(e$file, if (!is.na(e$field)) paste0(", ", e$field))
    # Valeurs passées comme variables du gabarit : cli ne réinterprète pas
    # leurs accolades, qui viennent des déclarations.
    cli::cli_bullets(c(x = "{where} : {e$message}"))
  }
  invisible(x)
}

# --- Une déclaration ---------------------------------------------------------

# Contrôle le texte JSON d'une déclaration : schéma, puis `id` égal au nom du
# fichier si `expected_id` est fourni. Rend un tibble `field`, `message`.
declaration_check_text <- function(text, expected_id = NULL) {
  parsed <- tryCatch(jsonlite::parse_json(text, simplifyVector = FALSE), error = function(e) e)
  if (inherits(parsed, "error")) {
    msg <- trimws(gsub("\\s+", " ", conditionMessage(parsed)))
    return(declaration_rows(NA_character_, paste0("JSON illisible : ", msg)))
  }

  res <- declaration_validator()(text, verbose = TRUE, greedy = TRUE)
  rows <- if (isTRUE(as.logical(res))) manifest_error_rows() else manifest_translate_errors(attr(res, "errors"), parsed)
  rows <- declaration_rows(rows$field, rows$message)

  id <- if (is.list(parsed) && !is.null(names(parsed))) parsed[["id"]] else NULL
  if (!is.null(expected_id) && is.character(id) && length(id) == 1L && !identical(id, expected_id)) {
    rows <- rbind(rows, declaration_rows("id", sprintf(
      "l'id doit être égal au nom du fichier sans .json : le fichier attend %s, l'id vaut %s.",
      expected_id, id
    )))
  }
  rows
}

# Validateur ajv du schéma de la déclaration, créé une fois par session.
declaration_validator <- function() {
  rlang::check_installed("jsonvalidate", reason = "pour contrôler le journal des déclarations.")
  if (is.null(.manifest_cache$declaration_validator)) {
    .manifest_cache$declaration_validator <- jsonvalidate::json_validator(
      manifest_schema_path("declaration-1.0.json"), engine = "ajv"
    )
  }
  .manifest_cache$declaration_validator
}

declaration_rows <- function(field = character(0), message = character(0)) {
  tibble::tibble(field = as.character(field), message = as.character(message))
}

registry_error_rows <- function(file = character(0), field = character(0), message = character(0)) {
  n <- length(message)
  tibble::tibble(file = rep_len(as.character(file), n), field = rep_len(as.character(field), n), message = as.character(message))
}
