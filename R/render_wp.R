#' Rendu complet d'un document de travail (WP) OFCE
#'
#' Orchestre le build complet d'un WP Quarto : vérification du dépôt git,
#' vérification de la structure WP, lecture de l'état `stage` (staging ou
#' publié) depuis la clé `draft` de `_quarto.yml` (lue par les extensions
#' `ofce-quarto-extensions` pour le bandeau « Version provisoire »). **La
#' consultation du registre central (`ofceweb/wp-registry`) ne se fait plus
#' ici** : elle a lieu en amont, dans [setup_wp()] (et à nouveau dans
#' [publish_wp()] juste avant l'appel à `render_wp()`) — `render_wp()`
#' suppose que `draft`/`wp`/`annee` sont déjà synchronisés dans
#' `_quarto.yml` et se contente de les lire, sans accès réseau. Suivent le
#' nettoyage de `_site/`, le rendu Quarto (HTML + PDF),
#' construction du sitemap, écriture du manifeste (champ `stage` inclus), synchronisation
#' de `FTP_SERVER_DIR` (WPs publiés confirmés uniquement), et optionnellement
#' déploiement sur la branche de déploiement et prévisualisation locale.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param check Logique. Si `TRUE` (défaut), appelle [check_wp()] avant le
#'   rendu et abandonne si des erreurs bloquantes sont détectées.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param render_site Logique. Si `TRUE` (défaut), lance un serveur HTTP local
#'   via [servr::httw()] sur `_site/` après le rendu.
#' @param site2branch Logique. Si `TRUE`, pousse `_site/` vers la branche de
#'   déploiement via [site2branch()]. Défaut `FALSE`.
#' @param trigger Passé à [site2branch()]. Défaut = valeur de `site2branch`.
#' @param workers Entier. Nombre de workers parallèles pour le rendu. Défaut
#'   `8L`.
#'
#' @returns Invisible NULL.
#' @seealso [setup_wp()], [check_wp()], [deploy_wp()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists dir_delete dir_ls file_delete
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_text cli_alert_warning cli_alert_success
#' @importFrom tictoc tic toc
#' @importFrom servr daemon_stop httw
#' @importFrom quarto quarto_render
#' @export
render_wp <- function(
    path = ".",
    check       = TRUE,
    progress    = TRUE,
    render_site = TRUE,
    site2branch = FALSE,
    trigger     = site2branch,
    workers     = 8L) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  project <- fs::path_file(root) |> as.character()
  cli::cli_h1("render_wp : {project}")

  if (!fs::file_exists(fs::path(root, "_quarto.yml")))
    cli::cli_abort(
      "Pas de {.file _quarto.yml} dans {.path {root}}. Lancer {.run ofceweb::setup_wp()}.")

  # Vérifier le flag ofce_wp
  yml_top <- tryCatch(yaml::read_yaml(fs::path(root, "_quarto.yml")),
                      error = function(e) NULL)
  if (!is.null(yml_top) && !isTRUE(yml_top$ofce_wp))
    cli::cli_alert_warning(
      "Le {.file _quarto.yml} ne contient pas {.code ofce_wp: true}. \\
       Ce dépôt a-t-il bien été initialisé avec {.run ofceweb::setup_wp()} ?")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  # ---- 2. vérification de la structure WP ----------------------------------
  if (check) {
    diags <- check_wp(root, verbose = TRUE)
    n_err <- sum(diags$status == "error")
    if (n_err > 0L)
      cli::cli_abort(
        "{n_err} erreur{?s} bloquante{?s} détectée{?s} par check_wp(). \\
         Corriger avant de lancer render_wp().")
  }

  tictoc::tic()
  servr::daemon_stop()

  # ---- 2.5. état registre : lu directement depuis _quarto.yml --------------
  # La consultation du registre central (ofceweb/wp-registry) et la
  # synchronisation de `draft`/`wp`/`annee` se font désormais en amont, dans
  # setup_wp() et publish_wp() (sync_wp_registry_state()) — pas ici. render_wp()
  # se contente de lire l'état déjà persisté, sans accès réseau : `draft`
  # (lu par les extensions ofce-quarto-extensions pour le bandeau « Version
  # provisoire ») fait foi pour `stage`, utilisé plus bas pour le manifeste
  # et la synchronisation de FTP_SERVER_DIR.
  stage <- if (!is.null(yml_top) && !is.null(yml_top$draft)) {
    isTRUE(yml_top$draft)
  } else {
    cli::cli_alert_warning(
      "Pas de cl\u00e9 {.code draft} dans {.file _quarto.yml} \u2014 \u00e9tat registre non \\
       synchronis\u00e9. Lancer {.run ofceweb::setup_wp()} avant de rendre. \\
       Valeur par d\u00e9faut : {.val TRUE} (staging).")
    TRUE
  }

  # ---- 3. vider _site/ -----------------------------------------------------
  if (fs::dir_exists("_site"))
    tryCatch(
      fs::dir_delete("_site"),
      error = function(e) { Sys.sleep(1); fs::dir_delete("_site") }
    )

  # ---- 4. rendu Quarto (HTML + PDF) ----------------------------------------
  cli::cli_h2("Rendu Quarto (HTML + PDF)")
  quarto::quarto_render(output_format = "all", as_job = FALSE)

  # Nettoyer les DS_Store
  if (fs::dir_exists("_site"))
    fs::dir_ls("_site", recurse = TRUE, regexp = "DS_Store$",
               type = "file", all = TRUE) |>
      fs::file_delete()

  # ---- 5. sitemap ----------------------------------------------------------
  cli::cli_h2("Construction du sitemap")
  tryCatch(build_sitemap(root, progress = progress),
           error = function(e)
             cli::cli_alert_warning("Sitemap non généré : {conditionMessage(e)}"))

  # ---- 6. manifeste --------------------------------------------------------
  cli::cli_h2("Écriture du manifest.json")
  tryCatch(wp_manifest(root, stage = stage),
           error = function(e)
             cli::cli_alert_warning("manifest.json non généré : {conditionMessage(e)}"))

  # ---- 6.5. synchronisation server-dir FTP ---------------------------------
  # site-path dans _quarto.yml est la source de vérité pour server-dir dans le
  # workflow FTP. On synchronise ici pour que le déploiement soit toujours
  # cohérent, même si le workflow a été copié depuis le gabarit (placeholder)
  # ou si la version a été incrémentée depuis le dernier setup.
  if (!is.null(yml_top) && isFALSE(stage)) {
    server_dir <- yml_top$website$`site-path`
    if (!is.null(server_dir) && nzchar(server_dir)) {
      if (!grepl("/$", server_dir)) server_dir <- paste0(server_dir, "/")
      tryCatch(
        set_gh_var(root, "FTP_SERVER_DIR", server_dir),
        error = function(e)
          cli::cli_alert_warning("FTP_SERVER_DIR non mis à jour : {conditionMessage(e)}")
      )
    }
  }

  tictoc::toc()

  # ---- 7. déploiement / instruction -----------------------------------------
  if (site2branch) {
    ofceweb::site2branch(root, progress = progress, trigger = trigger)
  } else {
    cli::cli_text(
      "Pour déployer, lancer {.run ofceweb::deploy_wp()}")
  }

  # ---- 8. prévisualisation locale --------------------------------------------
  if (render_site) {
    cli::cli_h2("Prévisualisation locale")
    tryCatch(rewrite_absolute_hrefs(root),
             error = function(e)
               cli::cli_alert_warning(
                 "Réécriture des liens locaux ignorée : {conditionMessage(e)}"))
    servr::httw("_site", daemon = TRUE)
  }

  invisible(NULL)
}

#' Rendu et déploiement complet d'un document de travail (WP) OFCE
#'
#' Rafraîchit l'état du registre central (`ofceweb/wp-registry`, via
#' `sync_wp_registry_state()`) — pour rattraper un enregistrement survenu
#' depuis le dernier [setup_wp()] — puis enchaîne [render_wp()] et
#' [deploy_wp()] : rend le WP, pousse `_site/` vers la branche de
#' déploiement FTP, et met à jour la page de redirection vers l'URL stable
#' (via [push_wp_redirect()]). Ce rafraîchissement ne recalcule que
#' `draft`/`wp`/`annee` ; si le numéro WP change à cette étape, un
#' avertissement invite à relancer [setup_wp()] pour recalculer les champs
#' dérivés (`site-path`, `citation.*`, `FTP_SERVER_DIR`).
#'
#' @inheritParams render_wp
#' @param trigger Logique. Déclenche les workflows GitHub Actions FTP après le
#'   push. Défaut `TRUE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [render_wp()], [deploy_wp()], [push_wp_redirect()], [setup_wp()]
#' @export
publish_wp <- function(
    path        = ".",
    check       = TRUE,
    progress    = TRUE,
    render_site = TRUE,
    trigger     = TRUE,
    workers     = 8L) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  # ---- rafraîchir l'état registre avant le rendu ---------------------------
  # Rattrape le cas où le dépôt a été enregistré (PR wp-registry fusionnée)
  # depuis le dernier setup_wp(). Ne recalcule pas site-path/citation.*/
  # FTP_SERVER_DIR/FTP_REDIRECT_DIR (source de vérité : setup_wp()) — un
  # avertissement invite à relancer setup_wp() si wp/annee changent ici.
  qyml_path <- fs::path(root, "_quarto.yml")
  wp_before <- if (fs::file_exists(qyml_path))
    tryCatch(yaml::read_yaml(qyml_path)$wp, error = function(e) NULL) else NULL

  cli::cli_h2("Registre central")
  reg <- tryCatch(sync_wp_registry_state(root), error = function(e) {
    cli::cli_alert_warning("Synchronisation du registre ignor\u00e9e : {conditionMessage(e)}")
    NULL
  })

  if (!is.null(reg) && !isTRUE(reg$network_error)) {
    wp_after <- if (!is.null(reg$registry_entry)) as.integer(reg$registry_entry$wp) else NULL
    if (!is.null(wp_after) && !identical(wp_before, wp_after)) {
      cli::cli_alert_warning(
        "Num\u00e9ro WP mis \u00e0 jour depuis le registre ({.val {wp_before}} \u2192 {.val {wp_after}}) \\
         \u2014 relancer {.run ofceweb::setup_wp()} pour recalculer {.field site-path}/\\
         {.field citation.*}/{.field FTP_SERVER_DIR} avant de publier.")
    }
  }

  render_wp(
    path        = path,
    check       = check,
    progress    = progress,
    render_site = render_site,
    site2branch = FALSE,
    workers     = workers
  )
  deploy_wp(
    path        = path,
    progress    = progress,
    trigger     = trigger
  )
}
