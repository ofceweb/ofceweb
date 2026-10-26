#' Lit l'index des séries PB du registre central (`pb/index.json`)
#'
#' Télécharge `pb/index.json` (lecture publique, non authentifiée) du dépôt
#' registre central (`ofce/wp-registry`, sous-dossier `pb/`). L'index est la
#' seule source des séries PB existantes et de leurs paramètres : aucune série
#' n'est codée en dur dans ofceweb.
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Liste nommée (clé = identifiant de série) dont chaque élément est
#'   une liste avec `open`, `label`, `path-prefix`, `pdf-prefix`,
#'   `draft-prefix`, `container-title` ; `NULL` en cas d'échec (réseau, JSON
#'   invalide, clé `series` absente).
#' @keywords internal
#' @noRd
fetch_pb_series_index <- function(registry_repo = "ofce/wp-registry") {
  index_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/pb/index.json", registry_repo)
  tryCatch({
    series <- jsonlite::fromJSON(index_url, simplifyVector = FALSE)[["series"]]
    if (is.list(series) && length(series) > 0L && !is.null(names(series))) series else NULL
  }, error = function(e) NULL)
}

#' Série PB d'un `_quarto.yml`
#'
#' Lit la clé `pb_series` (indépendante de `institut`, qui ne sert qu'au
#' logo). Un dépôt sans cette clé est traité comme appartenant à la série
#' historique `"ofce"`.
#'
#' @param yml Liste issue de `yaml::read_yaml("_quarto.yml")`.
#' @return Chaîne de longueur 1, en minuscules et sans espaces superflus.
#' @keywords internal
#' @noRd
pb_series <- function(yml) {
  s <- yml[["pb_series"]]
  if (is.null(s) || length(s) != 1L || is.na(s) || !nzchar(trimws(as.character(s))))
    return("ofce")
  tolower(trimws(as.character(s)))
}

#' Lit les entrées du registre central PB (`pb/{série}.json`)
#'
#' Télécharge l'index des séries (`pb/index.json`), puis `pb/{série}.json`
#' pour chaque série listée (lecture publique, non authentifiée) du dépôt
#' registre central. Les PB partagent le même dépôt que les WP
#' (`ofce/wp-registry`) -- sous le sous-dossier `pb/`, distinct de `wp/` --
#' il n'existe pas de dépôt `pb-registry` séparé.
#'
#' Chaque série est numérotée à partir de 1 dans son propre fichier,
#' indépendamment de l'année de publication. L'ancien fichier plat
#' `pb/pb.json` est figé et n'est plus lu.
#'
#' Si l'index ou un seul fichier de série est inaccessible, le registre est
#' considéré comme indisponible (`NULL`) : traiter un échec comme une liste
#' vide ferait proposer le numéro 1 par [pb_registry_request()].
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @param index Index des séries déjà téléchargé ([fetch_pb_series_index()]),
#'   ou `NULL` pour le télécharger.
#' @return Liste d'entrées de toutes les séries, chacune portant `pb_series`
#'   (le nom du fichier fait foi), ou `NULL` si le registre est indisponible.
#' @keywords internal
#' @noRd
fetch_pb_registry <- function(registry_repo = "ofce/wp-registry", index = NULL) {
  if (is.null(index)) index <- fetch_pb_series_index(registry_repo)
  if (is.null(index)) return(NULL)

  out <- list()
  for (s in names(index)) {
    url <- sprintf(
      "https://raw.githubusercontent.com/%s/main/pb/%s.json", registry_repo, s)
    pb_list <- tryCatch(
      jsonlite::fromJSON(url, simplifyVector = FALSE)[["pb"]] %||% list(),
      error = function(e) NULL
    )
    if (is.null(pb_list)) return(NULL)
    for (e in pb_list) {
      e[["pb_series"]] <- s
      out[[length(out) + 1L]] <- e
    }
  }
  out
}

#' Toutes les entrées du registre PB
#'
#' Équivalent PB de [fetch_wp_entries()] : alias de [fetch_pb_registry()],
#' conservé sous ce nom pour que [sync_pb_registry_state()] et
#' [pb_registry_request()] restent stables.
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Liste d'entrées (toutes séries), ou `NULL` si le registre est
#'   inaccessible.
#' @keywords internal
#' @noRd
fetch_pb_entries <- function(registry_repo = "ofce/wp-registry") {
  fetch_pb_registry(registry_repo)
}

