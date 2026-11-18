#' Collecte la base des contenus depuis le journal des déclarations
#'
#' Lit le journal des déclarations d'un dépôt comme `ofceweb/contentdb`,
#' télécharge le manifeste de chaque contenu déclaré, le valide, et construit
#' la base des contenus : un enregistrement par contenu, trié par `id`. La
#' fonction rend la base et la liste des anomalies. Elle ne lève pas d'erreur
#' R sur un contenu défaillant : le contenu est repris de la base précédente,
#' ou absent, et l'anomalie est signalée.
#'
#' La collecte est complète à chaque appel : tout le journal est relu et tous
#' les manifestes sont retéléchargés, en HTTP à leur `manifest_url`.
#'
#' 1. Le journal est contrôlé par [check_registry()]. Une déclaration refusée
#'    est ignorée ; un `id` déclaré dans plusieurs fichiers est ignoré dans
#'    tous.
#' 2. Chaque manifeste, `published` ou `retired`, est téléchargé (délai de
#'    30 secondes), puis validé comme par [validate_manifest()]. Son `id`, ou
#'    pour un manifeste collectif l'`id` de l'une de ses entrées, doit être
#'    celui de la déclaration. Un manifeste collectif dont une seule entrée
#'    est invalide est invalide en entier.
#' 3. Quand le manifeste ne répond pas, est invalide ou porte un autre `id`,
#'    les enregistrements de la base précédente qui venaient de ce manifeste
#'    (même `manifest_url`) sont repris tels quels, avec leur `collected_at` et
#'    leur `manifest_url`, mais avec le `status` de la déclaration en cours.
#'    Sans base précédente, le contenu est absent de la base.
#' 4. Chaque entrée d'un manifeste devient un enregistrement. Un enregistrement
#'    garde les champs v1 du manifeste (schéma `manifest-1.0.json`), dans
#'    l'ordre du schéma, et ajoute les cinq champs de l'agrégateur :
#'    * `author_ids` : une liste de `null`, de la longueur de `authors` (le
#'      rapprochement avec le référentiel des auteurs n'est pas encore fait) ;
#'    * `children` : les `id` des enregistrements dont le `parent` désigne ce
#'      contenu, triés par `date_published` puis par `id` ;
#'    * `status` : celui de la déclaration (celle d'`ofce-blog` pour un post) ;
#'    * `manifest_url` : l'URL du manifeste qui a produit l'enregistrement ;
#'    * `collected_at` : date et heure UTC du téléchargement réussi.
#'
#'    Les champs historiques ou inconnus du manifeste (`wp`, `stage`,
#'    `source-repo`…) ne passent pas dans la base.
#' 5. Le contenu d'une déclaration passe avant une entrée de manifeste
#'    collectif de même `id` ; entre deux entrées de même `id`, la première
#'    est gardée.
#'
#' Le package `jsonvalidate` est nécessaire. Il n'est pas installé avec
#' ofceweb : la fonction propose de l'installer au premier appel.
#'
#' @param root Racine du dépôt, qui contient le dossier `registry/`.
#' @param previous Base précédente : chemin d'un `contents.json`, liste R
#'   d'enregistrements (le `contents` d'une collecte précédente), ou `NULL`.
#'   Un fichier absent vaut `NULL` ; un fichier illisible ou qui n'est pas une
#'   base est signalé, et la collecte se fait sans base précédente.
#'
#' @returns Une liste de classe `ofceweb_contents_collection` :
#'   * `contents` : la base, liste d'enregistrements triée par `id` ;
#'   * `anomalies` : un tibble à une ligne par anomalie, de colonnes `type`,
#'     `id` (le contenu concerné, `NA` s'il est inconnu), `file` (le fichier de
#'     déclaration, ou le chemin de la base précédente) et `message`, en
#'     français. Les types sont :
#'     - `declaration_invalid` : déclaration refusée par [check_registry()] ;
#'     - `manifest_unreachable` : manifeste qui ne répond pas (404, 5xx,
#'       délai dépassé) ;
#'     - `manifest_invalid` : manifeste illisible ou refusé par la validation ;
#'     - `id_mismatch` : manifeste qui ne porte pas l'`id` de sa déclaration ;
#'     - `duplicate_id` : entrée écartée parce que son `id` est déjà pris ;
#'     - `parent_unresolved` : `parent` qui ne désigne aucun enregistrement ;
#'     - `previous_invalid` : base précédente illisible ;
#'   * `n_declarations` : le nombre de fichiers trouvés dans `registry/`.
#'
#' @seealso [write_contents()] pour écrire `contents.json`,
#'   [check_registry()], [validate_manifest()].
#'
#' @examples
#' \dontrun{
#' # Depuis la racine d'un clone de ofceweb/contentdb
#' res <- collect_contents(".", previous = "contents.json")
#' res
#' res$anomalies
#' write_contents(res, "contents.json")
#' }
#' @export
collect_contents <- function(root = ".", previous = NULL) {
  anomalies <- list(collect_anomaly_rows())
  note <- function(type, id, file, message) {
    anomalies[[length(anomalies) + 1L]] <<- collect_anomaly_rows(type, id, file, message)
  }

  prev <- collect_read_previous(previous)
  if (!is.null(prev$error)) {
    note("previous_invalid", NA_character_, if (is.character(previous)) previous else NA_character_, prev$error)
  }
  prev_ids <- vapply(prev$records, function(r) r$id, "")

  # 1. Journal
  chk <- check_registry(root)
  for (i in seq_len(nrow(chk$errors))) {
    e <- chk$errors[i, ]
    note("declaration_invalid", sub("\\.json$", "", basename(e$file)), e$file,
         paste0("déclaration ignorée : ", if (!is.na(e$field)) paste0(e$field, " : "), e$message))
  }
  files <- collect_registry_files(root)
  ids <- sub("\\.json$", "", basename(files))
  keep <- !(files %in% chk$errors$file) & !(ids %in% ids[duplicated(ids)])
  files <- files[keep]

  # 2, 3. Manifestes
  results <- lapply(files, function(f) {
    decl <- jsonlite::read_json(file.path(root, f), simplifyVector = FALSE)
    out <- collect_declaration(decl)
    if (!is.null(out$anomaly)) {
      prev_rec <- prev$records[match(decl$id, prev_ids)]
      part <- if (length(prev_rec)) {
        url <- prev_rec[[1]]$manifest_url
        Filter(function(r) identical(r$manifest_url, url), prev$records)
      } else list()
      part <- lapply(part, function(r) { r$status <- decl$status; r })
      suite <- if (length(part)) {
        sprintf("enregistrement%s précédent%s repris (%d).", if (length(part) > 1L) "s" else "",
                if (length(part) > 1L) "s" else "", length(part))
      } else {
        "contenu absent de la base : aucun enregistrement précédent."
      }
      note(out$anomaly$type, decl$id, f, paste0(out$anomaly$message, " ; ", suite))
      out$records <- part
    }
    list(id = decl$id, file = f, records = out$records)
  })

  # 5. Fusion : le contenu de chaque déclaration, puis les autres entrées.
  base <- list()
  src <- character()
  for (res in results) {
    own <- Filter(function(r) identical(r$id, res$id), res$records)
    if (length(own)) {
      base[[res$id]] <- own[[1]]
      src[[res$id]] <- res$file
    }
  }
  declared <- names(base)
  for (res in results) {
    own_seen <- FALSE
    for (r in res$records) {
      if (identical(r$id, res$id) && !own_seen) { own_seen <- TRUE; next }
      if (!is.null(base[[r$id]])) {
        why <- if (r$id %in% declared && !identical(r$id, res$id)) {
          sprintf("l'entrée %s du manifeste de %s a l'id d'un contenu déclaré à part : elle est écartée au profit de ce contenu.", r$id, res$id)
        } else {
          sprintf("deux entrées du manifeste de %s ont l'id %s : la première est gardée, la suivante est écartée.", res$id, r$id)
        }
        note("duplicate_id", r$id, res$file, why)
        next
      }
      base[[r$id]] <- r
      src[[r$id]] <- res$file
    }
  }

  # 4. Hiérarchie
  ids <- names(base) %||% character()
  parents <- vapply(base, function(r) if (is.character(r$parent) && length(r$parent) == 1L) r$parent else NA_character_, "")
  dates <- vapply(base, function(r) as.character(r$date_published %||% ""), "")
  for (id in ids) {
    kids <- ids[!is.na(parents) & parents == id]
    kids <- kids[order(dates[kids], kids, method = "radix")]
    base[[id]]["children"] <- list(as.list(kids))
  }
  for (id in ids[!is.na(parents) & !(parents %in% ids)]) {
    note("parent_unresolved", id, src[[id]], sprintf(
      "le parent %s ne désigne aucun contenu de la base : l'enregistrement est gardé avec ce parent.", parents[[id]]
    ))
  }

  base <- unname(base[order(ids, method = "radix")])
  structure(
    list(contents = base, anomalies = do.call(rbind, anomalies), n_declarations = chk$n_declarations),
    class = "ofceweb_contents_collection"
  )
}

