#' Incrémente la version staging d'une prévision OFCE
#'
#' Lit le champ `version` dans `_quarto-staging.yml`, l'incrémente
#' (`"v0"` → `"v1"`, `"v3"` → `"v4"`, etc.), met à jour `_quarto-staging.yml`
#' (champ `version` et dernier segment de `site-path`), puis synchronise la
#' variable GitHub Actions `FTP_STAGING_DIR`.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param custom_version Chaîne ou `NULL` (défaut). Si non `NULL`, force la
#'   version à cette valeur exacte (alphanumériques + underscores, ex.
#'   `"v2_rc"`). Sinon, auto-incrémente le dernier chiffre.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [setup_prev()], [check_prev()]
#' @importFrom fs path_abs path_expand path file_exists
#' @importFrom cli cli_abort cli_alert_success cli_alert_info cli_alert_warning
#' @importFrom yaml read_yaml
#' @export
prev_version_up <- function(path = ".", custom_version = NULL) {

  root     <- fs::path_abs(fs::path_expand(path))
  yml_path <- fs::path(root, "_quarto.yml")
  stg_path <- fs::path(root, "_quarto-staging.yml")

  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")
  if (!fs::file_exists(stg_path))
    cli::cli_abort(
      "Pas de {.file _quarto-staging.yml} dans {.path {root}}. \\
       Lancer {.run ofceweb::setup_prev()} d'abord.")

  yml_top <- yaml::read_yaml(yml_path)
  if (!isTRUE(yml_top$ofce_prev))
    cli::cli_abort(
      "{.fun prev_version_up} ne fonctionne que sur un dépôt initialisé via \\
       {.run ofceweb::setup_prev()} ({.code ofce_prev: true} absent).")

  stg <- yaml::read_yaml(stg_path)

  current_version <- if (!is.null(stg$version)) as.character(stg$version) else "v0"

  if (!grepl("^[A-Za-z0-9_]+$", current_version))
    cli::cli_abort(
      "La version courante {.val {current_version}} contient des caractères \\
       interdits. Utiliser {.arg custom_version} pour forcer une version.")

  new_version <- increment_version_str(current_version, custom = custom_version)

  # Mise à jour de _quarto-staging.yml : patch textuel préservant commentaires
  # et mise en page (yaml::read_yaml()/write_yaml() ne fait pas de round-trip
  # fidèle du fichier).
  stg_lines <- readLines(stg_path, warn = FALSE)
  stg_lines <- yaml_patch_scalar(stg_lines, "version", new_version)

  sp <- as.character(stg$website$`site-path` %||% "")
  new_sp <- NULL
  if (nzchar(sp)) {
    segs         <- strsplit(sp, "/", fixed = TRUE)[[1]]
    segs[length(segs)] <- new_version
    new_sp <- paste(segs, collapse = "/")
    stg_lines <- yaml_patch_scalar(stg_lines, "website.site-path", new_sp)
  } else {
    cli::cli_alert_warning(
      "site-path absent de {.file _quarto-staging.yml} — non mis à jour.")
  }

  writeLines(stg_lines, stg_path)

  cli::cli_alert_success(
    "Version staging : {.val {current_version}} \u2192 {.val {new_version}}")
  cli::cli_alert_info(
    "Nouveau site-path staging : {.val {new_sp}}")

  # Mise à jour de la variable GitHub FTP_STAGING_DIR
  if (!is.null(new_sp) && nzchar(new_sp)) {
    staging_dir <- if (grepl("/$", new_sp)) new_sp else paste0(new_sp, "/")
    staging_dir <- stringr::str_remove(staging_dir, "^staging/")
    tryCatch(
      set_gh_var(root, "FTP_STAGING_DIR", staging_dir),
      error = function(e)
        cli::cli_alert_warning("FTP_STAGING_DIR non mise à jour : {conditionMessage(e)}")
    )
  }

  invisible(NULL)
}