#' Consulte le registre central PB et synchronise `draft`/`pb`
#'
#' Équivalent PB de [sync_wp_registry_state()]. Interroge le sous-dossier
#' `pb/` de `ofce/wp-registry` (index des séries + un fichier par série, via
#' [fetch_pb_entries()]) pour savoir si le
#' dépôt courant a une entrée confirmée (`type == "repo"` avec `source-repo`
#' correspondant au remote `origin` local). Le résultat (`stage = FALSE` si
#' publié, `TRUE` si staging) est écrit dans la clé `draft` de `_quarto.yml`
#' (lue par `ofce-quarto-extensions` pour le bandeau « Version provisoire »),
#' et les clés `pb` et `pb_series` sont synchronisées depuis l'entrée trouvée
#' (dépôt publié, toutes séries confondues -- le registre fait foi ; un
#' avertissement signale une `pb_series` locale corrigée). En staging (pas
#' encore de numéro attribué), `pb` est effacé et `pb_series` laissé tel quel
#' (choix de l'auteur·e). Le champ `annee` n'est ni lu ni écrit ici
#' (numérotation par série, indépendante de l'année).
#'
#' Les PB partagent le même dépôt registre que les WP (`ofce/wp-registry`) —
#' sous `pb/`, distinct de `wp/` — il n'existe pas de dépôt `pb-registry`
#' séparé.
#'
#' En cas d'échec de consultation du registre (réseau, `pb/index.json` ou
#' `pb/{série}.json` inaccessible), l'état ne peut pas être vérifié -- la
#' fonction force alors `draft: true` et efface `pb` de `_quarto.yml`
#' (`pb_series` n'est pas touché), même pour un dépôt déjà publié : une vérification impossible ne doit jamais être traitée comme
#' une confirmation implicite du statu quo. La fonction retourne
#' `network_error = TRUE` pour que les appelants ([setup_pb()], [publish_pb()])
#' puissent avertir l'utilisateur·rice.
#'
#' @param root Chemin vers la racine du dépôt. Défaut `"."`.
#' @param quiet Logique. Si `TRUE`, supprime les messages `cli`. Défaut
#'   `FALSE`.
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#'   Défaut `"ofce/wp-registry"`.
#' @return Liste `list(stage, registry_entry, source_repo, network_error,
#'   pb_series)` (`pb_series` : série de l'entrée du registre, sinon `NULL`).
#'   Si `network_error` est `TRUE`, `stage` vaut `TRUE` (brouillon forcé) et
#'   `pb` a été effacé de `_quarto.yml`.
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
    # Verification impossible : on ne peut pas garantir que ce pb est
    # toujours valide. Plutot que de conserver silencieusement une valeur non
    # revalidee, on l'efface et on force le brouillon.
    warn(
      "Registre inaccessible ({.url pb/index.json}) — vérification \\
       impossible : {.code pb} effacé de {.file _quarto.yml} et \\
       {.code draft: true} forcé. Relancer une fois le registre accessible.")
    tryCatch({
      lines <- readLines(qyml_path, warn = FALSE)
      lines <- yaml_patch_scalar(lines, "draft", TRUE)
      lines <- yaml_patch_delete(lines, "pb")
      writeLines(lines, qyml_path)
    }, error = function(e)
      warn(
        "Clés {.code draft}/{.code pb}/{.code pb_series} non écrites dans {.file _quarto.yml} : \\
         {conditionMessage(e)}"))
    return(list(
      stage = TRUE, registry_entry = NULL,
      source_repo = source_repo, network_error = TRUE, pb_series = NULL
    ))
  }

  registry_entry <- NULL
  stage <- if (!is.na(source_repo)) {
    matched <- Filter(
      function(e) identical(e$type, "repo") && repo_slug_equal(e[["source-repo"]], source_repo),
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

  # Le registre fait foi pour la serie comme pour le numero.
  reg_series <- if (!is.null(registry_entry)) registry_entry[["pb_series"]] else NULL
  if (!is.null(reg_series)) {
    local_series <- tryCatch(
      pb_series(yaml::read_yaml(qyml_path)), error = function(e) "ofce")
    if (!identical(local_series, reg_series))
      warn(
        "{.field pb_series} local ({.val {local_series}}) corrigé d'après le \\
         registre ({.val {reg_series}}) dans {.file _quarto.yml}.")
  }

  tryCatch({
    lines <- readLines(qyml_path, warn = FALSE)
    lines <- yaml_patch_scalar(lines, "draft", stage)
    if (!is.null(registry_entry)) {
      lines <- yaml_patch_scalar(lines, "pb", as.integer(registry_entry$pb))
      if (!is.null(reg_series))
        lines <- yaml_patch_scalar(lines, "pb_series", reg_series)
    } else {
      lines <- yaml_patch_delete(lines, "pb")
    }
    writeLines(lines, qyml_path)
  }, error = function(e)
    warn(
      "Clés {.code draft}/{.code pb}/{.code pb_series} non écrites dans {.file _quarto.yml} : \\
       {conditionMessage(e)}"))

  list(
    stage = stage, registry_entry = registry_entry,
    source_repo = source_repo, network_error = FALSE, pb_series = reg_series
  )
}
