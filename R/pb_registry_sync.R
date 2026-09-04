#' Liste des années disponibles dans le sous-dossier `pb/` de `wp-registry`
#' (`pb/index.json`)
#'
#' Télécharge `pb/index.json` (lecture publique, non authentifiée) du dépôt
#' registre central. Les PB partagent le même dépôt que les WP
#' (`ofce/wp-registry`) — sous le sous-dossier `pb/`, distinct de `wp/` — il
#' n'existe pas de dépôt `pb-registry` séparé. Utilisé pour savoir quels
#' fichiers `pb/{année}.json` interroger. Équivalent PB de [fetch_wp_index()].
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Vecteur entier des années, ou `NULL` si `pb/index.json` est
#'   inaccessible (registre indisponible).
#' @keywords internal
#' @noRd
fetch_pb_index <- function(registry_repo = "ofce/wp-registry") {
  index_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/pb/index.json", registry_repo)
  tryCatch({
    years <- jsonlite::fromJSON(index_url, simplifyVector = TRUE)$years
    as.integer(years)
  }, error = function(e) NULL)
}

#' Lit les entrées d'une année du registre PB (`pb/{année}.json`)
#'
#' Équivalent PB de [fetch_wp_year()] : lit le sous-dossier `pb/` et la clé
#' JSON `$pb` (racine du fichier annuel).
#'
#' @param annee Entier. Année à lire.
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Liste d'entrées (`registry$pb`), ou `NULL` si le fichier est
#'   introuvable ou illisible (année pas encore créée, ou erreur réseau).
#' @keywords internal
#' @noRd
fetch_pb_year <- function(annee, registry_repo = "ofce/wp-registry") {
  year_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/pb/%d.json",
    registry_repo, as.integer(annee))
  tryCatch(
    jsonlite::fromJSON(year_url, simplifyVector = FALSE)$pb,
    error = function(e) NULL
  )
}

#' Fusionne toutes les entrées du sous-dossier `pb/` de `wp-registry`
#'
#' Équivalent PB de [fetch_wp_entries()]. Télécharge `pb/index.json` puis
#' chaque `pb/{année}.json` qui y est listé, et fusionne toutes les entrées
#' obtenues. Tolérant : une année illisible individuellement est ignorée avec
#' un avertissement, sans bloquer la lecture des autres années.
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Liste fusionnée d'entrées, ou `NULL` si `pb/index.json` lui-même
#'   est inaccessible (à distinguer d'une liste vide, qui signifie un registre
#'   lu avec succès mais sans années ou sans entrées).
#' @keywords internal
#' @noRd
fetch_pb_entries <- function(registry_repo = "ofce/wp-registry") {
  years <- fetch_pb_index(registry_repo)
  if (is.null(years)) return(NULL)

  entries <- list()
  for (y in years) {
    yr_entries <- fetch_pb_year(y, registry_repo)
    if (is.null(yr_entries)) {
      cli::cli_alert_warning(
        "Année {.val {y}} du registre illisible ({.url pb/{y}.json}) — ignorée.")
      next
    }
    entries <- c(entries, yr_entries)
  }
  entries
}

