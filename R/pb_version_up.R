#' Incrémente la version d'un policy brief OFCE en brouillon
#'
#' Équivalent PB de [wp_version_up()], limité aux brouillons. Lit le champ
#' `version` dans `_quarto.yml`, l'incrémente (`"v0"` → `"v1"`, `"v3_4"` →
#' `"v3_5"`, etc.), met à jour `_quarto.yml` (champ `version` et, pour un
#' brouillon en staging FTP, dernier segment de `website.site-url`), met à
#' jour la variable GitHub Actions `FTP_STAGING_DIR` et régénère
#' `manifest.json`.
#'
#' Seul un brouillon (`pb` encore `null`) est versionné. Un PB publié (`pb`
#' attribué par le registre) n'a plus de version : la fonction s'arrête avec
#' une erreur, une correction se faisant en redéployant à la même adresse
#' ([publish_pb()]).
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param custom_version Chaîne ou `NULL` (défaut). Si non `NULL`, force la
#'   version à cette valeur (alphanumériques + underscores uniquement). Sinon,
#'   auto-incrémente le dernier chiffre de la version.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [setup_pb()], [wp_version_up()], [site_version_up()]
#' @importFrom fs path_abs path_expand path file_exists
#' @importFrom cli cli_abort cli_alert_success cli_alert_info cli_alert_warning
#' @importFrom yaml read_yaml
#' @keywords internal
pb_version_up <- function(path = ".", custom_version = NULL) {
  root <- fs::path_abs(fs::path_expand(path))
  yml_path <- fs::path(root, "_quarto.yml")

  if (!fs::file_exists(yml_path)) {
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")
  }

  yml <- yaml::read_yaml(yml_path)

  if (!isTRUE(yml$ofce_pb)) {
    cli::cli_abort(
      "{.fun pb_version_up} ne fonctionne que sur un dépôt initialisé via \
       {.run ofceweb::setup_pb()} ({.code ofce_pb: true} absent)."
    )
  }

  if (!is.null(yml[["pb"]])) {
    cli::cli_abort(c(
      "Ce PB est publié ({.field pb} = {.val {yml[['pb']]}}) : un PB publié \
       n'a plus de version.",
      "i" = "Pour corriger le PB, redéployer à la même adresse avec \
             {.run ofceweb::publish_pb()}."
    ))
  }

  if (is.null(yml$version)) {
    current_version <- "∅"
    new_version <- "v0"
  } else {
    current_version <- as.character(yml$version)

    if (!grepl("^[A-Za-z0-9_]+$", current_version)) {
      cli::cli_abort(
        "La version courante {.val {current_version}} contient des caractères \
         interdits. Seuls les alphanumériques et underscores sont acceptés."
      )
    }

    new_version <- increment_version_str(
      current_version,
      custom = custom_version
    )
  }

  # Mise à jour de _quarto.yml : patch textuel préservant commentaires et
  # mise en page.
  lines <- readLines(yml_path, warn = FALSE)
  lines <- yaml_patch_scalar(lines, "version", new_version)

  # Brouillon : pas de site-path. Pour un brouillon en `stage-target: ftp`,
  # website.site-url porte déjà le segment de version — on le met à jour à
  # l'identique. Un brouillon gh-pages n'a pas de segment de version dans
  # son site-url : rien à faire là.
  site_url <- as.character(yml$website$`site-url` %||% "")
  new_site_url <- NULL
  if (nzchar(site_url) && !identical(current_version, "∅") &&
      grepl(paste0("/", current_version, "/?$"), site_url)) {
    new_site_url <- sub(
      paste0("/", current_version, "/?$"),
      paste0("/", new_version, "/"),
      site_url
    )
    lines <- yaml_patch_scalar(lines, "website.site-url", new_site_url)
  }

  writeLines(lines, yml_path)
  cli::cli_alert_success(
    "version mise à jour : {.val {current_version}} → {.val {new_version}}"
  )
  if (!is.null(new_site_url)) {
    cli::cli_alert_info("Nouvelle site-url : {.val {new_site_url}}")
  } else {
    cli::cli_alert_info(
      "Brouillon sans segment de version dans website.site-url — inchangée."
    )
  }

  # Mise à jour de FTP_STAGING_DIR ({repo}/{version}/) (cf. setup_pb()).
  tryCatch(
    {
      gh <- detect_gh_owner(root)
      repo_name <- if (!is.na(gh$repo)) gh$repo else fs::path_file(root)
      staging_dir <- sprintf("%s/%s/", repo_name, new_version)
      set_gh_var(root, "FTP_STAGING_DIR", staging_dir)
    },
    error = function(e) {
      cli::cli_alert_warning(
        "FTP_STAGING_DIR non mise à jour : {conditionMessage(e)}"
      )
    }
  )

  # Régénération du manifeste
  tryCatch(
    pb_manifest(root),
    error = function(e) {
      cli::cli_alert_warning(
        "manifest.json non régénéré : {conditionMessage(e)}"
      )
    }
  )

  invisible(NULL)
}
