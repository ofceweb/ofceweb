#' Vérifie la structure d'un dépôt de document de travail (WP)
#'
#' Inspecte le `_quarto.yml` et les fichiers `.qmd` à la racine du dépôt pour
#' détecter les problèmes bloquants (erreurs) et les situations à corriger
#' (warnings) avant un rendu ou un déploiement.
#'
#' Contrôles effectués :
#' \itemize{
#'   \item Présence et validité de `_quarto.yml` (champs `annee`, `author`,
#'     `date`, `citation` — erreur bloquante si absents)
#'   \item `index.qmd` présent, déclare `wp-html` et `wp-pdf` / `wp-typst`
#'   \item `references.bib` présent (warning)
#'   \item `news.qmd` présent (warning)
#'   \item Si WP publié (`wp` non nul) : `annee` entier valide, cohérence
#'     `version` / dernier segment de `site-path`
#'   \item Tous les `.qmd` non-index référencés dans `website.other-links`
#'     (warning)
#'   \item Unicité des `output-file` PDF à travers tous les `.qmd` (erreur)
#' }
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param verbose Logique. Si `TRUE` (défaut), affiche les diagnostics avec
#'   [cli::cli_alert_success()], [cli::cli_alert_warning()] et
#'   [cli::cli_alert_danger()].
#'
#' @returns Un data frame (invisible) à trois colonnes : `field` (chr), `status`
#'   (`"ok"`, `"warning"`, `"error"`) et `message` (chr). [render_wp()] appelle
#'   cette fonction et abandonne si des erreurs bloquantes sont présentes.
#' @seealso [render_wp()], [setup_wp()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists dir_ls path_ext_remove path_rel
#' @importFrom cli cli_h1 cli_alert_success cli_alert_warning cli_alert_danger cli_rule cli_alert_info
#' @importFrom yaml read_yaml
#' @importFrom glue glue
#' @section Working Paper (WP) Users:
#'
#' @export
check_wp <- function(path = ".", verbose = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  diags <- list()

  add_diag <- function(field, status, message) {
    n <- length(diags) + 1L
    if(as.character(message) |> is.null())
      browser()
    diags[[n]] <<- list(
      field   = as.character(field),
      status  = as.character(status),
      message = as.character(message)
    )
  }

  if (verbose) cli::cli_h1("check_wp : {fs::path_file(root)}")

  # ---- _quarto.yml ---------------------------------------------------------
  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path)) {
    add_diag("_quarto.yml", "error", "Fichier absent. Lancer setup_wp() d'abord.")
    df <- if (length(diags) > 0) {
      data.frame(
        field   = sapply(diags, `[[`, "field"),
        status  = sapply(diags, `[[`, "status"),
        message = sapply(diags, `[[`, "message"),
        stringsAsFactors = FALSE
      )
    } else {
      data.frame(field = character(), status = character(), message = character(), stringsAsFactors = FALSE)
    }
    if (verbose) print_wp_diags(df, root)
    return(invisible(df))
  }

  yml <- tryCatch(yaml::read_yaml(yml_path),
                  error = function(e) {
                    add_diag("_quarto.yml", "error",
                             paste0("Impossible de lire le YAML : ", conditionMessage(e)))
                    NULL
                  })
  if (is.null(yml)) {
    df <- if (length(diags) > 0) {
      data.frame(
        field   = sapply(diags, `[[`, "field"),
        status  = sapply(diags, `[[`, "status"),
        message = sapply(diags, `[[`, "message"),
        stringsAsFactors = FALSE
      )
    } else {
      data.frame(field = character(), status = character(), message = character(), stringsAsFactors = FALSE)
    }
    if (verbose) print_wp_diags(df, root)
    return(invisible(df))
  }

  if (!isTRUE(yml$ofce_wp)) {
    add_diag("ofce_wp", "warning",
             "Champ `ofce_wp: true` absent — ce dépôt n'a peut-être pas été initialisé via setup_wp().")
  }

  # Champs obligatoires dans _quarto.yml
  # (annee sera vérifié plus précisément si WP publié)
  for (field in c("date", "citation")) {
    if (is.null(yml[[field]])) {
      add_diag(field, "error", sprintf("Champ `%s` absent de _quarto.yml.", field))
    } else {
      add_diag(field, "ok", sprintf("Champ `%s` présent.", field))
    }
  }

  # annee : vérification basique d'abord
  if (is.null(yml$annee)) {
    add_diag("annee", "error", "Champ `annee` absent de _quarto.yml.")
  }

  # wp : doit être fourni quand annee est fourni
  if (!is.null(yml$annee) && is.null(yml$wp)) {
    add_diag("wp", "error",
             "Champ `annee` renseigné mais `wp` absent de _quarto.yml — numéro du WP manquant ?")
  }

  if (is.null(yml$author) && is.null(yml$authors)) {
    add_diag("author", "error", "Champ `author` absent de _quarto.yml.")
  } else {
    add_diag("author", "ok", "Champ `author` présent.")
  }

  # ---- index.qmd -----------------------------------------------------------
  idx_path <- fs::path(root, "index.qmd")
  if (!fs::file_exists(idx_path)) {
    add_diag("index.qmd", "error", "index.qmd absent.")
  } else {
    add_diag("index.qmd", "ok", "index.qmd présent.")

    idx_yml <- tryCatch(get_yaml(idx_path), error = function(e) NULL)
    project_formats <- names(yml$format)
    idx_formats     <- names(if (!is.null(idx_yml)) idx_yml$format else NULL)
    all_formats     <- union(project_formats, idx_formats)

    if ("wp-html" %in% all_formats) {
      add_diag("format:wp-html", "ok", "Format wp-html déclaré.")
    } else {
      add_diag("format:wp-html", "error", "Format wp-html non déclaré (ni dans _quarto.yml ni dans index.qmd).")
    }

    has_pdf <- any(c("wp-pdf", "wp-typst") %in% all_formats)
    if (has_pdf) {
      pdf_fmt <- intersect(c("wp-pdf", "wp-typst"), all_formats)[[1]]
      add_diag("format:pdf", "ok", sprintf("Format PDF déclaré : %s.", pdf_fmt))
    } else {
      add_diag("format:pdf", "error",
               "Aucun format PDF (wp-pdf ou wp-typst) déclaré (ni dans _quarto.yml ni dans index.qmd).")
    }
  }

  # ---- references.bib (warning) --------------------------------------------
  if (fs::file_exists(fs::path(root, "references.bib"))) {
    add_diag("references.bib", "ok", "references.bib présent.")
  } else {
    add_diag("references.bib", "warning", "references.bib absent — les citations ne fonctionneront pas.")
  }

  # ---- news.qmd (warning) --------------------------------------------------
  if (fs::file_exists(fs::path(root, "news.qmd"))) {
    add_diag("news.qmd", "ok", "news.qmd présent.")
  } else {
    add_diag("news.qmd", "warning", "news.qmd absent — pas d'historique des révisions.")
  }

  # ---- .github/workflows (error) -----------------------------------------
  workflows_dir <- fs::path(root, ".github", "workflows")
  if (fs::dir_exists(workflows_dir)) {
    ftp_deploy_path <- fs::path(workflows_dir, "ftp_deploy.yml")
    if (fs::file_exists(ftp_deploy_path)) {
      add_diag(".github/workflows", "ok", ".github/workflows/ et ftp_deploy.yml présents.")
    } else {
      add_diag(".github/workflows", "error",
               ".github/workflows/ présent mais ftp_deploy.yml absent — lancer setup_wp() d'abord.")
    }
  } else {
    add_diag(".github/workflows", "error",
             ".github/workflows/ absent — lancer setup_wp() d'abord.")
  }

  # ---- Contrôles spécifiques WP publié -------------------------------------
  if (!is.null(yml$wp)) {
    # annee : validation plus stricte pour WP publié
    if (!is.null(yml$annee)) {
      annee_ok <- !is.na(suppressWarnings(as.integer(yml$annee))) &&
                  as.integer(yml$annee) > 1990L
      if (annee_ok) {
        add_diag("annee", "ok", sprintf("annee = %s valide pour un WP publié.", yml$annee))
      } else {
        add_diag("annee", "error",
                 sprintf("annee `%s` invalide pour un WP publié (entier > 1990 attendu).", yml$annee))
      }
    }

    # site-path : présence et cohérence structurelle (wp/YYYY/NNN[/vX])
    sp      <- yml$website$`site-path`
    version <- if (!is.null(yml$version)) as.character(yml$version) else NULL

    if (is.null(sp) || !nzchar(sp)) {
      add_diag("site-path", "error",
               "WP publié (wp non nul) mais site-path absent de _quarto.yml.")
    } else {
      segs <- strsplit(sp, "/", fixed = TRUE)[[1]]
      n    <- length(segs)

      # Structure attendue : YYYY/NNN  ou  YYYY/NNN/vX
      struct_ok <- n %in% c(2L, 3L)

      if (!struct_ok) {
        add_diag("site-path", "error",
                 sprintf(
                   "site-path `%s` mal formé — attendu : `YYYY/NNN` ou `YYYY/NNN/vX`.",
                   sp))
      } else {
        # Segment YYYY
        annee_seg <- suppressWarnings(as.integer(segs[1L]))
        annee_yml <- suppressWarnings(as.integer(yml$annee))
        if (!is.na(annee_seg) && !is.na(annee_yml) && annee_seg == annee_yml) {
          add_diag("site-path/annee", "ok",
                   sprintf("Segment année `%s` cohérent avec annee.", segs[1L]))
        } else {
          add_diag("site-path/annee", "error",
                   sprintf(
                     "Segment année `%s` dans site-path incohérent avec annee = `%s`.",
                     segs[1L], yml$annee))
        }

        # Segment NNN
        wp_seg <- suppressWarnings(as.integer(segs[2L]))
        wp_yml <- suppressWarnings(as.integer(yml$wp))
        if (!is.na(wp_seg) && !is.na(wp_yml) && wp_seg == wp_yml) {
          add_diag("site-path/wp", "ok",
                   sprintf("Segment numéro WP `%s` cohérent avec wp.", segs[2L]))
        } else {
          add_diag("site-path/wp", "error",
                   sprintf(
                     "Segment numéro WP `%s` dans site-path incohérent avec wp = `%s`.",
                     segs[2L], yml$wp))
        }

        # Segment version (optionnel)
        if (!is.null(version) && nzchar(version)) {
          if (n == 3L) {
            if (identical(segs[3L], version)) {
              add_diag("site-path/version", "ok",
                       sprintf("Segment version `%s` cohérent avec version.", segs[3L]))
            } else {
              add_diag("site-path/version", "error",
                       sprintf(
                         "Segment version `%s` dans site-path incohérent avec version = `%s`.",
                         segs[3L], version))
            }
          } else {
            # n == 2 : version définie dans le YAML mais absente du chemin
            add_diag("site-path/version", "warning",
                     sprintf(
                       "version `%s` définie dans le YAML mais absente de site-path `%s`.",
                       version, sp))
          }
        } else if (n == 3L) {
          # segment version présent dans le chemin mais yml$version absent
          add_diag("site-path/version", "warning",
                   sprintf(
                     "Segment version `%s` présent dans site-path mais `version` absente du YAML.",
                     segs[3L]))
        }
      }
    }
  }

  # ---- .qmd non-index : référencés dans other-links ? ---------------------
  all_qmds <- fs::dir_ls(root, glob = "*.qmd", type = "file")
  all_qmds <- all_qmds[!grepl("^_", fs::path_file(all_qmds))]

  other_qmds <- all_qmds[
    !tolower(fs::path_file(all_qmds)) %in% c("index.qmd")
  ]

  other_links <- yml$website$`other-links`
  other_links_stems <- vapply(
    if (is.null(other_links)) list() else other_links,
    function(x) {
      href <- x$href
      if (is.null(href) || !nzchar(href)) return("")
      # strip possible absolute URL prefix, keep filename stem
      href_file <- sub(".*[/\\\\]", "", href)
      fs::path_ext_remove(href_file)
    },
    character(1L)
  )

  for (qmd in other_qmds) {
    stem <- fs::path_ext_remove(fs::path_file(qmd))
    if (stem %in% other_links_stems) {
      add_diag(fs::path_file(qmd), "ok",
               sprintf("%s référencé dans website.other-links.", fs::path_file(qmd)))
    } else {
      add_diag(fs::path_file(qmd), "warning",
               sprintf("%s non référencé dans website.other-links (page inaccessible depuis la navigation).",
                       fs::path_file(qmd)))
    }
  }

  # ---- unicité des output-file PDF ----------------------------------------
  all_pdf_outputs <- character()

  # project-level
  if (!is.null(yml$format)) {
    for (fmt in c("wp-pdf", "wp-typst")) {
      fmt_val <- yml$format[[fmt]]
      if (is.list(fmt_val)) {
        of <- fmt_val$`output-file`
        if (!is.null(of) && nzchar(of)) all_pdf_outputs <- c(all_pdf_outputs, of)
      }
    }
  }

  # document-level
  for (qmd in all_qmds) {
    qy <- tryCatch(get_yaml(qmd), error = function(e) NULL)
    if (is.null(qy) || !is.list(qy) || is.null(qy$format) || !is.list(qy$format)) next
    for (fmt in c("wp-pdf", "wp-typst")) {
      fmt_val <- qy$format[[fmt]]
      if (is.list(fmt_val)) {
        of <- fmt_val$`output-file`
        if (!is.null(of) && nzchar(of)) all_pdf_outputs <- c(all_pdf_outputs, of)
      }
    }
  }

  dupes <- all_pdf_outputs[duplicated(all_pdf_outputs)]
  if (length(dupes) == 0L) {
    if (length(all_pdf_outputs) > 0L)
      add_diag("output-file", "ok",
               sprintf("output-file PDF unique : %s.", paste(all_pdf_outputs, collapse = ", ")))
  } else {
    add_diag("output-file", "error",
             sprintf("output-file en double détecté : %s.", paste(unique(dupes), collapse = ", ")))
  }

  # ---- Résumé --------------------------------------------------------------
  df <- if (length(diags) > 0) {
    tdiag <- purrr::transpose(diags)
    data.frame(
      field   = tdiag[["field"]] |> unlist(),
      status  = tdiag[["status"]] |> unlist(),
      message = tdiag[["message"]] |> unlist(),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(field = character(), status = character(), message = character(), stringsAsFactors = FALSE)
  }

  if (verbose) print_wp_diags(df, root)

  invisible(df)
}