#' Écrit la base des contenus dans `contents.json`
#'
#' Écrit la base rendue par [collect_contents()] en tableau JSON, UTF-8, un
#' enregistrement par contenu, dans l'ordre de la base (trié par `id`). Les
#' champs tableaux restent des tableaux JSON même avec un seul élément, et
#' les valeurs absentes s'écrivent `null`.
#'
#' @param x Résultat de [collect_contents()], ou liste d'enregistrements.
#' @param path Chemin du fichier à écrire.
#'
#' @returns `path`, invisible.
#'
#' @examples
#' \dontrun{
#' res <- collect_contents(".", previous = "contents.json")
#' write_contents(res, "contents.json")
#' }
#' @export
write_contents <- function(x, path = "contents.json") {
  records <- if (inherits(x, "ofceweb_contents_collection")) x$contents else x
  json <- if (length(records)) {
    jsonlite::toJSON(records, auto_unbox = TRUE, null = "null", digits = NA, pretty = TRUE)
  } else {
    "[]"
  }
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeLines(enc2utf8(as.character(json)), con, useBytes = TRUE)
  invisible(path)
}

#' @export
print.ofceweb_contents_collection <- function(x, ...) {
  n <- length(x$contents)
  a <- nrow(x$anomalies)
  if (a == 0L) {
    cli::cli_alert_success("Base collectée : {n} enregistrement{?s}, aucune anomalie.")
    return(invisible(x))
  }
  cli::cli_alert_warning("Base collectée : {n} enregistrement{?s}, {a} anomalie{?s}.")
  for (i in seq_len(a)) {
    e <- x$anomalies[i, ]
    where <- paste0(e$type, if (!is.na(e$id)) paste0(", ", e$id))
    # Valeurs passées comme variables du gabarit : cli ne réinterprète pas
    # leurs accolades, qui viennent des manifestes.
    cli::cli_bullets(c("!" = "{where} : {e$message}"))
  }
  invisible(x)
}

