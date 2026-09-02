#' Consulte le registre central et synchronise `draft`/`wp`/`annee`
#'
#' Interroge `ofceweb/wp-registry` (via [fetch_wp_entries()]) pour savoir si
#' le dépôt courant a une entrée confirmée (`type == "repo"` avec
#' `source-repo` correspondant au remote `origin` local). Le résultat
#' (`stage = FALSE` si publié, `TRUE` si staging) est écrit dans la clé
#' `draft` de `_quarto.yml` (lue par `ofce-quarto-extensions` pour le
#' bandeau « Version provisoire »), et les clés `wp`/`annee` sont
#' synchronisées depuis l'entrée trouvée (dépôt publié) ou effacées
#' (staging, pas encore de numéro attribué) — leur valeur n'est jamais
#' laissée à la charge de l'auteur·e une fois le dépôt enregistré.
#'
#' En cas d'échec de consultation du registre (réseau, `wp/index.json`
#' inaccessible), l'état ne peut pas être vérifié -- la fonction force
#' alors `draft: true` et efface `wp`/`annee` de `_quarto.yml`, même pour
#' un dépôt déjà publié : une vérification impossible ne doit jamais être
#' traitée comme une confirmation implicite du statu quo, sous peine de
#' publier en production un WP dont le numéro n'a en réalité pas pu être
#' revalidé. La fonction retourne `network_error = TRUE` pour que les
#' appelants ([setup_wp()], [publish_wp()]) puissent avertir
#' l'utilisateur·rice et l'inviter à relancer l'opération une fois le
#' registre de nouveau accessible.
#'
#' Utilisée par [setup_wp()] (pour que `_quarto.yml` soit déjà correct après
#' l'appel) et par [publish_wp()] (pour rattraper un enregistrement survenu
#' entre le dernier `setup_wp()` et la publication).
#'
#' @param root Chemin vers la racine du dépôt. Défaut `"."`.
#' @param quiet Logique. Si `TRUE`, supprime les messages `cli`. Défaut
#'   `FALSE`.
#' @return Liste `list(stage, registry_entry, source_repo, network_error)`.
#'   Si `network_error` est `TRUE`, `stage` vaut `TRUE` (brouillon forcé) et
#'   `wp`/`annee` ont été effacés de `_quarto.yml` -- l'état n'a pas pu être
#'   vérifié et n'est donc jamais traité comme publié.
#' @keywords internal
#' @noRd
sync_wp_registry_state <- function(root = ".", quiet = FALSE) {
  qyml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(qyml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  say <- function(...) if (!quiet) cli::cli_alert_success(...)
  warn <- function(...) if (!quiet) cli::cli_alert_warning(...)

  source_repo <- tryCatch(gh_slug_from_remote(root), error = function(e) NA_character_)
  entries     <- fetch_wp_entries()

  if (is.null(entries)) {
    # Verification impossible : on ne peut pas garantir que ce wp/annee
    # est toujours valide (ex. numero repris entre-temps, depot jamais
    # enregistre). Plutot que de conserver silencieusement une valeur non
    # revalidee, on l'efface et on force le brouillon -- evite qu'un WP non
    # verifie soit deploye en production (deploy_wp() route sur stage/wp).
    warn(
      "Registre inaccessible ({.url wp/index.json}) — vérification \\
       impossible : {.code wp}/{.code annee} effacés de {.file _quarto.yml} \\
       et {.code draft: true} forcé. Relancer une fois le registre accessible.")
    tryCatch({
      lines <- readLines(qyml_path, warn = FALSE)
      lines <- yaml_patch_scalar(lines, "draft", TRUE)
      lines <- yaml_patch_delete(lines, "annee")
      lines <- yaml_patch_delete(lines, "wp")
      writeLines(lines, qyml_path)
    }, error = function(e)
      warn(
        "Clés {.code draft}/{.code wp}/{.code annee} non écrites dans \\
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
      say("D\u00e9p\u00f4t {.val {source_repo}} enregistr\u00e9 \u2014 d\u00e9ploiement en production.")
      FALSE
    } else {
      warn(
        "D\u00e9p\u00f4t {.val {source_repo}} absent du registre \u2014 staging. ",
        "Lancer {.run ofceweb::wp_registry_request()} pour demander un num\u00e9ro.")
      TRUE
    }
  } else {
    warn("Remote {.code origin} introuvable ou non reconnu \u2014 staging par d\u00e9faut.")
    TRUE
  }

  tryCatch({
    lines <- readLines(qyml_path, warn = FALSE)
    lines <- yaml_patch_scalar(lines, "draft", stage)
    if (!is.null(registry_entry)) {
      lines <- yaml_patch_scalar(lines, "annee", as.integer(registry_entry$annee))
      lines <- yaml_patch_scalar(lines, "wp", as.integer(registry_entry$wp))
    } else {
      lines <- yaml_patch_delete(lines, "annee")
      lines <- yaml_patch_delete(lines, "wp")
    }
    writeLines(lines, qyml_path)
  }, error = function(e)
    warn(
      "Cl\u00e9s {.code draft}/{.code wp}/{.code annee} non \u00e9crites dans \\
       {.file _quarto.yml} : {conditionMessage(e)}"))

  list(
    stage = stage, registry_entry = registry_entry,
    source_repo = source_repo, network_error = FALSE
  )
}
