#' Lit les entrées du registre central PB (`pb/pb.json`)
#'
#' Télécharge `pb/pb.json` (lecture publique, non authentifiée) du dépôt
#' registre central. Les PB partagent le même dépôt que les WP
#' (`ofce/wp-registry`) — sous le sous-dossier `pb/`, distinct de `wp/` — il
#' n'existe pas de dépôt `pb-registry` séparé.
#'
#' Contrairement au registre WP (sharded par année, `wp/{annee}.json`), le
#' registre PB est un **fichier plat unique** : les numéros PB sont attribués
#' de manière strictement séquentielle depuis l'origine, indépendamment de
#' l'année de publication — l'année n'a donc aucune valeur d'indexation ici.
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Liste d'entrées (`registry$pb`), ou `NULL` si `pb/pb.json` est
#'   inaccessible (registre indisponible, ou pas encore créé).
#' @keywords internal
#' @noRd
fetch_pb_registry <- function(registry_repo = "ofce/wp-registry") {
  registry_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/pb/pb.json", registry_repo)
  tryCatch(
    jsonlite::fromJSON(registry_url, simplifyVector = FALSE)$pb,
    error = function(e) NULL
  )
}

#' Toutes les entrées du registre PB
#'
#' Équivalent PB de [fetch_wp_entries()]. Le registre PB étant un fichier
#' plat unique (`pb/pb.json`), il n'y a rien à fusionner : cette fonction est
#' un simple alias de [fetch_pb_registry()], conservé sous ce nom pour que
#' [sync_pb_registry_state()] et [pb_registry_request()] restent stables face
#' à un éventuel retour au sharding.
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Liste d'entrées, ou `NULL` si `pb/pb.json` est inaccessible.
#' @keywords internal
#' @noRd
fetch_pb_entries <- function(registry_repo = "ofce/wp-registry") {
  fetch_pb_registry(registry_repo)
}

#' Consulte le registre central PB et synchronise `draft`/`pb`
#'
#' Équivalent PB de [sync_wp_registry_state()]. Interroge le sous-dossier
#' `pb/` de `ofce/wp-registry` (via [fetch_pb_entries()]) pour savoir si le
#' dépôt courant a une entrée confirmée (`type == "repo"` avec `source-repo`
#' correspondant au remote `origin` local). Le résultat (`stage = FALSE` si
#' publié, `TRUE` si staging) est écrit dans la clé `draft` de `_quarto.yml`
#' (lue par `ofce-quarto-extensions` pour le bandeau « Version provisoire »),
#' et la clé `pb` est synchronisée depuis l'entrée trouvée (dépôt publié) ou
#' effacée (staging, pas encore de numéro attribué). Le champ `annee` n'est
#' plus utilisé pour les PB (numérotation strictement séquentielle depuis
#' l'origine, indépendante de l'année) : il n'est ni lu ni écrit ici.
#'
#' Les PB partagent le même dépôt registre que les WP (`ofce/wp-registry`) —
#' sous `pb/`, distinct de `wp/` — il n'existe pas de dépôt `pb-registry`
#' séparé.
#'
#' En cas d'échec de consultation du registre (réseau, `pb/pb.json`
#' inaccessible), l'état ne peut pas être vérifié -- la fonction force alors
#' `draft: true` et efface `pb` de `_quarto.yml`, même pour un dépôt déjà
#' publié : une vérification impossible ne doit jamais être traitée comme
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
      "Registre inaccessible ({.url pb/pb.json}) — vérification \\
       impossible : {.code pb} effacé de {.file _quarto.yml} et \\
       {.code draft: true} forcé. Relancer une fois le registre accessible.")
    tryCatch({
      lines <- readLines(qyml_path, warn = FALSE)
      lines <- yaml_patch_scalar(lines, "draft", TRUE)
      lines <- yaml_patch_delete(lines, "pb")
      writeLines(lines, qyml_path)
    }, error = function(e)
      warn(
        "Clés {.code draft}/{.code pb} non écrites dans {.file _quarto.yml} : \\
         {conditionMessage(e)}"))
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
      lines <- yaml_patch_scalar(lines, "pb", as.integer(registry_entry$pb))
    } else {
      lines <- yaml_patch_delete(lines, "pb")
    }
    writeLines(lines, qyml_path)
  }, error = function(e)
    warn(
      "Clés {.code draft}/{.code pb} non écrites dans {.file _quarto.yml} : \\
       {conditionMessage(e)}"))

  list(
    stage = stage, registry_entry = registry_entry,
    source_repo = source_repo, network_error = FALSE
  )
}
