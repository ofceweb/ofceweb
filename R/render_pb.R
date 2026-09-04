#' Rendu complet d'un policy brief (PB) OFCE
#'
#' Équivalent PB de [render_wp()]. Orchestre le build complet d'un PB Quarto :
#' vérification du dépôt git, vérification de la structure PB, lecture de l'état
#' `stage` (staging ou publié) depuis la clé `draft` de `_quarto.yml`. **La
#' consultation du registre central (`ofce/wp-registry`, sous-dossier `pb/`) ne se fait plus ici** :
#' elle a lieu en amont, dans [setup_pb()] (et à nouveau dans [publish_pb()]) —
#' `render_pb()` suppose que `draft`/`pb`/`annee` sont déjà synchronisés dans
#' `_quarto.yml` et se contente de les lire, sans accès réseau. Suivent le
#' nettoyage de `_site/`, le rendu Quarto (HTML + PDF), la construction du
#' sitemap, l'écriture du manifeste, la synchronisation de `FTP_SERVER_DIR`
#' (PBs publiés confirmés uniquement), et optionnellement le déploiement et la
#' prévisualisation locale.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param check Logique. Si `TRUE` (défaut), appelle [check_pb()] avant le rendu
#'   et abandonne si des erreurs bloquantes sont détectées.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param render_site Logique. Si `TRUE` (défaut), lance un serveur HTTP local
#'   via [servr::httw()] sur `_site/` après le rendu.
#' @param site2branch Logique. Si `TRUE`, pousse `_site/` vers la branche de
#'   déploiement via [site2branch()]. Défaut `FALSE`.
#' @param trigger Passé à [site2branch()]. Défaut = valeur de `site2branch`.
#' @param workers Entier. Nombre de workers parallèles pour le rendu. Défaut
#'   `8L`.
#' @param ... Arguments supplémentaires ignorés (compatibilité avec les appels
#'   CI historiques, ex. `check_repo`).
#'
#' @returns Invisible NULL.
#' @seealso [setup_pb()], [check_pb()], [deploy_pb()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists dir_delete dir_ls file_delete
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_text cli_alert_warning cli_alert_success
#' @importFrom tictoc tic toc
#' @importFrom servr daemon_stop httw
#' @importFrom quarto quarto_render
#' @export
render_pb <- function(
    path = ".",
    check       = TRUE,
    progress    = TRUE,
    render_site = TRUE,
    site2branch = FALSE,
    trigger     = site2branch,
    workers     = 8L,
    ...) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  project <- fs::path_file(root) |> as.character()
  cli::cli_h1("render_pb : {project}")

  if (!fs::file_exists(fs::path(root, "_quarto.yml")))
    cli::cli_abort(
      "Pas de {.file _quarto.yml} dans {.path {root}}. Lancer {.run ofceweb::setup_pb()}.")

  # Vérifier le flag ofce_pb
  yml_top <- tryCatch(yaml::read_yaml(fs::path(root, "_quarto.yml")),
                      error = function(e) NULL)
  if (!is.null(yml_top) && !isTRUE(yml_top$ofce_pb))
    cli::cli_alert_warning(
      "Le {.file _quarto.yml} ne contient pas {.code ofce_pb: true}. \\
       Ce dépôt a-t-il bien été initialisé avec {.run ofceweb::setup_pb()} ?")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  # ---- 2. vérification de la structure PB ----------------------------------
  if (check) {
    diags <- check_pb(root, verbose = TRUE)
    n_err <- sum(diags$status == "error")
    if (n_err > 0L)
      cli::cli_abort(
        "{n_err} erreur{?s} bloquante{?s} détectée{?s} par check_pb(). \\
         Corriger avant de lancer render_pb().")
  }

  tictoc::tic()
  servr::daemon_stop()

  # ---- 2.5. état registre : lu directement depuis _quarto.yml --------------
  stage <- if (!is.null(yml_top) && !is.null(yml_top$draft)) {
    isTRUE(yml_top$draft)
  } else {
    cli::cli_alert_warning(
      "Pas de clé {.code draft} dans {.file _quarto.yml} — état registre non \\
       synchronisé. Lancer {.run ofceweb::setup_pb()} avant de rendre. \\
       Valeur par défaut : {.val TRUE} (staging).")
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
  tryCatch(pb_manifest(root, stage = stage),
           error = function(e)
             cli::cli_alert_warning("manifest.json non généré : {conditionMessage(e)}"))

  # ---- 6.5. synchronisation server-dir FTP ---------------------------------
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
      "Pour déployer, lancer {.run ofceweb::deploy_pb()}")
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

#' Rendu et déploiement complet d'un policy brief (PB) OFCE
#'
#' Équivalent PB de [publish_wp()]. Rafraîchit l'état du registre central
#' (`ofce/wp-registry`, sous-dossier `pb/`, via `sync_pb_registry_state()`) — pour rattraper un
#' enregistrement survenu depuis le dernier [setup_pb()] — puis enchaîne
#' [render_pb()] et [deploy_pb()]. Ce rafraîchissement ne recalcule que
#' `draft`/`pb`/`annee` ; si le numéro PB change à cette étape, un avertissement
#' invite à relancer [setup_pb()] pour recalculer les champs dérivés
#' (`site-path`, `citation.*`, `FTP_SERVER_DIR`).
#'
#' @inheritParams render_pb
#' @param trigger Logique. Déclenche les workflows GitHub Actions FTP après le
#'   push. Défaut `TRUE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [render_pb()], [deploy_pb()], [push_pb_redirect()], [setup_pb()]
#' @export
publish_pb <- function(
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

  qyml_path <- fs::path(root, "_quarto.yml")
  pb_before <- if (fs::file_exists(qyml_path))
    tryCatch(yaml::read_yaml(qyml_path)$pb, error = function(e) NULL) else NULL

  cli::cli_h2("Registre central")
  reg <- tryCatch(sync_pb_registry_state(root), error = function(e) {
    cli::cli_alert_warning("Synchronisation du registre ignorée : {conditionMessage(e)}")
    NULL
  })

  if (!is.null(reg) && isTRUE(reg$network_error)) {
    if (!is.null(pb_before))
      cli::cli_alert_warning(
        "Registre inaccessible — {.field pb}/{.field annee} effacés de \\
         {.file _quarto.yml} (était {.val {pb_before}}), {.code draft: true} forcé. \\
         Ce rendu sera traité comme un brouillon. Relancer {.run ofceweb::publish_pb()} \\
         une fois le registre de nouveau accessible pour publier en production.")
  } else if (!is.null(reg) && !isTRUE(reg$network_error)) {
    pb_after <- if (!is.null(reg$registry_entry)) as.integer(reg$registry_entry$pb) else NULL
    if (!is.null(pb_after) && !identical(pb_before, pb_after)) {
      cli::cli_alert_warning(
        "Numéro PB mis à jour depuis le registre ({.val {pb_before}} → {.val {pb_after}}) \\
         — relancer {.run ofceweb::setup_pb()} pour recalculer {.field site-path}/\\
         {.field citation.*}/{.field FTP_SERVER_DIR} avant de publier.")
    }
  }

  render_pb(
    path        = path,
    check       = check,
    progress    = progress,
    render_site = render_site,
    site2branch = FALSE,
    workers     = workers
  )
  deploy_pb(
    path        = path,
    progress    = progress,
    trigger     = trigger
  )
}
