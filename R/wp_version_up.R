#' Incrémente la version d'un document de travail OFCE publié
#'
#' Lit le champ `version` dans `_quarto.yml`, l'incrémente (`"v0"` → `"v1"`,
#' `"v3_4"` → `"v3_5"`, etc.), met à jour `_quarto.yml` (champ `version` et
#' dernier segment de `site-path`), met à jour les variables GitHub Actions
#' `FTP_SERVER_DIR`/`FTP_STAGING_DIR` et régénère `manifest.json`.
#'
#' Fonctionne aussi bien pour un WP publié (`wp` non nul) que pour un
#' brouillon (`wp` encore `null`) : un brouillon a déjà une version de revue
#' (`_quarto.yml$version`, utilisée dans le nom du dossier de staging FTP et,
#' pour un brouillon en `stage-target: ftp`, dans `website.site-url`), qu'il
#' est légitime d'incrémenter avant même l'attribution d'un numéro WP. Pour
#' un WP publié, en plus de `version`, `website.site-path` (et les variables
#' `FTP_SERVER_DIR`/`FTP_REDIRECT_DIR` qui en dérivent) sont mis à jour ; pour
#' un brouillon, `website.site-path` n'existe pas — c'est `website.site-url`
#' (si elle contient déjà un segment de version, cas `stage-target: ftp`) qui
#' est mise à jour à la place. Dans les deux cas, `FTP_STAGING_DIR`
#' (toujours `{repo}/{version}/`, cf. [setup_wp()]) est recalculée.
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
#' @importFrom yaml read_yaml
#' @keywords internal
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

  is_draft <- is.null(yml$wp)

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

  # Mise à jour de _quarto.yml : patch textuel préservant commentaires et
  # mise en page (yaml::read_yaml()/write_yaml() ne fait pas de round-trip
  # fidèle du fichier).
  lines <- readLines(yml_path, warn = FALSE)
  lines <- yaml_patch_scalar(lines, "version", new_version)

  if (!is_draft) {
    # WP publié : la version vit dans le dernier segment de site-path.
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
  } else {
    # Brouillon : pas de site-path. Pour un brouillon en `stage-target: ftp`,
    # website.site-url porte déjà le segment de version
    # (https://staging.ofce.fr/{repo}/{version}/) — on le met à jour à
    # l'identique. Un brouillon gh-pages n'a pas de segment de version dans
    # son site-url (https://{org}.github.io/{repo}/) : rien à faire là.
    site_url <- as.character(yml$website$`site-url` %||% "")
    new_site_url <- NULL
    if (nzchar(site_url) && !identical(current_version, "\u2205") &&
        grepl(paste0("/", current_version, "/?$"), site_url)) {
      new_site_url <- sub(
        paste0("/", current_version, "/?$"),
        paste0("/", new_version, "/"),
        site_url
      )
      lines <- yaml_patch_scalar(lines, "website.site-url", new_site_url)
    }
  }

  writeLines(lines, yml_path)
  cli::cli_alert_success(
    "version mise à jour : {.val {current_version}} → {.val {new_version}}"
  )
  if (!is_draft) {
    cli::cli_alert_info("Nouveau site-path : {.val {new_site_path}}")
  } else if (!is.null(new_site_url)) {
    cli::cli_alert_info("Nouvelle site-url : {.val {new_site_url}}")
  } else {
    cli::cli_alert_info(
      "Brouillon sans segment de version dans website.site-url — inchangée."
    )
  }

  # Mise à jour des variables GitHub FTP_SERVER_DIR et FTP_REDIRECT_DIR
  # (WP publié uniquement — un brouillon n'est jamais déployé via
  # ftp_deploy.yml/FTP_SERVER_DIR, seulement via ftp_stage.yml/FTP_STAGING_DIR).
  if (!is_draft && !is.null(sp) && nzchar(sp)) {
    tryCatch(
      {
        server_dir <- if (grepl("/$", new_site_path)) {
          new_site_path
        } else {
          paste0(new_site_path, "/")
        }
        # Le dernier segment de new_site_path est par construction
        # `new_version` (cf. `segs` ci-dessus) -- on le retire directement
        # plutôt que par une regex numérique, qui échouerait sur une version
        # personnalisée (ex. "v2_corr", "v5_AS42").
        redirect_dir <- if (length(segs) > 1L) {
          paste0(paste(segs[-length(segs)], collapse = "/"), "/")
        } else {
          server_dir
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

  # Mise à jour de FTP_STAGING_DIR ({repo}/{version}/) — toujours, brouillon
  # ou publié (cf. setup_wp()) : c'est la destination utilisée par
  # ftp_stage.yml pour la revue avant enregistrement au registre central.
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
