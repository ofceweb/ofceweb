#' Initialise un dépôt de document de travail (WP) OFCE
#'
#' Copie les gabarits embarqués dans le package (`inst/setup_wp/`) à la racine
#' du dépôt, initialise la branche `gh-pages` pour la pré-publication, et
#' adapte le `_quarto.yml` avec les métadonnées du WP (titre, numéro, année,
#' langue, URLs).
#'
#' La fonction est **non-destructive** pour les fichiers utilisateur : sur un
#' dépôt existant, les fichiers gabarits `.qmd` et scripts (dont `_quarto.yml`)
#' ne sont pas écrasés, et les champs YAML ne sont mis à jour que si l'argument
#' correspondant a été fourni explicitement. Les champs déjà absents ne sont pas
#' injectés. `repo-url`, `favicon` et `ofce_wp: true` sont toujours positionnés
#' (valeurs dérivées sans ambiguïté). `website.site-url`/`website.site-path`
#' sont eux aussi toujours (re)calculés dès que `wp` est non nul — valeur lue
#' dans `_quarto.yml` ou fournie par le registre central — pour qu'un
#' `site-path` manquant (fichier édité à la main, ou créé avant cette
#' fonctionnalité) soit toujours réparé.
#'
#' En revanche, les **workflows GitHub Actions** (`.github/workflows/`) sont
#' **toujours mis à jour** depuis la version de référence du package : ils ne
#' doivent pas être modifiés manuellement par l'utilisateur, et chaque appel à
#' `setup_wp()` réapplie les corrections et mises à jour de templates.
#'
#' Pour les WPs publiés (`wp` non nul), la fonction met à jour la variable
#' GitHub Actions `FTP_SERVER_DIR` (publique, visible dans Settings → Variables)
#' à partir du `site-path` du `_quarto.yml`. Les workflows `ftp_deploy.yml` et
#' `ftp_stage.yml` sont aussi migrés automatiquement si `server-dir` y est
#' encore codé en dur, et si l'étape de vérification anti-collision (voir
#' [wp_manifest()]) y est absente.
#'
#' `wp` et `annee` ne sont **pas** des arguments : ils sont soit lus depuis un
#' `_quarto.yml` déjà existant, soit écrasés par une entrée confirmée du
#' registre central (`ofceweb/wp-registry`), jamais choisis librement par
#' l'appelant. Un dépôt sans `_quarto.yml` et sans entrée de registre reste un
#' brouillon (`wp` absent) ; pour obtenir un numéro, utiliser
#' [wp_registry_request()] puis relancer `setup_wp()` une fois la PR
#' fusionnée. De même, le titre affiché dans le résumé est toujours déduit de
#' `index.qmd` (ou du nom du dépôt GitHub) — il n'y a plus d'argument
#' `website_title`.
#'
#' La variable `FTP_STAGING_DIR` est toujours positionnée (brouillon ou publié)
#' à `{repo}/{version}/` — l'utilisateur FTP de staging ayant un chroot sur
#' `www/staging/`, le chemin effectif sur le serveur est
#' `www/staging/{repo}/{version}/`. Ce chemin est utilisé par `ftp_stage.yml`
#' pour déposer les versions de revue avant enregistrement dans le registre
#' central (voir [wp_registry_request()]).
#'
#' Toujours pour les WPs publiés, `citation.issue` (`"{année}-{wp}"`, sans
#' zéro de remplissage) et `citation.url`
#' (`https://www.ofce.fr/wp/{année}/{wp}/`, l'URL publique stable, sans
#' segment de version) sont recalculés à chaque appel à partir de
#' `annee`/`wp` — ce sont des valeurs dérivées, jamais éditées manuellement.
#'
#' Les extensions Quarto OFCE (`_extensions/`) sont installées/mises à jour
#' via [ofce::setup_quarto()], qui les récupère depuis le dépôt GitHub
#' `OFCE/ofce-quarto-extensions` — la fonction nécessite donc un accès
#' réseau. D'éventuelles extensions périmées (installées par une version
#' antérieure du package) sont signalées par un avertissement, jamais
#' supprimées automatiquement.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param lang Chaîne. Langue principale : `"fr"` (défaut) ou `"en"`.
#' @param hypothesis Logique. Active les commentaires Hypothesis. Défaut `FALSE`.
#' @param versionning Logique. Si `TRUE` et WP publié (`wp` non `NULL`),
#'   ajoute `/v0` au `site-path`.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [render_wp()], [deploy_wp()], [wp_version_up()], [update_navbar()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists file_copy dir_copy dir_create dir_ls path_ext path_ext_remove
#' @importFrom cli cli_h1 cli_h2 cli_li cli_abort cli_alert_success cli_alert_warning cli_alert_info
#' @importFrom yaml read_yaml
#' @importFrom gert git_remote_list
#' @export
setup_wp <- function(
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

  cli::cli_h1("setup_wp dans {.path {fs::path_file(root)}}")

  check_quarto_version()

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

  if (isTRUE(yml[["ofce_prev"]])) {
    cli::cli_abort(c(
      "Ce dépôt est une {.strong prévision} ({.field ofce_prev: true} dans {.file _quarto.yml}).",
      "i" = "Utilisez {.fn setup_prev} pour initialiser un dépôt de prévision.",
      "x" = "{.fn setup_wp} ne peut pas être appliqué à un dépôt de prévision."
    ))
  }

  if(file.exists(dest_index))
    index_yml <- get_yaml(dest_index) else
      index_yml <- list()

  # wp / annee : plus d'arguments — toujours lus depuis _quarto.yml, sauf
  # écrasement par une entrée confirmée du registre central (section 10d).
  # `wp_provided`/`annee_provided` indiquent simplement qu'une valeur est
  # déjà connue (yml ou registre) et doit donc être (ré)écrite plus bas.
  wp          <- yml[["wp"]]
  wp_provided <- !is.null(wp)

  annee          <- yml[["annee"]]
  annee_provided <- !is.null(annee)
  if (is.null(annee)) annee <- as.integer(format(Sys.Date(), "%Y"))

  if(!is.null(yml[["lang"]])&&!lang_provided) {
    lang <- yml[["lang"]]
    lang_provided <- TRUE
  }
  if(is.null(yml[["lang"]])&&!lang_provided) {
    lang <- "fr"
    lang_provided <- TRUE
  }
  # website_title : plus d'argument — toujours déduit d'un website.title
  # résiduel (compat. avant update_navbar(), qui supprime cette clé) ou du
  # titre de index.qmd.
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
    hypothesis <- is.null(wp)
  }
  if(hypothesis_provided){
      hypothesis <- isTRUE(hypothesis)
    }
  if (!is.null(yml[["stage-target"]]) && !stage_target_provided) {
    stage_target_provided <- TRUE
    stage_target <- yml[["stage-target"]]
  }
  if (is.null(yml[["stage-target"]]) && !stage_target_provided) {
    stage_target_provided <- TRUE
    stage_target <- "gh-pages"
  }
  if (stage_target_provided)
    stage_target <- match.arg(stage_target, c("gh-pages", "ftp"))

  version <- yml[["version"]]
  if(version_provided & is.null(yml[["version"]]) & isTRUE(versionning))
    version <- "v0"

  if(!version_provided & !is.null(yml[["version"]])) {
    version_provided <- TRUE
    versionning <- TRUE
  }

  # ---- 0. validation des arguments -----------------------------------------
  if (!is.null(wp)) {
    wp <- suppressWarnings(as.integer(wp))
    if (is.na(wp))
      cli::cli_abort("{.arg wp} doit être un entier ou NULL.")
  }

  annee <- suppressWarnings(as.integer(annee))
  if (is.na(annee))
    cli::cli_abort("{.arg annee} doit être un entier.")

  if (!lang %in% c("fr", "en")) {
    cli::cli_alert_warning("{.arg lang} doit être {.val fr} ou {.val en}. Utilisation de {.val fr}.")
    lang <- "fr"
  }

  # ---- 1. branche gh-pages (toujours pour les WPs) -------------------------
  init_gh_pages_branch(root)

  # ---- 2. infos dépôt git --------------------------------------------------
  remotes <- tryCatch(gert::git_remote_list(repo = root),
                      error = function(e) NULL)
  origin_url <- NULL
  if (!is.null(remotes) && nrow(remotes) > 0) {
    o <- remotes[remotes$name == "origin", , drop = FALSE]
    if (nrow(o) > 0) origin_url <- o$url[[1]]
    else origin_url <- remotes$url[[1]]
  }

  parse_remote_wp <- function(url) {
    if (is.null(url)) return(list(owner = NA_character_, repo = NA_character_))
    url2 <- sub("\\.git$", "", url)
    if (grepl("^git@", url2)) {
      m <- regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
    } else {
      m <- regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
    }
    if (length(m) < 3) return(list(owner = NA_character_, repo = NA_character_))
    list(owner = m[[2]], repo = m[[3]])
  }

  gh     <- parse_remote_wp(origin_url)
  repo_name <- if (is.na(gh$repo)) fs::path_file(root) else gh$repo
  gh_org    <- if (is.na(gh$owner)) "ofce" else gh$owner

  # Avertissement si le dépôt n'est pas dans l'organisation ofce.
  # Le rendu local fonctionne, mais la publication FTP nécessite d'être dans
  # `ofce` : les secrets FTP y sont stockés et l'accès au registre central
  # (wp_registry_request()) est réservé aux dépôts de cette organisation.
  if (!is.na(gh$owner) && !identical(tolower(gh_org), "ofce")) {
    cli::cli_alert_info(
      "Ce dépôt est sous {.strong {gh_org}}, pas sous {.strong ofce}.
      Le rendu fonctionne, mais la publication FTP ne sera pas possible
      avant un transfert de propriété vers l'organisation {.strong ofce}
      GitHub → Settings → Danger Zone → Transfer repository).")
  }

  # ---- 3. titre du WP -------------------------------------------------------
  final_title <- if (!is.null(website_title) && nzchar(website_title)) {
    website_title
  } else {
    repo_name
  }

  # ---- 4. localisation des gabarits -----------------------------------------
  pkg_setup_wp   <- system.file("setup_wp",   package = "ofceweb")
  pkg_share <- system.file("share", package = "ofceweb")
  if (!nzchar(pkg_setup_wp))
    pkg_setup_wp <- fs::path(find.package("ofceweb"), "inst", "setup_wp")
  if (!nzchar(pkg_setup_wp))
    pkg_setup_wp <- fs::path(root, "inst", "setup_wp")   # dev fallback
  if (!nzchar(pkg_share))
    pkg_share <- fs::path(root, "inst", "share")

  # ---- 5. copie _quarto.yml (seulement si absent) ---------------------------
  src_yaml  <- fs::path(pkg_setup_wp, "_quarto.yml")
  if (!fs::file_exists(dest_yaml)) {
    fs::file_copy(src_yaml, dest_yaml, overwrite = FALSE)

    cli::cli_alert_success("Copie de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} déjà présent — non écrasé.")
  }

  # ---- 6. copie index.qmd (si absent) ---------------------------------------
  src_index    <- fs::path(pkg_setup_wp, "index.qmd")
  dest_index   <- fs::path(root, "index.qmd")
  created_index <- !fs::file_exists(dest_index)
  if (created_index) {
    fs::file_copy(src_index, dest_index, overwrite = FALSE)
    index_yml <- get_yaml(dest_index)
    cli::cli_alert_success("Copie de {.file index.qmd}")
  } else {
    cli::cli_alert_info("{.file index.qmd} déjà présent — non écrasé.")
  }

  # ---- 7. copie annexes.qmd et news.qmd (si absents) -----------------------
  for (qmd in c("annexes.qmd", "news.qmd")) {
    dest_qmd <- fs::path(root, qmd)
    if (!fs::file_exists(dest_qmd)) {
      fs::file_copy(fs::path(pkg_setup_wp, qmd), dest_qmd, overwrite = FALSE)
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
    check_fonts(quiet = TRUE),
    error = function(e)
      cli::cli_alert_warning("{.fn check_fonts} a \u00e9chou\u00e9 : {conditionMessage(e)}")
  )

  # ---- 9. extensions Quarto OFCE (source de vérité : ofce::setup_quarto()) --
  tryCatch({
    ofce::setup_quarto(root, quiet = TRUE)
    # `ofce::setup_quarto()` peut réussir (exit code 0) sans avoir réellement
    # posé les fichiers attendus : on vérifie donc la présence effective du
    # dossier, plutôt que de se fier uniquement à l’absence d’erreur R.
    if (fs::dir_exists(fs::path(root, "_extensions", "ofce"))) {
      cli::cli_alert_success(
        "Extensions Quarto OFCE install\u00e9es/mises \u00e0 jour ({.fn ofce::setup_quarto})."
      )
    } else {
      cli::cli_alert_warning(
        "{.fn ofce::setup_quarto} n'a signal\u00e9 aucune erreur mais \
         {.path _extensions/ofce/} est absent \u2014 v\u00e9rifier la connexion \
         r\u00e9seau et l'installation de Quarto ({.code quarto check})."
      )
    }
  }, error = function(e) {
    cli::cli_alert_warning("{.fn ofce::setup_quarto} a \u00e9chou\u00e9 : {conditionMessage(e)}")
  })
  check_stray_ofce_extensions(root)

  # ---- 10. copie des workflows (toujours mis à jour depuis le package) ------
  # Les workflows sont la source de vérité du package — l'utilisateur ne doit
  # pas les modifier. Force-remplacer à chaque appel.
  src_wf  <- fs::path(pkg_setup_wp, "workflows")
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
  # Idempotent : remplace la ligne codée en dur dans les workflows existants
  # par la référence à la variable GitHub. N'écrase pas un fichier déjà migré.
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
  # Idempotent : injecte l'étape de vérification de propriété (manifest.json
  # distant vs. github.repository) dans un ftp_deploy.yml existant qui ne
  # l'a pas encore, en la recopiant depuis le gabarit du package.
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
            "{.file .github/workflows/ftp_deploy.yml} : ajout de la v\u00e9rification anti-collision."
          )
        }
      }
    }
  }

  # ---- 10d. registre central (source de vérité pour wp/annee/draft) --------
  # Consulte ofceweb/wp-registry (sync_wp_registry_state(), partagée avec
  # publish_wp()) pour que _quarto.yml soit déjà correct et cohérent après
  # cet appel, sans attendre render_wp(). Une entrée confirmée pour ce dépôt
  # (source-repo correspondant) l'emporte toujours sur la valeur déjà présente
  # dans _quarto.yml : celle-ci ne reste utile que pour un dépôt pas encore
  # enregistré. En cas d'échec réseau, fail-soft : draft/wp/annee ne sont pas
  # modifiés et les valeurs existantes du YAML font foi ci-dessous.
  cli::cli_h2("Registre central")
  registry_state <- tryCatch(
    sync_wp_registry_state(root),
    error = function(e) {
      cli::cli_alert_warning("Synchronisation du registre ignor\u00e9e : {conditionMessage(e)}")
      NULL
    }
  )
  if (!is.null(registry_state) && !isTRUE(registry_state$network_error) &&
      !is.null(registry_state$registry_entry)) {
    wp             <- as.integer(registry_state$registry_entry$wp)
    annee          <- as.integer(registry_state$registry_entry$annee)
    wp_provided    <- TRUE
    annee_provided <- TRUE
  }

  # ---- 11. édition du _quarto.yml ------------------------------------------
  # Patch textuel : ne touche que les lignes des clés modifiées ci-dessous,
  # préservant commentaires, indentation et mise en page du reste du
  # fichier. `lines` est lu ICI (après la copie éventuelle du gabarit en
  # section 5, et après la synchronisation du registre en 10d, qui peut
  # avoir déjà réécrit draft/wp/annee sur disque) pour patcher le contenu
  # réel sur disque, et non un `yml` capturé avant que le gabarit n'existe.
  lines_before <- readLines(dest_yaml, warn = FALSE)
  lines <- lines_before

  # wp/annee/lang : écrire UNIQUEMENT si une valeur est déjà connue (yml
  # existant ou registre central) — pour un nouveau WP, le gabarit contient
  # déjà les valeurs par défaut ; pour un WP existant, l'absence d'un champ
  # est intentionnelle.
  if (wp_provided)    { yml$wp    <- wp;    lines <- yaml_patch_scalar_or_delete(lines, "wp", wp) }
  if (annee_provided) { yml$annee <- annee; lines <- yaml_patch_scalar(lines, "annee", annee) }
  if (lang_provided)  { yml$lang  <- lang;  lines <- yaml_patch_scalar(lines, "lang", lang) }
  # website.title : plus jamais écrit (cf. update_navbar(), qui supprime la
  # clé si elle est encore présente d'un appel antérieur) — le titre du WP
  # reste porté par la clé `title` au niveau racine, pas par `website.title`.

  # version : le gabarit le fournit pour les nouveaux WPs — jamais injecté
  # dans un fichier existant.

  # project.type : toujours forcé à "ofce-website" pour les WPs OFCE
  yml$project$type <- "ofce-website"
  lines <- yaml_patch_scalar(lines, "project.type", "ofce-website")

  # stage-target : source de vérité pour le routage du déploiement — toujours positionné
  yml$`stage-target` <- stage_target
  lines <- yaml_patch_scalar(lines, "stage-target", stage_target)

  # ofce_wp : marqueur de dépôt WP OFCE — toujours positionné
  yml$ofce_wp <- TRUE
  lines <- yaml_patch_scalar(lines, "ofce_wp", TRUE)

  # favicon : asset géré par le package — toujours resynchronisé, même sur
  # un _quarto.yml existant (le fichier www/fofce-wp.png est lui-même
  # réécrit à l'étape 8, quelle que soit la valeur historique de la clé).
  yml$website$favicon <- "www/fofce-wp.png"
  lines <- yaml_patch_scalar(lines, "website.favicon", "www/fofce-wp.png")

  # draft-mode : toujours resynchronisé, même sur un _quarto.yml existant qui
  # aurait été créé avant l’introduction de cette clé.
  yml$website$`draft-mode` <- "visible"
  lines <- yaml_patch_scalar(lines, "website.draft-mode", "visible")

  # repo-url : toujours calculé depuis le remote git — forcé à chaque appel
  repo_url <- sprintf("https://github.com/%s/%s/", gh_org, repo_name)
  yml$website$`repo-url` <- repo_url
  lines <- yaml_patch_scalar(lines, "website.repo-url", repo_url)

  # site-url / site-path : toujours recalculés — source de vérité pour les URLs
  # canoniques injectées dans le HTML rendu.
  #
  # Publié (wp non nul)   : site-url = www.ofce.fr,  site-path = {annee}/{wp}/[{version}/]
  # Brouillon gh-pages : site-url = {org}.github.io/{repo}/,         pas de site-path
  # Staging FTP        : site-url = staging.ofce.fr/{repo}/[{version}/], pas de site-path
  if (!is.null(wp)) {
    # Année effective : yml$annee est déjà à jour.
    effective_annee_sp <- suppressWarnings(as.integer(yml$annee %||% annee))
    if (is.na(effective_annee_sp)) effective_annee_sp <- annee
    yml$website$`site-url`  <- "https://www.ofce.fr/"
    lines <- yaml_patch_scalar(lines, "website.site-url", "https://www.ofce.fr/")
    site_path_base <- sprintf("%d/%d", effective_annee_sp, wp)
    if (isTRUE(versionning))
      site_path <- paste0(site_path_base, "/", version)
    else
      site_path <- site_path_base
    yml$version <- version
    lines <- yaml_patch_scalar_or_delete(lines, "version", version)

    # Les WPs créés avant l'abandon du zéro-padding portent un site-path de
    # la forme `2026/007` : la valeur recalculée l'écrase.
    old_site_path <- as.character(yml$website$`site-path` %||% "")
    if (nzchar(old_site_path) && !identical(old_site_path, site_path)) {
      cli::cli_alert_warning(
        "site-path modifié : {.val {old_site_path}} \u2192 {.val {site_path}} \r
         \u2014 le prochain déploiement ira sur une {.strong URL différente}."
      )
      cli::cli_alert_info(
        "L'ancien répertoire {.val {old_site_path}} reste en place sur le \r
         serveur : le supprimer ou y poser une redirection si nécessaire."
      )
    }

    yml$website$`site-path` <- site_path
    lines <- yaml_patch_scalar(lines, "website.site-path", site_path)
  } else {
    # Brouillon / staging — toujours recalculé depuis stage-target.
    yml$website$`site-path` <- NULL
    lines <- yaml_patch_delete(lines, "website.site-path")
    draft_site_url <- if (identical(stage_target, "ftp")) {
      ver_seg <- if (!is.null(version) && nzchar(as.character(version)))
        paste0(version, "/") else ""
      sprintf("https://staging.ofce.fr/%s/%s", repo_name, ver_seg)
    } else {
      sprintf("https://%s.github.io/%s/", gh_org, repo_name)
    }
    yml$website$`site-url`  <- draft_site_url
    lines <- yaml_patch_scalar(lines, "website.site-url", draft_site_url)
  }

  # citation.url / citation.issue : valeurs dérivées, toujours mises à jour
  # pour les WPs publiés afin que les citations ne se brisent pas lors des
  # mises à jour de version ou de numéro.
  # - citation.url  : URL stable (sans le segment de version), calculée
  #   directement depuis annee/wp — indépendamment de site-path — pour
  #   toujours pointer vers `www.ofce.fr/wp/{annee}/{wp}/`, l'URL publique
  #   réelle (cf. deploy_wp()'s stable_url).
  # - citation.issue: "{année}-{wp}" (le wp étant un entier, jamais de zéro
  #   de remplissage superflu, contrairement à l'ancien site-path zero-padded).
  if (!is.null(yml$wp)) {
    citation_annee <- suppressWarnings(as.integer(yml$annee))
    citation_wp    <- suppressWarnings(as.integer(yml$wp))
    if (!is.na(citation_annee) && !is.na(citation_wp)) {
      stable_url <- sprintf("https://www.ofce.fr/wp/%d/%d/", citation_annee, citation_wp)
      if (is.null(yml$citation)) yml$citation <- list()
      yml$citation$url <- stable_url
      lines <- yaml_patch_scalar(lines, "citation.url", stable_url)

      issue <- sprintf("%d-%d", citation_annee, citation_wp)
      yml$citation$issue <- issue
      lines <- yaml_patch_scalar(lines, "citation.issue", issue)
    }
  }

  # hypothesis : uniquement si fourni explicitement
  if (hypothesis_provided) {
    yml$comments <- list(hypothesis = isTRUE(hypothesis))
    lines <- yaml_patch_scalar(lines, "comments.hypothesis", isTRUE(hypothesis))
  }

  # output-file PDF : uniquement si wp ou annee sont déjà connus (yml existant
  # ou registre) ET si le format wp-pdf ou wp-typst est déjà déclaré dans le
  # YAML (ne pas injecter un format que le WP n'utilise pas)
  uses_wp_pdf <- is.list(index_yml$format) &&
    (is.list(index_yml$format$`wp-pdf`) || is.list(index_yml$format$`wp-typst`))
  if ((wp_provided || annee_provided) && uses_wp_pdf) {
    effective_wp    <- if (wp_provided)    wp    else yml$wp
    effective_annee <- if (annee_provided) annee else as.integer(yml$annee)
    pdf_output <- if (!is.null(effective_wp)) {
      sprintf("OFCEWP%d-%d.pdf", effective_annee, effective_wp)
    } else {
      "OFCEWP-draft.pdf"
    }
  } else {
    pdf_output <- index_yml$format$`wp-pdf`$`output-file` %||%
      index_yml$format$`wp-typst`$`output-file` %||% NA_character_
  }

  # N'écrire le fichier que si le contenu a réellement changé — évite le
  # bruit dans git diff quand rien n'a bougé.
  if (!identical(lines_before, lines)) {
    writeLines(lines, dest_yaml)
    cli::cli_alert_success("Mise à jour de {.file _quarto.yml}")
  } else {
    cli::cli_alert_info("{.file _quarto.yml} — aucun changement nécessaire.")
  }

  # Met aussi à jour l'output-file dans index.qmd (patch ciblé, préserve le
  # reste du frontmatter et le corps du document)
  tryCatch({
    yaml_patch_frontmatter_scalar(dest_index, "format.wp-pdf.output-file", pdf_output)
    cli::cli_alert_success("output-file mis à jour dans {.file index.qmd}")
  }, error = function(e) {
    cli::cli_alert_warning("Impossible de patcher index.qmd : {conditionMessage(e)}")
  })

  # ---- 11b. navbar (source centralisée du package) --------------------------
  tryCatch(
    update_navbar(root),
    error = function(e)
      cli::cli_alert_warning("update_navbar() a échoué : {conditionMessage(e)}")
  )

  # ---- 12. server-dir dans le workflow FTP ----------------------------------
  # yml$wp est la valeur effective : argument fourni (mis à jour en section 11)
  # ou valeur déjà présente dans le YAML. NULL uniquement pour les brouillons.
  if (!is.null(yml$wp)) {
    yml_after  <- tryCatch(yaml::read_yaml(dest_yaml), error = function(e) NULL)
    server_dir <- yml_after$website$`site-path`
    if (!is.null(server_dir) && nzchar(server_dir)) {
      if (!grepl("/$", server_dir)) server_dir <- paste0(server_dir, "/")
      set_gh_var(root, "FTP_SERVER_DIR", server_dir)
      # URL stable : répertoire parent du site-path (sans le segment de version)
      server_dir_clean <- sub("/$", "", server_dir)
      redirect_dir <- if (grepl("/v\\d+$", server_dir_clean)) {
        paste0(sub("/v\\d+$", "", server_dir_clean), "/")
      } else {
        paste0(server_dir_clean, "/")
      }
      set_gh_var(root, "FTP_REDIRECT_DIR", redirect_dir)
    }
  }

  # ---- 12b. FTP_STAGING_DIR (toujours, indépendant du numéro WP) -----------
  # Chemin FTP de staging : {repo}/{version}/
  # L'utilisateur FTP de staging a un chroot sur www/staging/, donc le chemin
  # effectif sur le serveur est www/staging/{repo}/{version}/.
  # Utilisé par ftp_stage.yml avec les credentials STAGING_USER/STAGING_PASSWORD.
  staging_slug    <- if (!is.na(gh$repo)) gh$repo else fs::path_file(root)
  staging_version <- yml$version
  staging_ver_seg <- if (!is.null(staging_version) && nzchar(as.character(staging_version)))
    paste0(staging_version, "/") else ""
  staging_dir <- sprintf("%s/%s", staging_slug, staging_ver_seg)
  set_gh_var(root, "FTP_STAGING_DIR", staging_dir)

  # ---- 13. .gitignore -------------------------------------------------------
  gi_path      <- fs::path(root, ".gitignore")
  gi_lines     <- if (fs::file_exists(gi_path)) readLines(gi_path, warn = FALSE) else character()
  tmpl_path    <- system.file("setup_wp/.gitignore", package = "ofceweb")
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
  cli::cli_li("wp          : {if (is.null(yml$wp)) 'brouillon (null)' else yml$wp}")
  cli::cli_li("annee       : {yml$annee}")
  cli::cli_li("version     : {yml$version}")
  cli::cli_li("lang        : {yml[['lang']]}")
  cli::cli_li("site-url    : {yml$website$`site-url`}")
  if (!is.null(yml$website$`site-path`))
    cli::cli_li("site-path   : {yml$website$`site-path`}")
  cli::cli_li("staging url : https://staging.ofce.fr/{staging_dir}")
  cli::cli_li("stage-target: {stage_target}")
  cli::cli_li("draft       : {if (is.null(registry_state) || isTRUE(registry_state$network_error)) '(non consulte)' else registry_state$stage}")
  if (!is.null(yml$citation$issue))
    cli::cli_li("citation issue: {yml$citation$issue}")
  if (!is.null(yml$citation$url))
    cli::cli_li("citation url: {yml$citation$url}")
  cli::cli_li("hypothesis  : {isTRUE(yml$comments$hypothesis)}")
  cli::cli_li("pdf         : {if (is.na(pdf_output)) '(non applicable)' else pdf_output}")

  cli::cli_bullets(
    c(
      ">" = "{.emph commiter} et {.emph pusher} les changements avant de lancer {.run ofceweb::render_wp()}."
  ))

  invisible(NULL)
}
