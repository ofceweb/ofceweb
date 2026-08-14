#' Incrémente la version dans le `site-path` du `_quarto.yml`
#'
#' Lit le `_quarto.yml` à la racine du dépôt, repère le dernier segment du
#' `site-path` (la version) et l'incrémente. Si `custom_version` est fourni,
#' remplace simplement le segment de version par cette valeur. Sinon, détecte
#' la dernière séquence de chiffres dans le segment et l'augmente de 1
#' (ex. `v0` -> `v1`, `v3_4` -> `v3_5`, `v5_AS42` -> `v5_AS43`,
#' `v10_42A` -> `v10_43A`, `6v` -> `7v`). Met également à jour la variable
#' GitHub Actions `FTP_SERVER_DIR` avec le nouveau `site-path`.
#'
#' Ne fonctionne que si `ofce_host: true` est présent dans le `_quarto.yml`.
#' Les versions doivent être alphanumériques avec des underscores uniquement.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param custom_version Chaîne ou `NULL` (défaut). Si non `NULL`, remplace
#'   la version actuelle par cette valeur (validée : alphanumériques et
#'   underscores uniquement).
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [setup_site()]
#' @export
site_version_up <- function(path = ".", custom_version = NULL) {
  root <- fs::path_abs(fs::path_expand(path))
  yml_path <- fs::path(root, "_quarto.yml")

  if (!fs::file_exists(yml_path)) {
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")
  }

  yml <- yaml::read_yaml(yml_path)

  if (!isTRUE(yml$ofce_host)) {
    cli::cli_abort(
      "{.code site_version_up()} ne fonctionne que si {.code ofce_host: true} \\
       est défini dans le {.file _quarto.yml}."
    )
  }

  sp <- yml$website$`site-path`
  if (is.null(sp) || !nzchar(sp)) {
    cli::cli_abort(
      "Aucun {.code site-path} défini dans le {.file _quarto.yml}."
    )
  }

  segments <- strsplit(sp, "/", fixed = TRUE)[[1]]
  if (length(segments) < 1) {
    cli::cli_abort("{.code site-path} vide.")
  }

  current_version <- segments[length(segments)]

  if (!grepl("^[A-Za-z0-9_]+$", current_version)) {
    cli::cli_abort(
      "Le segment de version courant {.val {current_version}} contient des \\
       caractères interdits. Seuls les alphanumériques et underscores sont \\
       acceptés."
    )
  }

  new_version <- increment_version_str(current_version, custom = custom_version)

  segments[length(segments)] <- new_version
  new_sp <- paste(segments, collapse = "/")
  yml$website$`site-path` <- new_sp

  yaml::write_yaml(
    yml,
    yml_path,
    indent.mapping.sequence = TRUE,
    handlers = list(logical = yaml::verbatim_logical)
  )

  if (length(segments) >= 2) {
    server_dir <- paste(
      segments[(length(segments) - 1):length(segments)],
      collapse = "/"
    )
    set_gh_var(root, "FTP_SERVER_DIR", server_dir)
  }

  cli::cli_alert_success(
    "Version mise à jour : {.val {current_version}} -> {.val {new_version}}"
  )
  cli::cli_alert_info("Nouveau {.code site-path} : {.val {new_sp}}")

  rescan_site(path = root)
  push_site_redirect(path = root)

  invisible(NULL)
}
