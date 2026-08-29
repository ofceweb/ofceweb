#' Vérifie la structure d'un dépôt de prévision OFCE
#'
#' Inspecte les fichiers de configuration (`_quarto.yml`,
#' `_quarto-staging.yml`, `_quarto-publish.yml`), la structure de dossiers, et
#' les ressources GitHub Actions pour détecter les problèmes bloquants avant
#' un rendu ou un déploiement.
#'
#' Contrôles effectués :
#' \enumerate{
#'   \item Nom du dossier conforme à `prev{YY}0{3|9}` (ex. `prev2603`)
#'   \item Présence des sous-dossiers `france/`, `inter/`, `fiches/`,
#'     `tableaux_comptes/`, `data_pays/`
#'   \item `_quarto.yml` présent et lisible
#'   \item Marqueur `ofce_prev: true` présent
#'   \item Champs `prev`, `annee`, `mois` présents dans `_quarto.yml`
#'   \item `project.type: ofce-website` présent dans `_quarto.yml`
#'   \item Section `profile` de `_quarto.yml` : `default: staging` et groupe
#'     `[staging, publish]` (avertissements non bloquants si modifiés) ; vérifie
#'     que les fichiers `_quarto-{profil}.yml` existent pour chaque profil déclaré
#'   \item `_quarto-staging.yml` présent avec `version`, `site-url:
#'     https://staging.ofce.fr/`, `site-path` de la forme `prev{YYMM}/v{N}`,
#'     `encrypt_site: true`, `comments.hypothesis: true`, et
#'     `project.output-dir: _site_staging`
#'   \item `_quarto-publish.yml` présent avec `site-path` de la forme
#'     `prev/prev{YYMM}`, `encrypt_site: false`, `comments.hypothesis: false`,
#'     et `project.output-dir: _site_publish`
#'   \item Cohérence du `prev` id entre `_quarto.yml` et les deux profils
#'   \item `.github/workflows/ftp_deploy_staging.yml` présent
#'   \item `.github/workflows/ftp_deploy_publish.yml` présent
#'   \item `.github/workflows/ftp_deploy_profile.yml` présent
#'   \item Variables GitHub `FTP_STAGING_DIR` et `FTP_PUBLISH_DIR` définies
#'     (vérification via `gh` CLI, avec fallback silencieux si absent)
#'   \item Secret GitHub `STATICRYPT_PASSWORD` défini (warning non bloquant —
#'     le rendu local fonctionne sans lui, mais le workflow CI staging
#'     échouera)
#'   \item Connexion GitHub (`gh::gh("GET /user")`) — warning non bloquant si
#'     non authentifié
#' }
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param verbose Logique. Si `TRUE` (défaut), affiche les diagnostics avec
#'   [cli::cli_alert_success()], [cli::cli_alert_warning()] et
#'   [cli::cli_alert_danger()].
#'
#' @returns Un data frame (invisible) à trois colonnes : `field` (chr),
#'   `status` (`"ok"`, `"warning"`, `"error"`) et `message` (chr).
#' @seealso [setup_prev()], [render_prev()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists
#' @importFrom cli cli_h1 cli_alert_success cli_alert_warning cli_alert_danger cli_rule
#' @importFrom yaml read_yaml
#' @importFrom gh gh
#' @export
check_prev <- function(path = ".", verbose = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  diags <- list()

  add_diag <- function(field, status, message) {
    n <- length(diags) + 1L
    diags[[n]] <<- list(
      field   = as.character(field),
      status  = as.character(status),
      message = as.character(message)
    )
  }

  if (verbose) cli::cli_h1("check_prev : {fs::path_file(root)}")

  # ---- connexion GitHub -----------------------------------------------------
  gh_login <- check_gh_login(verbose = FALSE)
  if (!is.na(gh_login)) {
    add_diag("gh:login", "ok",
             sprintf("Connecté à GitHub en tant que @%s.", gh_login))
  } else {
    add_diag("gh:login", "warning",
             "Non connecté à GitHub (gh::gh('GET /user') a échoué). Les opérations staging et registry seront indisponibles.")
  }

  # ---- 1. Nom du dossier ---------------------------------------------------
  project <- fs::path_file(root) |> as.character()
  if (grepl("^prev[0-9]{2}0[39]$", project)) {
    add_diag("nom dossier", "ok",
             sprintf("Nom `%s` conforme (prev{YY}0{3|9}).", project))
  } else {
    add_diag("nom dossier", "error",
             sprintf("Nom `%s` non conforme — attendu : prev{YY}0{3|9} (ex. prev2603, prev2609).", project))
  }

  # ---- 2. Sous-dossiers obligatoires ---------------------------------------
  for (sub in c("france", "inter", "fiches", "tableaux_comptes", "data_pays")) {
    if (fs::dir_exists(fs::path(root, sub))) {
      add_diag(sprintf("dossier %s/", sub), "ok",
               sprintf("Sous-dossier `%s/` présent.", sub))
    } else {
      add_diag(sprintf("dossier %s/", sub), "error",
               sprintf("Sous-dossier `%s/` absent.", sub))
    }
  }

  # ---- 3. _quarto.yml présent et lisible -----------------------------------
  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path)) {
    add_diag("_quarto.yml", "error",
             "_quarto.yml absent. Lancer setup_prev() d'abord.")
    return(prev_diag_df(diags, verbose))
  }

  yml <- tryCatch(yaml::read_yaml(yml_path), error = function(e) {
    add_diag("_quarto.yml", "error",
             paste0("Impossible de lire le YAML : ", conditionMessage(e)))
    NULL
  })
  if (is.null(yml)) return(prev_diag_df(diags, verbose))

  add_diag("_quarto.yml", "ok", "_quarto.yml présent et lisible.")

  # ---- 4. Marqueur ofce_prev: true -----------------------------------------
  if (isTRUE(yml$ofce_prev)) {
    add_diag("ofce_prev", "ok", "Marqueur `ofce_prev: true` présent.")
  } else {
    add_diag("ofce_prev", "warning",
             "`ofce_prev: true` absent — dépôt non initialisé via setup_prev() ?")
  }

  # ---- 5. Champs prev, annee, mois -----------------------------------------
  for (field in c("prev", "annee", "mois")) {
    if (!is.null(yml[[field]])) {
      add_diag(field, "ok",
               sprintf("Champ `%s` présent : %s.", field, yml[[field]]))
    } else {
      add_diag(field, "error",
               sprintf("Champ `%s` absent de _quarto.yml.", field))
    }
  }

  # ---- 5b. project.type: ofce-website ---------------------------------------
  if (identical(yml$project$type, "ofce-website")) {
    add_diag("project.type", "ok",
             "`project.type: ofce-website` présent dans _quarto.yml.")
  } else {
    add_diag("project.type", "warning",
             sprintf("`project.type` vaut `%s` — attendu `ofce-website`. Lancer setup_prev().",
                     yml$project$type %||% "(absent)"))
  }

  # ---- 5c. profile: default staging, group [staging, publish] (non bloquant)
  prof_default <- yml$profile$default
  prof_group   <- as.character(unlist(yml$profile$group))

  if (is.null(prof_default)) {
    add_diag("profile/default", "warning",
             "`profile.default` absent de _quarto.yml — attendu `staging`.")
  } else if (!identical(prof_default, "staging")) {
    add_diag("profile/default", "warning",
             sprintf("`profile.default` vaut `%s` (modifié) — attendu `staging`.", prof_default))
  } else {
    add_diag("profile/default", "ok",
             "`profile.default: staging` présent dans _quarto.yml.")
  }

  missing_in_group <- setdiff(c("staging", "publish"), prof_group)
  if (length(missing_in_group) > 0L) {
    add_diag("profile/group", "warning",
             sprintf("Profil(s) manquant(s) dans `profile.group` : %s — attendu [staging, publish].",
                     paste(missing_in_group, collapse = ", ")))
  } else {
    add_diag("profile/group", "ok",
             "`profile.group` contient bien `staging` et `publish`.")
  }

  # Pour chaque profil déclaré, vérifie que le fichier _quarto-{profil}.yml existe
  for (pname in intersect(prof_group, c("staging", "publish"))) {
    pfile <- fs::path(root, sprintf("_quarto-%s.yml", pname))
    if (!fs::file_exists(pfile)) {
      add_diag(sprintf("profile/%s/fichier", pname), "warning",
               sprintf("`%s` déclaré dans `profile.group` mais `_quarto-%s.yml` introuvable.",
                       pname, pname))
    }
  }

  prev_id <- as.character(yml$prev %||% "")

  # ---- 6. _quarto-staging.yml ----------------------------------------------
  stg_path <- fs::path(root, "_quarto-staging.yml")
  stg <- NULL
  if (!fs::file_exists(stg_path)) {
    add_diag("_quarto-staging.yml", "error",
             "_quarto-staging.yml absent. Lancer setup_prev() d'abord.")
  } else {
    stg <- tryCatch(yaml::read_yaml(stg_path), error = function(e) NULL)
    if (is.null(stg)) {
      add_diag("_quarto-staging.yml", "error",
               "Impossible de lire _quarto-staging.yml.")
    } else {
      add_diag("_quarto-staging.yml", "ok",
               "_quarto-staging.yml présent et lisible.")

      # version
      if (!is.null(stg$version)) {
        add_diag("staging/version", "ok",
                 sprintf("Champ `version` présent : %s.", stg$version))
      } else {
        add_diag("staging/version", "error",
                 "Champ `version` absent de _quarto-staging.yml.")
      }

      # site-path forme prev{YYMM}/v{N} (servi depuis le sous-domaine
      # staging.ofce.fr, sans préfixe "staging/")
      sp_stg <- stg$website$`site-path`
      if (is.null(sp_stg)) {
        add_diag("staging/site-path", "error",
                 "Champ `site-path` absent de _quarto-staging.yml.")
      } else if (!grepl("^prev[0-9]{4}/v[0-9]+", sp_stg)) {
        add_diag("staging/site-path", "error",
                 sprintf("`site-path` staging `%s` mal formé — attendu : prev{YYMM}/v{N}.", sp_stg))
      } else {
        add_diag("staging/site-path", "ok",
                 sprintf("`site-path` staging `%s` bien formé.", sp_stg))
      }

      # site-url attendu : https://staging.ofce.fr/
      su_stg <- stg$website$`site-url`
      if (is.null(su_stg)) {
        add_diag("staging/site-url", "error",
                 "Champ `site-url` absent de _quarto-staging.yml.")
      } else if (!identical(sub("/$", "", su_stg), "https://staging.ofce.fr")) {
        add_diag("staging/site-url", "error",
                 sprintf("`site-url` staging `%s` inattendu — attendu https://staging.ofce.fr/.", su_stg))
      } else {
        add_diag("staging/site-url", "ok",
                 "`site-url: https://staging.ofce.fr/` présent dans _quarto-staging.yml.")
      }

      # encrypt_site: true
      if (isTRUE(stg$encrypt_site)) {
        add_diag("staging/encrypt_site", "ok",
                 "`encrypt_site: true` présent dans _quarto-staging.yml.")
      } else {
        add_diag("staging/encrypt_site", "warning",
                 "`encrypt_site: true` absent — le site staging ne sera pas chiffré en CI.")
      }

      # comments.hypothesis: true
      if (isTRUE(stg$comments$hypothesis)) {
        add_diag("staging/comments", "ok",
                 "`comments.hypothesis: true` présent dans _quarto-staging.yml.")
      } else {
        add_diag("staging/comments", "warning",
                 "`comments.hypothesis: true` absent de _quarto-staging.yml.")
      }

      # project/output-dir: _site_staging
      out_stg <- stg$project$`output-dir`
      if (!is.null(out_stg) && out_stg == "_site_staging") {
        add_diag("staging/output-dir", "ok",
                 "`project.output-dir: _site_staging` présent dans _quarto-staging.yml.")
      } else {
        add_diag("staging/output-dir", "error",
                 sprintf("`project.output-dir` vaut `%s` — attendu `_site_staging`.",
                         out_stg %||% "(absent)"))
      }
    }
  }

  # ---- 7. _quarto-publish.yml ----------------------------------------------
  pub_path <- fs::path(root, "_quarto-publish.yml")
  pub <- NULL
  if (!fs::file_exists(pub_path)) {
    add_diag("_quarto-publish.yml", "error",
             "_quarto-publish.yml absent. Lancer setup_prev() d'abord.")
  } else {
    pub <- tryCatch(yaml::read_yaml(pub_path), error = function(e) NULL)
    if (is.null(pub)) {
      add_diag("_quarto-publish.yml", "error",
               "Impossible de lire _quarto-publish.yml.")
    } else {
      add_diag("_quarto-publish.yml", "ok",
               "_quarto-publish.yml présent et lisible.")

      sp_pub <- pub$website$`site-path`
      if (is.null(sp_pub)) {
        add_diag("publish/site-path", "error",
                 "Champ `site-path` absent de _quarto-publish.yml.")
      } else if (!grepl("^prev/prev[0-9]{4}$", sp_pub)) {
        add_diag("publish/site-path", "error",
                 sprintf("`site-path` publish `%s` mal formé — attendu : prev/prev{YYMM}.", sp_pub))
      } else {
        add_diag("publish/site-path", "ok",
                 sprintf("`site-path` publish `%s` bien formé.", sp_pub))
      }

      # encrypt_site: false
      if (isFALSE(pub$encrypt_site)) {
        add_diag("publish/encrypt_site", "ok",
                 "`encrypt_site: false` présent dans _quarto-publish.yml.")
      } else {
        add_diag("publish/encrypt_site", "error",
                 sprintf("`encrypt_site` vaut `%s` dans _quarto-publish.yml — doit être `false`.",
                         pub$encrypt_site %||% "(absent)"))
      }

      # comments.hypothesis: false
      if (isFALSE(pub$comments$hypothesis)) {
        add_diag("publish/comments", "ok",
                 "`comments.hypothesis: false` présent dans _quarto-publish.yml.")
      } else {
        add_diag("publish/comments", "warning",
                 sprintf("`comments.hypothesis` vaut `%s` dans _quarto-publish.yml — attendu `false`.",
                         pub$comments$hypothesis %||% "(absent)"))
      }

      # project/output-dir: _site_publish
      out_pub <- pub$project$`output-dir`
      if (!is.null(out_pub) && out_pub == "_site_publish") {
        add_diag("publish/output-dir", "ok",
                 "`project.output-dir: _site_publish` présent dans _quarto-publish.yml.")
      } else {
        add_diag("publish/output-dir", "error",
                 sprintf("`project.output-dir` vaut `%s` — attendu `_site_publish`.",
                         out_pub %||% "(absent)"))
      }
    }
  }

  # ---- 8. Cohérence prev id ------------------------------------------------
  if (nzchar(prev_id)) {
    if (!is.null(stg)) {
      sp_stg <- stg$website$`site-path`
      if (!is.null(sp_stg)) {
        m <- regmatches(sp_stg, regexec("^prev([0-9]{4})/", sp_stg))[[1]]
        if (length(m) >= 2L) {
          stg_id <- m[[2L]]
          if (identical(stg_id, prev_id)) {
            add_diag("cohérence/staging", "ok",
                     sprintf("prev id `%s` cohérent avec site-path staging.", prev_id))
          } else {
            add_diag("cohérence/staging", "error",
                     sprintf("prev id `%s` incohérent avec site-path staging (extrait : `%s`).",
                             prev_id, stg_id))
          }
        }
      }
    }

    if (!is.null(pub)) {
      sp_pub <- pub$website$`site-path`
      if (!is.null(sp_pub)) {
        m <- regmatches(sp_pub, regexec("prev/prev([0-9]{4})$", sp_pub))[[1]]
        if (length(m) >= 2L) {
          pub_id <- m[[2L]]
          if (identical(pub_id, prev_id)) {
            add_diag("cohérence/publish", "ok",
                     sprintf("prev id `%s` cohérent avec site-path publish.", prev_id))
          } else {
            add_diag("cohérence/publish", "error",
                     sprintf("prev id `%s` incohérent avec site-path publish (extrait : `%s`).",
                             prev_id, pub_id))
          }
        }
      }
    }
  }

  # ---- 9. .github/workflows/ftp_deploy_staging.yml ------------------------
  wf_stg <- fs::path(root, ".github", "workflows", "ftp_deploy_staging.yml")
  if (fs::file_exists(wf_stg)) {
    add_diag("ftp_deploy_staging.yml", "ok",
             "Workflow FTP staging présent.")
  } else {
    add_diag("ftp_deploy_staging.yml", "error",
             ".github/workflows/ftp_deploy_staging.yml absent. Lancer setup_prev() d'abord.")
  }

  # ---- 10. .github/workflows/ftp_deploy_publish.yml -----------------------
  wf_pub <- fs::path(root, ".github", "workflows", "ftp_deploy_publish.yml")
  if (fs::file_exists(wf_pub)) {
    add_diag("ftp_deploy_publish.yml", "ok",
             "Workflow FTP publish présent.")
  } else {
    add_diag("ftp_deploy_publish.yml", "error",
             ".github/workflows/ftp_deploy_publish.yml absent. Lancer setup_prev() d'abord.")
  }

  # ---- 10b. .github/workflows/ftp_deploy_profile.yml ----------------------
  wf_prof <- fs::path(root, ".github", "workflows", "ftp_deploy_profile.yml")
  if (fs::file_exists(wf_prof)) {
    add_diag("ftp_deploy_profile.yml", "ok",
             "Workflow FTP profils personnalisés présent.")
  } else {
    add_diag("ftp_deploy_profile.yml", "warning",
             ".github/workflows/ftp_deploy_profile.yml absent — les profils personnalisés ne pourront pas être déployés en CI. Lancer setup_prev() pour l'ajouter.")
  }

  # ---- 11. Variables GitHub FTP_STAGING_DIR et FTP_PUBLISH_DIR ------------
  gh_ok <- nzchar(Sys.which("gh"))
  if (gh_ok) {
    tryCatch({
      vars_raw  <- system2("gh", c("variable", "list", "--json", "name"),
                           stdout = TRUE, stderr = FALSE)
      vars_list <- tryCatch(
        jsonlite::fromJSON(paste(vars_raw, collapse = ""))$name,
        error = function(e) character()
      )
      for (var_name in c("FTP_STAGING_DIR", "FTP_PUBLISH_DIR")) {
        if (var_name %in% vars_list) {
          add_diag(var_name, "ok",
                   sprintf("Variable GitHub `%s` définie.", var_name))
        } else {
          add_diag(var_name, "error",
                   sprintf("Variable GitHub `%s` non définie — lancer setup_prev().", var_name))
        }
      }
    }, error = function(e) {
      add_diag("gh variables", "warning",
               "Impossible de vérifier les variables GitHub (gh CLI non authentifié ?).")
    })
  } else {
    add_diag("gh variables", "warning",
             "gh CLI non disponible — variables GitHub non vérifiées.")
  }

  # ---- 12. Secret STATICRYPT_PASSWORD (non bloquant) ----------------------
  if (gh_ok) {
    tryCatch({
      sec_raw   <- system2("gh", c("secret", "list", "--json", "name"),
                           stdout = TRUE, stderr = FALSE)
      sec_list  <- tryCatch(
        jsonlite::fromJSON(paste(sec_raw, collapse = ""))$name,
        error = function(e) character()
      )
      if ("STATICRYPT_PASSWORD" %in% sec_list) {
        add_diag("STATICRYPT_PASSWORD", "ok",
                 "Secret GitHub `STATICRYPT_PASSWORD` défini.")
      } else {
        add_diag("STATICRYPT_PASSWORD", "warning",
                 "Secret `STATICRYPT_PASSWORD` non défini — le workflow CI staging échouera. Définir : gh secret set STATICRYPT_PASSWORD")
      }
    }, error = function(e) {
      add_diag("STATICRYPT_PASSWORD", "warning",
               "Impossible de vérifier le secret STATICRYPT_PASSWORD.")
    })
  } else {
    add_diag("STATICRYPT_PASSWORD", "warning",
             "gh CLI non disponible — secret STATICRYPT_PASSWORD non vérifié.")
  }

  prev_diag_df(diags, verbose, root)
}