# --- Une déclaration -----------------------------------------------------------

# Télécharge et valide le manifeste d'une déclaration. Rend
# list(records = <enregistrements>) ou list(anomaly = list(type, message)).
collect_declaration <- function(decl) {
  url <- decl$manifest_url
  fail <- function(type, message) list(records = list(), anomaly = list(type = type, message = message))

  text <- tryCatch(manifest_read_url(url), error = function(e) e)
  if (inherits(text, "error")) {
    msg <- trimws(gsub("\\s+", " ", conditionMessage(text)))
    return(fail("manifest_unreachable", sprintf("manifeste injoignable à %s : %s", url, msg)))
  }

  val <- manifest_validate_text(text)
  if (!isTRUE(val$valid)) {
    e <- val$errors
    where <- ifelse(is.na(e$entry), "", paste0("entrée ", e$entry, ifelse(is.na(e$id), "", paste0(" (", e$id, ")")), ", "))
    where <- paste0(where, ifelse(is.na(e$field), "", paste0(e$field, " : ")))
    return(fail("manifest_invalid", sprintf(
      "manifeste invalide à %s : %s", url, paste0(where, e$message, collapse = " ; ")
    )))
  }

  parsed <- jsonlite::parse_json(text, simplifyVector = FALSE)
  collective <- is.null(names(parsed))
  entries <- if (collective) parsed else list(parsed)
  entry_ids <- vapply(entries, function(m) m$id, "")
  if (!(decl$id %in% entry_ids)) {
    return(fail("id_mismatch", if (collective) {
      sprintf("le manifeste collectif à %s ne contient aucune entrée d'id %s, l'id de la déclaration.", url, decl$id)
    } else {
      sprintf("le manifeste à %s porte l'id %s, la déclaration l'id %s.", url, entry_ids, decl$id)
    }))
  }

  now <- collect_now()
  list(records = lapply(entries, collect_record, status = decl$status, manifest_url = url, collected_at = now))
}