# Affiche les diagnostics check_wp() dans la console.
print_wp_diags <- function(df, root = NULL) {
  if (nrow(df) == 0L) return(invisible(NULL))

  cli::cli_rule("Diagnostics check_wp()")
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
  } else {
    cli::cli_alert_success(
      "Aucune erreur bloquante. {n_warn} avertissement{?s}.")
  }

  # Build the path parameter for suggestions
  run_path <- if (!is.null(root) && !identical(root, getwd())) {
    fs::path_rel(root, getwd())
  } else {
    "."
  }

  # Check if .github/workflows is missing and suggest setup_wp()
  workflows_missing <- df[df$field == ".github/workflows" & df$status == "error", ]
  if (nrow(workflows_missing) > 0L) {
    cli::cli_rule()
    msg <- glue::glue("Dossier .github/workflows/ manquant. Exécutez {{.run setup_wp('{run_path}')}} pour initialiser le dépôt.")
    cli::cli_alert_info(msg)
    return(invisible(NULL))
  }

  # Check if there are missing required fields and suggest complete_wp_yaml()
  missing_required_fields <- c("date", "annee", "author", "citation")
  rows_missing <- df[df$field %in% missing_required_fields & df$status == "error", ]

  if (nrow(rows_missing) > 0L) {
    cli::cli_rule()
    msg <- glue::glue("Des champs obligatoires manquent. Exécutez {{.run complete_wp_yaml('{run_path}')}} pour les remplir automatiquement.")
    cli::cli_alert_info(msg)
  }

  invisible(NULL)
}
