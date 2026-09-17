#' Incrémente la version d'un policy brief OFCE publié
#'
#' Équivalent PB de [wp_version_up()]. Lit le champ `version` dans
#' `_quarto.yml`, l'incrémente (`"v0"` → `"v1"`, `"v3_4"` → `"v3_5"`, etc.),
#' met à jour `_quarto.yml` (champ `version` et dernier segment de `site-path`),
#' met à jour les variables GitHub Actions
#' `FTP_SERVER_DIR`/`FTP_REDIRECT_DIR`/`FTP_STAGING_DIR` et régénère
#' `manifest.json`.
#'
#' Fonctionne aussi bien pour un PB publié (`pb` non nul) que pour un
#' brouillon (`pb` encore `null`) : voir [wp_version_up()] pour le détail du
#' traitement (identique, au champ `pb`/`wp` près).
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
      "{.fun pb_version_up} ne fonctionne que sur un dépôt initialisé via \\
       {.run ofceweb::setup_pb()} ({.code ofce_pb: true} absent)."
    )
  }

  is_draft <- is.null(yml$pb)

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

  if (!is_draft) {
    # PB publié : la version vit dans le dernier segment de site-path.
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
    # website.site-url porte déjà le segment de version — on le met à jour à
    # l'identique. Un brouillon gh-pages n'a pas de segment de version dans
    # son site-url : rien à faire là.
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
  # (PB publié uniquement).
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
  # ou publié (cf. setup_pb()).
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
