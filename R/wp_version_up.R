#' Incrémente la version d'un document de travail OFCE publié
#'
#' Lit le champ `version` dans `_quarto.yml`, l'incrémente (`"v0"` → `"v1"`,
#' `"v3_4"` → `"v3_5"`, etc.), met à jour `_quarto.yml` (champ `version` et
#' dernier segment de `site-path`), met à jour la variable GitHub Actions
#' `FTP_SERVER_DIR` et régénère `manifest.json`.
#'
#' Ne fonctionne que pour un WP publié (`wp` non nul dans `_quarto.yml`).
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param custom_version Chaîne ou `NULL` (défaut). Si non `NULL`, force la
#'   version à cette valeur (alphanumériques + underscores uniquement, ex.
#'   `"v2_corr"`). Sinon, auto-incrémente le dernier chiffre de la version.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [setup_wp()], [site_version_up()]
#' @importFrom fs path_abs path_expand path file_exists
#' @importFrom cli cli_abort cli_alert_success cli_alert_info cli_alert_warning
#' @importFrom yaml read_yaml write_yaml verbatim_logical
#' @section Working Paper (WP) Users:
#'
#' @export
wp_version_up <- function(path = ".", custom_version = NULL) {
  root <- fs::path_abs(fs::path_expand(path))
  yml_path <- fs::path(root, "_quarto.yml")

  if (!fs::file_exists(yml_path)) {
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")
  }

  yml <- yaml::read_yaml(yml_path)

  if (!isTRUE(yml$ofce_wp)) {
    cli::cli_abort(
      "{.fun wp_version_up} ne fonctionne que sur un dépôt initialisé via \\
       {.run ofceweb::setup_wp()} ({.code ofce_wp: true} absent)."
    )
  }

  if (is.null(yml$wp)) {
    cli::cli_abort(
      "Ce WP est encore un brouillon ({.code wp: null}). \\
       Définir d'abord le numéro WP dans {.file _quarto.yml} avant d'incrémenter la version."
    )
  }

  if (is.null(yml$version)) {
    current_version <- "\u2205"
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

  # Mise à jour de _quarto.yml
  yml$version <- new_version

  # Mise à jour du dernier segment de site-path
  sp <- yml$website$`site-path` |> as.character()
  if (!is.null(sp) && nzchar(sp)) {
    segs <- strsplit(sp, "/", fixed = TRUE)[[1]]
    segs[length(segs)] <- new_version
    yml$website$`site-path` <- paste(segs, collapse = "/")
  } else {
    cli::cli_alert_warning(
      "site-path absent ou vide dans {.file _quarto.yml} — non mis à jour."
    )
  }

  yaml::write_yaml(
    yml,
    yml_path,
    indent.mapping.sequence = TRUE,
    handlers = list(logical = yaml::verbatim_logical)
  )
  cli::cli_alert_success(
    "version mise à jour : {.val {current_version}} → {.val {new_version}}"
  )
  cli::cli_alert_info("Nouveau site-path : {.val {yml$website$`site-path`}}")

  # Mise à jour des variables GitHub FTP_SERVER_DIR et FTP_REDIRECT_DIR
  if (!is.null(sp) && nzchar(sp)) {
    new_site_path <- yml$website$`site-path`
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
    wp_manifest(root),
    error = function(e) {
      cli::cli_alert_warning(
        "manifest.json non régénéré : {conditionMessage(e)}"
      )
    }
  )

  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Helper interne partagé : incrémenter une chaîne de version
# Exemples : "v0" -> "v1", "v3_4" -> "v3_5", "v5_AS42" -> "v5_AS43"
# Utilisé aussi par site_version_up().
# ---------------------------------------------------------------------------
increment_version_str <- function(v, custom = NULL) {
  if (!is.null(custom)) {
    if (
      !is.character(custom) ||
        length(custom) != 1L ||
        !nzchar(custom) ||
        !grepl("^[A-Za-z0-9_]+$", custom)
    ) {
      cli::cli_abort(
        "{.arg custom_version} doit être une chaîne alphanumérique \\
         (underscores autorisés, pas d'autres caractères spéciaux)."
      )
    }
    return(custom)
  }

  m <- regmatches(v, regexec("^(.*?)([0-9]+)([^0-9]*)$", v))[[1]]
  if (length(m) < 4L) {
    cli::cli_abort(
      "Impossible de détecter un numéro à incrémenter dans {.val {v}}. \\
       Utiliser {.arg custom_version} pour forcer une version."
    )
  }
  paste0(m[[2L]], as.integer(m[[3L]]) + 1L, m[[4L]])
}
