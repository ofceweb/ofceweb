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
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists dir_ls path_ext_remove
#' @importFrom cli cli_h1 cli_alert_success cli_alert_warning cli_alert_danger cli_rule
#' @importFrom yaml read_yaml
#' @export
check_wp <- function(path = ".", verbose = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  diags <- list()

  add_diag <- function(field, status, message) {
    diags[[length(diags) + 1L]] <<- data.frame(
      field   = as.character(field),
      status  = as.character(status),
      message = as.character(message),
      stringsAsFactors = FALSE
    )
  }

  if (verbose) cli::cli_h1("check_wp : {fs::path_file(root)}")

  # ---- _quarto.yml ---------------------------------------------------------
  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path)) {
    add_diag("_quarto.yml", "error", "Fichier absent. Lancer setup_wp() d'abord.")
    df <- do.call(rbind, diags)
    if (verbose) print_wp_diags(df)
    return(invisible(df))
  }

  yml <- tryCatch(yaml::read_yaml(yml_path),
                  error = function(e) {
                    add_diag("_quarto.yml", "error",
                             paste0("Impossible de lire le YAML : ", conditionMessage(e)))
                    NULL
                  })
  if (is.null(yml)) {
    df <- do.call(rbind, diags)
    if (verbose) print_wp_diags(df)
    return(invisible(df))
  }

  if (!isTRUE(yml$ofce_wp)) {
    add_diag("ofce_wp", "warning",
             "Champ `ofce_wp: true` absent — ce dépôt n'a peut-être pas été initialisé via setup_wp().")
  }

  # Champs obligatoires dans _quarto.yml
  for (field in c("annee", "date", "citation")) {
    if (is.null(yml[[field]])) {
      add_diag(field, "error", sprintf("Champ `%s` absent de _quarto.yml.", field))
    } else {
      add_diag(field, "ok", sprintf("Champ `%s` présent.", field))
    }
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

  # ---- Contrôles spécifiques WP publié -------------------------------------
  if (!is.null(yml$wp)) {
    # annee doit être un entier valide
    annee_ok <- !is.null(yml$annee) &&
                !is.na(suppressWarnings(as.integer(yml$annee))) &&
                as.integer(yml$annee) > 1990L
    if (annee_ok) {
      add_diag("annee", "ok", sprintf("annee = %s valide pour un WP publié.", yml$annee))
    } else {
      add_diag("annee", "error",
               sprintf("annee `%s` invalide pour un WP publié (entier > 1990 attendu).", yml$annee))
    }

    # version cohérente avec dernier segment de site-path
    sp      <- yml$website$`site-path`
    version <- as.character(yml$version)
    if (!is.null(sp) && nzchar(sp) && !is.null(version)) {
      segs     <- strsplit(sp, "/", fixed = TRUE)[[1]]
      last_seg <- segs[length(segs)]
      if (identical(last_seg, version)) {
        add_diag("version/site-path", "ok",
                 sprintf("version `%s` cohérente avec site-path.", version))
      } else {
        add_diag("version/site-path", "error",
                 sprintf("version `%s` incohérente avec le dernier segment de site-path `%s`.",
                         version, last_seg))
      }
    } else if (is.null(sp) || !nzchar(sp)) {
      add_diag("site-path", "error",
               "WP publié (wp non nul) mais site-path absent de _quarto.yml.")
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
  for (fmt in c("wp-pdf", "wp-typst")) {
    of <- yml$format[[fmt]]$`output-file`
    if (!is.null(of) && nzchar(of)) all_pdf_outputs <- c(all_pdf_outputs, of)
  }

  # document-level
  for (qmd in all_qmds) {
    qy <- tryCatch(get_yaml(qmd), error = function(e) NULL)
    if (is.null(qy)) next
    for (fmt in c("wp-pdf", "wp-typst")) {
      of <- qy$format[[fmt]]$`output-file`
      if (!is.null(of) && nzchar(of)) all_pdf_outputs <- c(all_pdf_outputs, of)
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
  df <- do.call(rbind, diags)
  if (is.null(df)) df <- data.frame(field = character(), status = character(),
                                     message = character(), stringsAsFactors = FALSE)

  if (verbose) print_wp_diags(df)

  invisible(df)
}

# Affiche les diagnostics check_wp() dans la console.
print_wp_diags <- function(df) {
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
  invisible(NULL)
}