#' Consulte le registre central PB et synchronise `draft`/`pb`/`annee`
#'
#' Équivalent PB de [sync_wp_registry_state()]. Interroge le sous-dossier
#' `pb/` de `ofce/wp-registry` (via [fetch_pb_entries()]) pour savoir si le
#' dépôt courant a une entrée confirmée (`type == "repo"` avec `source-repo`
#' correspondant au remote `origin` local). Le résultat (`stage = FALSE` si
#' publié, `TRUE` si staging) est écrit dans la clé `draft` de `_quarto.yml`
#' (lue par `ofce-quarto-extensions` pour le bandeau « Version provisoire »),
#' et les clés `pb`/`annee` sont synchronisées depuis l'entrée trouvée (dépôt
#' publié) ou effacées (staging, pas encore de numéro attribué).
#'
#' Les PB partagent le même dépôt registre que les WP (`ofce/wp-registry`) —
#' sous `pb/`, distinct de `wp/` — il n'existe pas de dépôt `pb-registry`
#' séparé.
#'
#' En cas d'échec de consultation du registre (réseau, `pb/index.json`
#' inaccessible), l'état ne peut pas être vérifié -- la fonction force alors
#' `draft: true` et efface `pb`/`annee` de `_quarto.yml`, même pour un dépôt
#' déjà publié : une vérification impossible ne doit jamais être traitée comme
#' une confirmation implicite du statu quo. La fonction retourne
#' `network_error = TRUE` pour que les appelants ([setup_pb()], [publish_pb()])
#' puissent avertir l'utilisateur·rice.
#'
#' @param root Chemin vers la racine du dépôt. Défaut `"."`.
#' @param quiet Logique. Si `TRUE`, supprime les messages `cli`. Défaut
#'   `FALSE`.
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#'   Défaut `"ofce/wp-registry"`.
#' @return Liste `list(stage, registry_entry, source_repo, network_error)`.
#'   Si `network_error` est `TRUE`, `stage` vaut `TRUE` (brouillon forcé) et
#'   `pb`/`annee` ont été effacés de `_quarto.yml`.
#' @keywords internal
#' @noRd
sync_pb_registry_state <- function(root = ".", quiet = FALSE,
                                   registry_repo = "ofce/wp-registry") {
  qyml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(qyml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  say <- function(...) if (!quiet) cli::cli_alert_success(...)
  warn <- function(...) if (!quiet) cli::cli_alert_warning(...)

  source_repo <- tryCatch(gh_slug_from_remote(root), error = function(e) NA_character_)
  entries     <- fetch_pb_entries(registry_repo)

  if (is.null(entries)) {
    # Verification impossible : on ne peut pas garantir que ce pb/annee est
    # toujours valide. Plutot que de conserver silencieusement une valeur non
    # revalidee, on l'efface et on force le brouillon.
    warn(
      "Registre inaccessible ({.url pb/index.json}) — vérification \\
       impossible : {.code pb}/{.code annee} effacés de {.file _quarto.yml} \\
       et {.code draft: true} forcé. Relancer une fois le registre accessible.")
    tryCatch({
      lines <- readLines(qyml_path, warn = FALSE)
      lines <- yaml_patch_scalar(lines, "draft", TRUE)
      lines <- yaml_patch_delete(lines, "annee")
      lines <- yaml_patch_delete(lines, "pb")
      writeLines(lines, qyml_path)
    }, error = function(e)
      warn(
        "Clés {.code draft}/{.code pb}/{.code annee} non écrites dans \\
         {.file _quarto.yml} : {conditionMessage(e)}"))
    return(list(
      stage = TRUE, registry_entry = NULL,
      source_repo = source_repo, network_error = TRUE
    ))
  }

  registry_entry <- NULL
  stage <- if (!is.na(source_repo)) {
    matched <- Filter(
      function(e) identical(e$type, "repo") && identical(e[["source-repo"]], source_repo),
      entries
    )
    if (length(matched) > 0L) {
      registry_entry <- matched[[1L]]
      say("Dépôt {.val {source_repo}} enregistré — déploiement en production.")
      FALSE
    } else {
      warn(
        "Dépôt {.val {source_repo}} absent du registre — staging. ",
        "Lancer {.run ofceweb::pb_registry_request()} pour demander un numéro.")
      TRUE
    }
  } else {
    warn("Remote {.code origin} introuvable ou non reconnu — staging par défaut.")
    TRUE
  }

  tryCatch({
    lines <- readLines(qyml_path, warn = FALSE)
    lines <- yaml_patch_scalar(lines, "draft", stage)
    if (!is.null(registry_entry)) {
      lines <- yaml_patch_scalar(lines, "annee", as.integer(registry_entry$annee))
      lines <- yaml_patch_scalar(lines, "pb", as.integer(registry_entry$pb))
    } else {
      lines <- yaml_patch_delete(lines, "annee")
      lines <- yaml_patch_delete(lines, "pb")
    }
    writeLines(lines, qyml_path)
  }, error = function(e)
    warn(
      "Clés {.code draft}/{.code pb}/{.code annee} non écrites dans \\
       {.file _quarto.yml} : {conditionMessage(e)}"))

  list(
    stage = stage, registry_entry = registry_entry,
    source_repo = source_repo, network_error = FALSE
  )
}
