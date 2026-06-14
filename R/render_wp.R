#' Rendu complet d'un document de travail (WP) OFCE
#'
#' Orchestre le build complet d'un WP Quarto : vérification du dépôt git,
#' vérification de la structure WP, nettoyage de `_site/`, rendu Quarto
#' (HTML + PDF), construction du sitemap, patch des hashes Bootstrap,
#' écriture du manifeste, synchronisation de la variable GitHub Actions
#' `FTP_SERVER_DIR` (WPs publiés uniquement), et optionnellement déploiement
#' sur la branche de déploiement et prévisualisation locale.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param check_repo Logique. Si `TRUE` (défaut), vérifie l'état du dépôt git
#'   avant le rendu via [check_repo_status()].
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
#' @returns Invisible : sortie de [gert::git_status()].
#' @seealso [setup_wp()], [check_wp()], [deploy_wp()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists dir_delete dir_ls file_delete
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_text cli_alert_warning cli_alert_success
#' @importFrom tictoc tic toc
#' @importFrom servr daemon_stop httw
#' @importFrom future plan
#' @importFrom future.mirai mirai_multisession
#' @importFrom quarto quarto_render
#' @importFrom gert git_status
#' @section Working Paper (WP) Users:
#'
#' @export
render_wp <- function(
    path = ".",
    check_repo  = TRUE,
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

  # ---- 1. vérification du dépôt git ----------------------------------------
  if (check_repo) check_repo_status()

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
  future::plan(future.mirai::mirai_multisession, workers = workers)

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

  # ---- 6. patch hashes bootstrap -------------------------------------------
  cli::cli_h2("Patch des html (bootstrap css hashé)")
  tryCatch(patch_sitelibs_hashes(NULL, root, progress = progress),
           error = function(e)
             cli::cli_alert_warning("Patch site_libs ignoré : {conditionMessage(e)}"))

  # ---- 6.5. chiffrement statique (si encrypt_site: true) ------------------
  if (isTRUE(yml_top$encrypt_site)) {
    cli::cli_h2("Chiffrement staticrypt")
    staticryptR::staticryptr(
      files     = "_site",
      directory = ".",
      recursive = TRUE,
      password  = Sys.getenv("STATICRYPT_PASSWORD"),
      short     = TRUE,
      template_color_primary   = "#e6142d",
      template_color_secondary = "#f9f9f3",
      template_title        = "Accès restreint",
      template_instructions = "Entrez le mot de passe ou contactez un responsable de la page que vous souhaitez atteindre.",
      template_button       = "Accès"
    )
  }

  # ---- 7. manifeste --------------------------------------------------------
  cli::cli_h2("Écriture du manifest.json")
  tryCatch(wp_manifest(root),
           error = function(e)
             cli::cli_alert_warning("manifest.json non généré : {conditionMessage(e)}"))

  # ---- 7.5. synchronisation server-dir FTP ---------------------------------
  # site-path dans _quarto.yml est la source de vérité pour server-dir dans le
  # workflow FTP. On synchronise ici pour que le déploiement soit toujours
  # cohérent, même si le workflow a été copié depuis le gabarit (placeholder)
  # ou si la version a été incrémentée depuis le dernier setup.
  if (!is.null(yml_top) && !is.null(yml_top$wp)) {
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

  status <- gert::git_status(staged = TRUE)

  # ---- 8. déploiement / instruction ----------------------------------------
  if (site2branch) {
    ofceweb::site2branch(root, progress = progress, trigger = trigger)
  } else {
    cli::cli_text(
      "Pour déployer, lancer {.run ofceweb::deploy_wp()}")
  }

  # ---- 9. prévisualisation locale ------------------------------------------
  if (render_site) {
    cli::cli_h2("Prévisualisation locale")
    tryCatch(rewrite_absolute_hrefs(root),
             error = function(e)
               cli::cli_alert_warning(
                 "Réécriture des liens locaux ignorée : {conditionMessage(e)}"))
    servr::httw("_site", daemon = TRUE)
  }

  invisible(status)
}

#' Rendu et déploiement complet d'un document de travail (WP) OFCE
#'
#' Enchaîne [render_wp()] puis [deploy_wp()] : rend le WP, pousse `_site/`
#' vers la branche de déploiement FTP, et met à jour la page de redirection
#' vers l'URL stable (via [push_wp_redirect()]).
#'
#' @inheritParams render_wp
#' @param trigger Logique. Déclenche les workflows GitHub Actions FTP après le
#'   push. Défaut `TRUE`.
#'
#' @returns Invisible `NULL`.
#' @seealso [render_wp()], [deploy_wp()], [push_wp_redirect()], [setup_wp()]
#' @section Working Paper (WP) Users:
#'
#' @export
publish_wp <- function(
    path        = ".",
    check_repo  = TRUE,
    check       = TRUE,
    progress    = TRUE,
    render_site = TRUE,
    trigger     = TRUE,
    workers     = 8L) {
  render_wp(
    path        = path,
    check_repo  = check_repo,
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
