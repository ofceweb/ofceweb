#' Initialise un dépôt de policy brief (PB) OFCE
#'
#' Équivalent PB de [setup_wp()]. Copie les gabarits embarqués dans le package
#' (`inst/setup_pb/`) à la racine du dépôt, initialise la branche `gh-pages`
#' pour la pré-publication, et adapte le `_quarto.yml` avec les métadonnées du
#' PB (titre, numéro, année, langue, URLs).
#'
#' La fonction est **non-destructive** pour les fichiers utilisateur : sur un
#' dépôt existant, les fichiers gabarits `.qmd` et scripts (dont `_quarto.yml`)
#' ne sont pas écrasés, et les champs YAML ne sont mis à jour que si l'argument
#' correspondant a été fourni explicitement. `repo-url`, `favicon` et
#' `ofce_pb: true` sont toujours positionnés. `website.site-url`/`site-path`
#' sont toujours (re)calculés dès que `pb` est non nul.
#'
#' En revanche, les **workflows GitHub Actions** (`.github/workflows/`) sont
#' **toujours mis à jour** depuis la version de référence du package.
#'
#' `pb` n'est **pas** un argument : il est soit lu depuis un `_quarto.yml`
#' déjà existant, soit écrasé par une entrée confirmée du registre central
#' (`ofce/wp-registry`, sous-dossier `pb/`), jamais choisi librement par
#' l'appelant. Un dépôt sans `_quarto.yml` et sans entrée de registre reste un
#' brouillon (`pb` absent) ; pour obtenir un numéro, utiliser
#' [pb_registry_request()] puis relancer `setup_pb()` une fois la PR
#' fusionnée. Le champ `annee` n'est pas utilisé pour les PB : les numéros
#' sont attribués séquentiellement depuis l'origine, indépendamment de
#' l'année de publication.
#'
#' Les extensions Quarto OFCE (`_extensions/`) sont installées/mises à jour via
#' [ofce::setup_quarto()], qui les récupère depuis le dépôt GitHub
#' `OFCE/ofce-quarto-extensions` — la fonction nécessite donc un accès réseau.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param lang Chaîne. Langue principale : `"fr"` (défaut) ou `"en"`.
#' @param hypothesis Logique. Active les commentaires Hypothesis. Défaut `FALSE`.
#' @param versionning Logique. Si `TRUE` et PB publié (`pb` non `NULL`),
#'   ajoute `/v0` au `site-path`.
#' @param stage_target Chaîne. Destination de pré-publication (brouillon,
#'   `pb` non encore attribué) : `"auto"` (défaut), `"ftp"` (staging OFCE),
#'   `"gh-pages"`. Cf. [setup_wp()] pour la sémantique détaillée.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [render_pb()], [deploy_pb()], [pb_version_up()], [update_navbar()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists file_copy dir_copy dir_create dir_ls path_ext path_ext_remove
#' @importFrom cli cli_h1 cli_h2 cli_li cli_abort cli_alert_success cli_alert_warning cli_alert_info
#' @importFrom yaml read_yaml
#' @importFrom gert git_remote_list
#' @export
setup_pb <- function(
    path = ".",
    lang = "fr",
    hypothesis = NULL,
    versionning = NULL,
    stage_target = NULL) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  if (!fs::dir_exists(root))
    cli::cli_abort("Le dossier {.path {root}} n'existe pas.")

  cli::cli_h1("setup_pb dans {.path {fs::path_file(root)}}")

  check_quarto_version()

  # ---- 0. connexion GitHub / DEPLOY_PAT / identite git ---------------------
  check_gh_setup(root)

  # Détecter les arguments fournis explicitement (avant toute modification)
  lang_provided       <- !missing(lang)
  hypothesis_provided <- !missing(hypothesis)
  version_provided      <- !missing(versionning)
  stage_target_provided <- !missing(stage_target)

  # Vérifier si les arguments ne sont pas dans un yml
  dest_yaml <- fs::path(root, "_quarto.yml")
  dest_index <- fs::path(root, "index.qmd")
  yml <- if (fs::file_exists(dest_yaml))
    tryCatch(yaml::read_yaml(dest_yaml), error = function(e) list())
  else list()

  # Garde-fous de type : un dépôt PB ne doit pas être un WP ni une prévision.
  if (isTRUE(yml[["ofce_prev"]])) {
    cli::cli_abort(c(
      "Ce dépôt est une {.strong prévision} ({.field ofce_prev: true} dans {.file _quarto.yml}).",
      "i" = "Utilisez {.fn setup_prev} pour initialiser un dépôt de prévision.",
      "x" = "{.fn setup_pb} ne peut pas être appliqué à un dépôt de prévision."
    ))
  }
  if (isTRUE(yml[["ofce_wp"]])) {
    cli::cli_abort(c(
      "Ce dépôt est un {.strong document de travail} ({.field ofce_wp: true} dans {.file _quarto.yml}).",
      "i" = "Utilisez {.fn setup_wp} pour initialiser un dépôt de document de travail.",
      "x" = "{.fn setup_pb} ne peut pas être appliqué à un dépôt WP."
    ))
  }

  if(file.exists(dest_index))
    index_yml <- get_yaml(dest_index) else
      index_yml <- list()

  # pb : plus un argument — toujours lu depuis _quarto.yml, sauf écrasement
  # par une entrée confirmée du registre central (section 10d). `annee`
  # n'est pas utilisé pour les PB (numérotation séquentielle indépendante de
  # l'année).
  pb          <- yml[["pb"]]
  pb_provided <- !is.null(pb)

  if(!is.null(yml[["lang"]])&&!lang_provided) {
    lang <- yml[["lang"]]
    lang_provided <- TRUE
  }
  if(is.null(yml[["lang"]])&&!lang_provided) {
    lang <- "fr"
    lang_provided <- TRUE
  }
  # website_title : toujours déduit d'un website.title résiduel ou du titre de
  # index.qmd.
  website_title <- NULL
  if (!is.null(yml[["website"]][["title"]])) {
    website_title <- yml[["website"]][["title"]]
  } else if (!is.null(index_yml[["title"]])) {
    website_title <- index_yml[["title"]]
  }
  if(!is.null(yml[["comment"]][["hypothesis"]])&&!hypothesis_provided) {
    hypothesis_provided <- TRUE
    hypothesis <- yml[["comment"]][["hypothesis"]]
  }
  if(is.null(yml[["comment"]][["hypothesis"]])&&!hypothesis_provided) {
    hypothesis_provided <- TRUE
    hypothesis <- is.null(pb)
  }
  if(hypothesis_provided){
      hypothesis <- isTRUE(hypothesis)
    }
  # ---- infos dépôt git (calculé tôt : nécessaire pour résoudre
  # stage-target = "auto" ci-dessous selon l'organisation GitHub) -----------
  gh        <- detect_gh_owner(root)
  repo_name <- if (is.na(gh$repo)) fs::path_file(root) else gh$repo
  gh_org    <- gh$org

  # Avertissement si le dépôt n'est pas dans l'organisation ofce.
  if (!is.na(gh$owner) && !identical(tolower(gh_org), "ofce")) {
    cli::cli_alert_info(
      "Ce dépôt est sous {.strong {gh_org}}, pas sous {.strong ofce}.
      Le rendu fonctionne, mais la publication FTP ne sera pas possible
      avant un transfert de propriété vers l'organisation {.strong ofce}
      GitHub → Settings → Danger Zone → Transfer repository).")
  }

  # ---- stage-target : gh-pages, ftp, ofce (alias hérité de ftp) ou auto ---
  if (!is.null(yml[["stage-target"]]) && !stage_target_provided) {
    stage_target_provided <- TRUE
    stage_target <- yml[["stage-target"]]
  }
  if (is.null(yml[["stage-target"]]) && !stage_target_provided) {
    stage_target_provided <- TRUE
    stage_target <- "auto"
  }
  if (stage_target_provided) {
    stage_target <- match.arg(stage_target, c("auto", "gh-pages", "ofce", "ftp"))
    if (identical(stage_target, "ofce")) stage_target <- "ftp"
  }
  stage_target_resolved <- resolve_stage_target(stage_target, org = gh_org)

  version <- yml[["version"]]
  if(version_provided & is.null(yml[["version"]]) & isTRUE(versionning))
    version <- "v0"

  if(!version_provided & !is.null(yml[["version"]])) {
    version_provided <- TRUE
    versionning <- TRUE
  }

  # ---- 0. validation des arguments -----------------------------------------
  if (!is.null(pb)) {
    pb <- suppressWarnings(as.integer(pb))
    if (is.na(pb))
      cli::cli_abort("{.arg pb} doit être un entier ou NULL.")
  }

  if (!lang %in% c("fr", "en")) {
    cli::cli_alert_warning("{.arg lang} doit être {.val fr} ou {.val en}. Utilisation de {.val fr}.")
    lang <- "fr"
  }

  # ---- 1. branche gh-pages (toujours pour les PBs) -------------------------
  init_gh_pages_branch(root)

  # ---- 3. titre du PB -------------------------------------------------------
  final_title <- if (!is.null(website_title) && nzchar(website_title)) {
    website_title
  } else {
    repo_name
  }

  # ---- 4. localisation des gabarits -----------------------------------------
  pkg_setup_pb   <- system.file("setup_pb",   package = "ofceweb")
  pkg_share <- system.file("share", package = "ofceweb")
  if (!nzchar(pkg_setup_pb))
    pkg_setup_pb <- fs::path(find.package("ofceweb"), "inst", "setup_pb")
  if (!nzchar(pkg_setup_pb))
    pkg_setup_pb <- fs::path(root, "inst", "setup_pb")   # dev fallback
  if (!nzchar(pkg_share))
    pkg_share <- fs::path(root, "inst", "share")

  # ---- 5. copie _quarto.yml (seulement si absent) ---------------------------
  src_yaml  <- fs::path(pkg_setup_pb, "_quarto.yml")
  if (!fs::file_exists(dest_yaml)) {
    fs::file_copy(src_yaml, dest_yaml, overwrite = FALSE)

    cli::cli_alert_success("Copie de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} déjà présent — non écrasé.")
  }

  # ---- 6. copie index.qmd (si absent) ---------------------------------------
  src_index    <- fs::path(pkg_setup_pb, "index.qmd")
  dest_index   <- fs::path(root, "index.qmd")
  created_index <- !fs::file_exists(dest_index)
  if (created_index) {
    fs::file_copy(src_index, dest_index, overwrite = FALSE)
    index_yml <- get_yaml(dest_index)
    cli::cli_alert_success("Copie de {.file index.qmd}")
  } else {
    cli::cli_alert_info("{.file index.qmd} déjà présent — non écrasé.")
  }

  # ---- 6b. format PDF : pb-pdf et pb-typst sont mutuellement exclusifs -----
  project_format_names <- names(
    tryCatch(yaml::read_yaml(dest_yaml), error = function(e) list())[["format"]]
  )
  pdf_formats_declared <- intersect(
    c("pb-pdf", "pb-typst"),
    union(project_format_names, names(index_yml[["format"]]))
  )

  if (length(pdf_formats_declared) > 1L) {
    commented_project <- tryCatch(
      yaml_comment_out_file(dest_yaml, "format.pb-pdf"),
      error = function(e) FALSE
    )
    commented_index <- tryCatch(
      yaml_comment_out_frontmatter(dest_index, "format.pb-pdf"),
      error = function(e) FALSE
    )
    if (isTRUE(commented_project) || isTRUE(commented_index)) {
      yml$format$`pb-pdf` <- NULL
      index_yml$format$`pb-pdf` <- NULL
      cli::cli_alert_warning(c(
        "Deux formats PDF étaient déclarés simultanément ({.field pb-pdf} ET {.field pb-typst}).",
        "i" = "{.field pb-pdf} a été commenté automatiquement -- {.field pb-typst} reste actif.",
        "x" = "Décommenter {.field pb-pdf} à la main (et recommenter {.field pb-typst}) pour revenir au moteur LaTeX ; les deux ne peuvent pas coexister."
      ))
      pdf_formats_declared <- "pb-typst"
    }
  } else if (identical(pdf_formats_declared, "pb-pdf") && !isTRUE(check_rsvg_convert(verbose = FALSE))) {
    tryCatch({
      yaml_patch_frontmatter_scalar(dest_index, "format.pb-pdf.fig-format", "png")
      index_yml$format$`pb-pdf`$`fig-format` <- "png"
    }, error = function(e) NULL)
    cli::cli_alert_warning(c(
      "{.code rsvg-convert} introuvable : Quarto ne peut pas rastériser nativement les figures SVG pour LaTeX ({.field pb-pdf}).",
      "i" = "{.field format.pb-pdf.fig-format: png} a été ajouté dans {.file index.qmd} pour contourner le problème.",
      "x" = "Les fichiers PDF produits seront probablement {.strong plus volumineux} (figures rasterisées en PNG plutôt que vectorielles)."
    ))
  }

  # ---- 7. copie annexes.qmd et news.qmd (si absents) -----------------------
  for (qmd in c("annexes.qmd", "news.qmd")) {
    dest_qmd <- fs::path(root, qmd)
    if (!fs::file_exists(dest_qmd)) {
      fs::file_copy(fs::path(pkg_setup_pb, qmd), dest_qmd, overwrite = FALSE)
      cli::cli_alert_success("Copie de {.file {qmd}}")
    } else {
      cli::cli_alert_info("{.file {qmd}} déjà présent — non écrasé.")
    }
  }

  # ---- 8. copie www/ depuis share/ ------------------------------------
  src_www <- fs::path(pkg_share, "www")
  if (fs::dir_exists(src_www)) {
    dest_www <- fs::path(root, "www")
    fs::dir_create(dest_www)
    for (f in fs::dir_ls(src_www, recurse = FALSE)) {
      if (fs::dir_exists(f))
        fs::dir_copy(f, fs::path(dest_www, fs::path_file(f)), overwrite = TRUE)
      else
        fs::file_copy(f, fs::path(dest_www, fs::path_file(f)), overwrite = TRUE)
    }
    cli::cli_alert_success("Copie du dossier {.path www/}")
  }

  # ---- 8b. polices Google (thèmes OFCE) -------------------------------------
  tryCatch(
    check_fonts(quiet = FALSE),
    error = function(e)
      cli::cli_alert_warning("{.fn check_fonts} a échoué : {conditionMessage(e)}")
  )

  # ---- 9. extensions Quarto OFCE (source de vérité : ofce::setup_quarto()) --
  tryCatch({
    ofce::setup_quarto(root, quiet = TRUE)
    if (fs::dir_exists(fs::path(root, "_extensions", "ofce", "pb"))) {
      cli::cli_alert_success(
        "Extensions Quarto OFCE installées/mises à jour ({.fn ofce::setup_quarto})."
      )
    } else {
      cli::cli_alert_warning(
        "{.fn ofce::setup_quarto} n'a signalé aucune erreur mais \
         {.path _extensions/ofce/pb} est absent — vérifier la connexion \
         réseau et l'installation de Quarto ({.code quarto check})."
      )
    }
  }, error = function(e) {
    cli::cli_alert_warning("{.fn ofce::setup_quarto} a échoué : {conditionMessage(e)}")
  })
  check_stray_ofce_extensions(root)

  # ---- 10. copie des workflows (toujours mis à jour depuis le package) ------
  src_wf  <- fs::path(pkg_setup_pb, "workflows")
  dest_wf <- fs::path(root, ".github", "workflows")
  if (fs::dir_exists(src_wf)) {
    fs::dir_create(dest_wf, recurse = TRUE)
    n_updated <- 0L
    for (f in fs::dir_ls(src_wf, type = "file")) {
      fname <- fs::path_file(f)
      if (fs::path_ext(fname) == "html") fname <- fs::path_ext_remove(fname)
      dest_f <- fs::path(dest_wf, fname)
      fs::file_copy(f, dest_f, overwrite = TRUE)
      n_updated <- n_updated + 1L
    }
    if (n_updated > 0L)
      cli::cli_alert_success("Mise à jour de {n_updated} workflow{?s} vers {.path .github/workflows/}")
  }

  # ---- 10b. migration server-dir → ${{ vars.FTP_SERVER_DIR }} ---------------
  ftp_wf <- fs::path(dest_wf, "ftp_deploy.yml")
  if (fs::file_exists(ftp_wf)) {
    wf_lines <- readLines(ftp_wf, warn = FALSE)
    needs_migration <- any(grepl("server-dir:", wf_lines)) &&
      !any(grepl("vars\\.FTP_SERVER_DIR", wf_lines))
    if (needs_migration) {
      wf_lines <- sub(
        "^(\\s*)server-dir:.*$",
        "\\1server-dir: ${{ vars.FTP_SERVER_DIR }}",
        wf_lines
      )
      writeLines(wf_lines, ftp_wf)
      cli::cli_alert_success(
        "{.file .github/workflows/ftp_deploy.yml} migré vers {.code {{vars.FTP_SERVER_DIR}}}"
      )
    }
  }

  # ---- 10c. migration : ajout de la vérification anti-collision ------------
  if (fs::file_exists(ftp_wf)) {
    wf_lines <- readLines(ftp_wf, warn = FALSE)
    collision_step_name <- "Vérification anti-collision"
    if (!any(grepl(collision_step_name, wf_lines, fixed = TRUE))) {
      src_ftp_wf <- fs::path(src_wf, "ftp_deploy.yml")
      if (fs::file_exists(src_ftp_wf)) {
        tpl_lines <- readLines(src_ftp_wf, warn = FALSE)
        step_start <- which(grepl(collision_step_name, tpl_lines, fixed = TRUE)) - 1L
        step_end   <- which(grepl("Chiffrement staticrypt", tpl_lines, fixed = TRUE)) - 1L
        anchor <- which(grepl("Chiffrement staticrypt", wf_lines, fixed = TRUE))
        if (length(step_start) == 1L && length(step_end) == 1L && length(anchor) == 1L) {
          collision_step <- tpl_lines[step_start:step_end]
          wf_lines <- append(wf_lines, collision_step, after = anchor - 1L)
          writeLines(wf_lines, ftp_wf)
          cli::cli_alert_success(
            "{.file .github/workflows/ftp_deploy.yml} : ajout de la vérification anti-collision."
          )
        }
      }
    }
  }

  # ---- 10d. registre central (source de vérité pour pb/draft) --------------
  cli::cli_h2("Registre central")
  registry_state <- tryCatch(
    sync_pb_registry_state(root),
    error = function(e) {
      cli::cli_alert_warning("Synchronisation du registre ignorée : {conditionMessage(e)}")
      NULL
    }
  )
  if (!is.null(registry_state) && isTRUE(registry_state$network_error)) {
    if (!is.null(pb) || !is.null(yml$pb))
      cli::cli_alert_warning(
        "{.field pb} non revalidé par le registre — traité comme absent \\
         pour cet appel (site-path, citation.*, FTP_SERVER_DIR non \\
         recalculés sur l'ancien numéro)."
      )
    pb          <- NULL
    yml$pb      <- NULL
    pb_provided <- FALSE
  } else if (!is.null(registry_state) && !isTRUE(registry_state$network_error) &&
      !is.null(registry_state$registry_entry)) {
    pb          <- as.integer(registry_state$registry_entry$pb)
    pb_provided <- TRUE
  }

  # ---- 11. édition du _quarto.yml ------------------------------------------
  lines_before <- readLines(dest_yaml, warn = FALSE)
  lines <- lines_before

  if (pb_provided)    { yml$pb    <- pb;    lines <- yaml_patch_scalar_or_delete(lines, "pb", pb) }
  if (lang_provided)  { yml$lang  <- lang;  lines <- yaml_patch_scalar(lines, "lang", lang) }
  # On enlève pb/annee de l'index si jamais présents (annee n'est plus
  # utilisé pour les PB, mais on nettoie une valeur résiduelle éventuelle).
  if(!is.null(index_yml$pb))
    yaml_comment_out_frontmatter(dest_index, "pb")
  if(!is.null(index_yml$annee))
    yaml_comment_out_frontmatter(dest_index, "annee")

  # project.type : toujours forcé à "ofce-website" pour les PBs OFCE
  yml$project$type <- "ofce-website"
  lines <- yaml_patch_scalar(lines, "project.type", "ofce-website")

  # stage-target : source de vérité pour le routage du déploiement
  yml$`stage-target` <- stage_target
  lines <- yaml_patch_scalar(lines, "stage-target", stage_target)

  # ofce_pb : marqueur de dépôt PB OFCE — toujours positionné
  yml$ofce_pb <- TRUE
  lines <- yaml_patch_scalar(lines, "ofce_pb", TRUE)

  # favicon : asset géré par le package — toujours resynchronisé
  yml$website$favicon <- "www/fofce-wp.png"
  lines <- yaml_patch_scalar(lines, "website.favicon", "www/fofce-wp.png")

  # draft-mode : toujours resynchronisé
  yml$website$`draft-mode` <- "visible"
  lines <- yaml_patch_scalar(lines, "website.draft-mode", "visible")

  # repo-url : toujours calculé depuis le remote git — forcé à chaque appel
  repo_url <- sprintf("https://github.com/%s/%s/", gh_org, repo_name)
  yml$website$`repo-url` <- repo_url
  lines <- yaml_patch_scalar(lines, "website.repo-url", repo_url)

  # site-url / site-path : toujours recalculés
  #
  # Publié (pb non nul)  : site-url = www.ofce.fr,  site-path = {pb}/[{version}/]
  # Brouillon gh-pages : site-url = {org}.github.io/{repo}/,       pas de site-path
  # Staging FTP        : site-url = staging.ofce.fr/{repo}/[{version}/], pas de site-path
  if (!is.null(pb)) {
    yml$website$`site-url`  <- "https://www.ofce.fr/"
    lines <- yaml_patch_scalar(lines, "website.site-url", "https://www.ofce.fr/")
    site_path_base <- sprintf("%d", pb)
    if (isTRUE(versionning))
      site_path <- paste0(site_path_base, "/", version)
    else
      site_path <- site_path_base
    yml$version <- version
    lines <- yaml_patch_scalar_or_delete(lines, "version", version)

    old_site_path <- as.character(yml$website$`site-path` %||% "")
    if (nzchar(old_site_path) && !identical(old_site_path, site_path)) {
      cli::cli_alert_warning(
        "site-path modifié : {.val {old_site_path}} → {.val {site_path}} \r
         — le prochain déploiement ira sur une {.strong URL différente}."
      )
      cli::cli_alert_info(
        "L'ancien répertoire {.val {old_site_path}} reste en place sur le \r
         serveur : le supprimer ou y poser une redirection si nécessaire."
      )
    }

    yml$website$`site-path` <- site_path
    lines <- yaml_patch_scalar(lines, "website.site-path", site_path)
  } else {
    yml$website$`site-path` <- NULL
    lines <- yaml_patch_delete(lines, "website.site-path")
    draft_site_url <- if (identical(stage_target_resolved, "ftp")) {
      ver_seg <- if (!is.null(version) && nzchar(as.character(version)))
        paste0(version, "/") else ""
      sprintf("https://staging.ofce.fr/%s/%s", repo_name, ver_seg)
    } else if (!is.na(gh_org)) {
      sprintf("https://%s.github.io/%s/", gh_org, repo_name)
    } else {
      cli::cli_alert_warning(
        "Impossible de déterminer l'URL GitHub Pages (pas de remote {.code origin}, \\
         pas de compte {.code gh} authentifié) — {.field website.site-url} laissé \\
         inchangé. Ajouter un remote {.code origin} (ou lancer {.code gh auth login}) \\
         puis relancer {.run setup_pb()}."
      )
      yml$website$`site-url`
    }
    yml$website$`site-url`  <- draft_site_url
    lines <- yaml_patch_scalar_or_delete(lines, "website.site-url", draft_site_url)
  }

  # citation.url / citation.issue : valeurs dérivées, toujours mises à jour
  # pour les PBs publiés.
  # - citation.url  : https://www.ofce.fr/pb/{pb}/ (URL stable, sans version)
  # - citation.issue: "{pb}"
  if (!is.null(yml$pb)) {
    citation_pb <- suppressWarnings(as.integer(yml$pb))
    if (!is.na(citation_pb)) {
      stable_url <- sprintf("https://www.ofce.fr/pb/%d/", citation_pb)
      if (is.null(yml$citation)) yml$citation <- list()
      yml$citation$url <- stable_url
      lines <- yaml_patch_scalar(lines, "citation.url", stable_url)

      issue <- sprintf("%d", citation_pb)
      yml$citation$issue <- issue
      lines <- yaml_patch_scalar(lines, "citation.issue", issue)
    }
  }

  # hypothesis : uniquement si fourni explicitement
  if (hypothesis_provided) {
    yml$comments <- list(hypothesis = isTRUE(hypothesis))
    lines <- yaml_patch_scalar(lines, "comments.hypothesis", isTRUE(hypothesis))
  }

  # output-file PDF : uniquement si pb est déjà connu ET si un format PDF
  # est effectivement actif (pb-pdf OU pb-typst).
  active_pdf_format <- if (length(pdf_formats_declared) == 1L) pdf_formats_declared else NA_character_
  uses_pb_pdf <- !is.na(active_pdf_format)
  if (pb_provided && uses_pb_pdf) {
    pdf_output <- if (!is.null(pb)) {
      sprintf("OFCEPB%d.pdf", pb)
    } else {
      "OFCEPB-draft.pdf"
    }
  } else if (uses_pb_pdf) {
    pdf_output <- index_yml$format[[active_pdf_format]]$`output-file` %||% NA_character_
  } else {
    pdf_output <- NA_character_
  }

  if (!identical(lines_before, lines)) {
    writeLines(lines, dest_yaml)
    cli::cli_alert_success("Mise à jour de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} — aucun changement nécessaire.")
  }

  if (uses_pb_pdf && !is.na(pdf_output)) {
    tryCatch({
      yaml_patch_frontmatter_scalar(
        dest_index,
        sprintf("format.%s.output-file", active_pdf_format),
        pdf_output
      )
      cli::cli_alert_success("output-file mis à jour dans {.file index.qmd}")
    }, error = function(e) {
      cli::cli_alert_warning("Impossible de patcher index.qmd : {conditionMessage(e)}")
    })

    tryCatch({
      yaml_patch_frontmatter_block(
        dest_index,
        "format-links",
        list(
          sub("^pb-", "", active_pdf_format),
          list(format = active_pdf_format, text = pdf_output, icon = "file-pdf")
        )
      )
      cli::cli_alert_success("format-links mis à jour dans {.file index.qmd}")
    }, error = function(e) {
      cli::cli_alert_warning("Impossible de patcher format-links dans index.qmd : {conditionMessage(e)}")
    })
  }

  # ---- 11b. navbar (source centralisée du package) --------------------------
  tryCatch(
    update_navbar(root),
    error = function(e)
      cli::cli_alert_warning("update_navbar() a échoué : {conditionMessage(e)}")
  )

  # ---- 12. server-dir dans le workflow FTP ----------------------------------
  if (!is.null(yml$pb)) {
    yml_after  <- tryCatch(yaml::read_yaml(dest_yaml), error = function(e) NULL)
    server_dir <- yml_after$website$`site-path`
    if (!is.null(server_dir) && nzchar(server_dir)) {
      if (!grepl("/$", server_dir)) server_dir <- paste0(server_dir, "/")
      set_gh_var(root, "FTP_SERVER_DIR", server_dir)
      server_dir_clean <- sub("/$", "", server_dir)
      redirect_dir <- if (grepl("/v\\d+$", server_dir_clean)) {
        paste0(sub("/v\\d+$", "", server_dir_clean), "/")
      } else {
        paste0(server_dir_clean, "/")
      }
      set_gh_var(root, "FTP_REDIRECT_DIR", redirect_dir)
    }
  }

  # ---- 12b. FTP_STAGING_DIR (toujours, indépendant du numéro PB) -----------
  staging_slug    <- if (!is.na(gh$repo)) gh$repo else fs::path_file(root)
  staging_version <- yml$version
  staging_ver_seg <- if (!is.null(staging_version) && nzchar(as.character(staging_version)))
    paste0(staging_version, "/") else ""
  staging_dir <- sprintf("%s/%s", staging_slug, staging_ver_seg)
  set_gh_var(root, "FTP_STAGING_DIR", staging_dir)

  # ---- 13. .gitignore -------------------------------------------------------
  gi_path      <- fs::path(root, ".gitignore")
  gi_lines     <- if (fs::file_exists(gi_path)) readLines(gi_path, warn = FALSE) else character()
  tmpl_path    <- system.file("setup_pb/.gitignore", package = "ofceweb")
  tmpl_entries <- readLines(tmpl_path, warn = FALSE)
  tmpl_entries <- tmpl_entries[nzchar(trimws(tmpl_entries))]
  changed      <- FALSE

  for (entry in tmpl_entries) {
    if (!any(trimws(gi_lines) == entry)) {
      gi_lines <- c(gi_lines, entry)
      changed  <- TRUE
    }
  }
  if (changed) {
    writeLines(gi_lines, gi_path)
    cli::cli_alert_success("Mise à jour de {.file .gitignore}")
  }

  # ---- Résumé ---------------------------------------------------------------
  cli::cli_h2("Résumé")
  cli::cli_li("titre       : {final_title}")
  cli::cli_li("pb          : {if (is.null(yml$pb)) 'brouillon (null)' else yml$pb}")
  cli::cli_li("version     : {yml$version}")
  cli::cli_li("lang        : {yml[['lang']]}")
  cli::cli_li("site-url    : {yml$website$`site-url`}")
  if (!is.null(yml$website$`site-path`))
    cli::cli_li("site-path   : {yml$website$`site-path`}")
  if (is.null(yml$pb) && identical(stage_target_resolved, "ftp")) {
    cli::cli_li("staging url : https://staging.ofce.fr/{staging_dir}")
  }
  cli::cli_li(
    "stage-target: {stage_target}{if (identical(stage_target, 'auto')) paste0(' (→ ', stage_target_resolved, ' pour ', gh_org, ')') else ''}"
  )
  cli::cli_li("draft       : {if (is.null(registry_state)) '(non consulté)' else if (isTRUE(registry_state$network_error)) 'TRUE (forcé -- registre inaccessible, pb effacé)' else registry_state$stage}")
  if (!is.null(yml$citation$issue))
    cli::cli_li("citation issue: {yml$citation$issue}")
  if (!is.null(yml$citation$url))
    cli::cli_li("citation url: {yml$citation$url}")
  cli::cli_li("hypothesis  : {isTRUE(yml$comments$hypothesis)}")
  cli::cli_li("pdf         : {if (is.na(pdf_output)) '(non applicable)' else pdf_output}")

  cli::cli_bullets(
    c(
      ">" = "{.emph commiter} et {.emph pusher} les changements avant de lancer {.run ofceweb::render_pb()}."
  ))

  invisible(NULL)
}