# ---------------------------------------------------------------------------
# Helpers internes check_prev
# ---------------------------------------------------------------------------

prev_diag_df <- function(diags, verbose, root = NULL) {
  df <- if (length(diags) > 0L) {
    data.frame(
      field   = vapply(diags, `[[`, character(1L), "field"),
      status  = vapply(diags, `[[`, character(1L), "status"),
      message = vapply(diags, `[[`, character(1L), "message"),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(field = character(), status = character(),
               message = character(), stringsAsFactors = FALSE)
  }
  if (verbose) print_prev_diags(df, root)
  invisible(df)
}

print_prev_diags <- function(df, root = NULL) {
  if (nrow(df) == 0L) return(invisible(NULL))

  cli::cli_rule("Diagnostics check_prev()")
  for (i in seq_len(nrow(df))) {
    switch(df$status[i],
      "error"   = cli::cli_alert_danger(
        "{.strong {df$field[i]}} : {df$message[i]}"),
      "warning" = cli::cli_alert_warning(
        "{df$field[i]} : {df$message[i]}"),
      cli::cli_alert_success(
        "{df$field[i]} : {df$message[i]}")
    )
  }

  n_err  <- sum(df$status == "error")
  n_warn <- sum(df$status == "warning")
  cli::cli_rule()
  if (n_err > 0L) {
    cli::cli_alert_danger(
      "{n_err} erreur{?s} bloquante{?s}, {n_warn} avertissement{?s}.")
    run_path <- if (!is.null(root) && !identical(root, getwd()))
      fs::path_rel(root, getwd()) else "."
    cli::cli_alert_info(
      "Exécuter {.run ofceweb::setup_prev('{run_path}')} pour corriger la configuration.")
  } else {
    cli::cli_alert_success(
      "Aucune erreur bloquante. {n_warn} avertissement{?s}.")
  }
  invisible(NULL)
}
