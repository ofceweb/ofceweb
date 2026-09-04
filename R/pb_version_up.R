#' Incrémente la version d'un policy brief OFCE publié
#'
#' Équivalent PB de [wp_version_up()]. Lit le champ `version` dans
#' `_quarto.yml`, l'incrémente (`"v0"` → `"v1"`, `"v3_4"` → `"v3_5"`, etc.),
#' met à jour `_quarto.yml` (champ `version` et dernier segment de `site-path`),
#' met à jour les variables GitHub Actions `FTP_SERVER_DIR`/`FTP_REDIRECT_DIR`
#' et régénère `manifest.json`.
#'
#' Ne fonctionne que pour un PB publié (`pb` non nul dans `_quarto.yml`).
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
#' @export
pb_version_up <- function(path = ".", custom_version = NULL) {
  root <- fs::path_abs(fs::path_expand(path))
  yml_path <- fs::path(root, "_quarto.yml")

  if (!fs::file_exists(yml_path)) {
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")
  }

  yml <- yaml::read_yaml(yml_path)

  if (!isTRUE(yml$ofce_pb)) {
    cli::cli_abort(
      "{.fun pb_version_up} ne fonctionne que sur un dépôt initialisé via \\
       {.run ofceweb::setup_pb()} ({.code ofce_pb: true} absent)."
    )
  }

  if (is.null(yml$pb)) {
    cli::cli_abort(
      "Ce PB est encore un brouillon ({.code pb: null}). \\
       Définir d'abord le numéro PB dans {.file _quarto.yml} avant d'incrémenter la version."
    )
  }

  if (is.null(yml$version)) {
    current_version <- "∅"
    new_version <- "v0"
  } else {
    current_version <- as.character(yml$version)

    if (!grepl("^[A-Za-z0-9_]+$", current_version)) {
      cli::cli_abort(
        "La version courante {.val {current_version}} contient des caractères \\
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

  # Mise à jour du dernier segment de site-path
  sp <- yml$website$`site-path` |> as.character()
  new_site_path <- NULL
  if (!is.null(sp) && nzchar(sp)) {
    segs <- strsplit(sp, "/", fixed = TRUE)[[1]]
    segs[length(segs)] <- new_version
    new_site_path <- paste(segs, collapse = "/")
    lines <- yaml_patch_scalar(lines, "website.site-path", new_site_path)
  } else {
    cli::cli_alert_warning(
      "site-path absent ou vide dans {.file _quarto.yml} — non mis à jour."
    )
  }

  writeLines(lines, yml_path)
  cli::cli_alert_success(
    "version mise à jour : {.val {current_version}} → {.val {new_version}}"
  )
  cli::cli_alert_info("Nouveau site-path : {.val {new_site_path}}")

  # Mise à jour des variables GitHub FTP_SERVER_DIR et FTP_REDIRECT_DIR
  if (!is.null(sp) && nzchar(sp)) {
    tryCatch(
      {
        server_dir <- if (grepl("/$", new_site_path)) {
          new_site_path
        } else {
          paste0(new_site_path, "/")
        }
        server_dir_clean <- sub("/$", "", server_dir)
        redirect_dir <- if (grepl("/v\\d+$", server_dir_clean)) {
          paste0(sub("/v\\d+$", "", server_dir_clean), "/")
        } else {
          paste0(server_dir_clean, "/")
        }
        set_gh_var(root, "FTP_SERVER_DIR", server_dir)
        set_gh_var(root, "FTP_REDIRECT_DIR", redirect_dir)
      },
      error = function(e) {
        cli::cli_alert_warning(
          "Variables GitHub non mises à jour : {conditionMessage(e)}"
        )
      }
    )
  }

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