# Un enregistrement : champs v1 du manifeste dans l'ordre du schéma, puis les
# cinq champs de l'agrégateur. `children` est calculé à la fusion.
collect_record <- function(m, status, manifest_url, collected_at) {
  fields <- collect_manifest_fields()
  r <- m[intersect(fields, names(m))]
  r["author_ids"] <- list(rep(list(NULL), length(m$authors)))
  r["children"] <- list(list())
  r$status <- status
  r$manifest_url <- manifest_url
  r$collected_at <- collected_at
  r
}

# Champs v1 du manifeste : les `properties` du schéma, moins les cinq champs
# réservés à l'agrégateur.
collect_manifest_fields <- function() {
  if (is.null(.manifest_cache$collect_fields)) {
    schema <- jsonlite::read_json(manifest_schema_path())
    .manifest_cache$collect_fields <- setdiff(names(schema$properties), collect_aggregator_fields)
  }
  .manifest_cache$collect_fields
}

collect_aggregator_fields <- c("author_ids", "children", "status", "manifest_url", "collected_at")

# Date et heure de collecte, remplacée dans les tests.
collect_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

# --- Journal et base précédente ---------------------------------------------------

collect_registry_files <- function(root) {
  reg <- file.path(root, "registry")
  files <- if (dir.exists(reg)) sort(list.files(reg, recursive = TRUE)) else character()
  rel <- file.path("registry", files)
  rel[grepl("^registry/[0-9]{4}/[^/]+\\.json$", rel)]
}

# Rend list(records = <liste>) et, si la base est illisible, `error`.
collect_read_previous <- function(previous) {
  if (is.null(previous)) return(list(records = list()))
  if (is.character(previous) && length(previous) == 1L && !is.na(previous)) {
    if (!file.exists(previous)) return(list(records = list()))
    x <- tryCatch(jsonlite::read_json(previous, simplifyVector = FALSE), error = function(e) e)
    if (inherits(x, "error")) {
      msg <- trimws(gsub("\\s+", " ", conditionMessage(x)))
      return(list(records = list(), error = paste0(
        "base précédente illisible (", msg, ") : la collecte se fait sans base précédente."
      )))
    }
  } else if (is.list(previous)) {
    x <- previous
  } else {
    cli::cli_abort("{.arg previous} doit être un chemin de fichier, une liste d'enregistrements ou NULL.")
  }

  is_str <- function(v) is.character(v) && length(v) == 1L
  ok <- is.list(x) && is.null(names(x)) &&
    all(vapply(x, function(r) is.list(r) && is_str(r$id) && is_str(r$manifest_url), TRUE))
  if (!ok) {
    return(list(records = list(), error = paste0(
      "la base précédente n'est pas un tableau d'enregistrements portant un id et une manifest_url : ",
      "la collecte se fait sans base précédente."
    )))
  }
  list(records = x)
}

collect_anomaly_rows <- function(type = character(0), id = character(0), file = character(0), message = character(0)) {
  n <- length(message)
  tibble::tibble(
    type = rep_len(as.character(type), n),
    id = rep_len(as.character(id), n),
    file = rep_len(as.character(file), n),
    message = as.character(message)
  )
}
