#' Rendu d'un site OFCE générique
#'
#' Lance un build complet du site Quarto pour le dépôt courant (initialisé via
#' [setup_site()]). Calque le fonctionnement de [render_blog()] mais pour un
#' site simple non bilingue : nettoyage de `_site`, rendu Quarto, reconstruction
#' du sitemap, patch des hash de `site_libs/`, déploiement optionnel et
#' prévisualisation locale.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param check_repo Logique. Si `TRUE` (défaut), vérifie l'état du dépôt git
#'   avant le rendu via [check_repo_status()].
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param render_site Logique. Si `TRUE` (défaut), lance un serveur HTTP local
#'   via [servr::httw()] sur `_site` après le rendu.
#' @param site2branch Logique. Si `TRUE`, appelle [site2branch()] pour pousser
#'   `_site` vers la branche de déploiement. Défaut `FALSE`.
#' @param trigger Passé à [site2branch()] pour déclencher le workflow GitHub
#'   Actions. Défaut égal à `site2branch`.
#' @param workers Entier. Nombre de workers parallèles. Défaut `8L`.
#'
#' @returns Invisible : sortie de [gert::git_status()].
#' @seealso [setup_site()], [stage_site()], [site2branch()], [render_blog()]
#' @importFrom fs path_expand path_abs path_norm path_file path file_exists dir_exists dir_delete dir_ls file_delete
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_text cli_alert_warning
#' @importFrom tictoc tic toc
#' @importFrom servr daemon_stop httw
#' @importFrom quarto quarto_render
#' @importFrom gert git_status git_remote_list
#' @export
render_site <- function(
    path = ".",
    check_repo = TRUE,
    progress = TRUE,
    render_site = TRUE,
    site2branch = FALSE,
    trigger = site2branch,
    workers = 8L) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  project <- fs::path_file(root) |> as.character()
  cli::cli_h1("repo {project}")

  if(!fs::file_exists(fs::path(root, "_quarto.yml")))
    cli::cli_abort(
      "Pas de {.file _quarto.yml} dans {.path {root}}. Lancer {.run ofceweb::setup_site()}.")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  if(check_repo) check_repo_status()

  tictoc::tic()
  servr::daemon_stop()

  if(fs::dir_exists("_site"))
    tryCatch(
      fs::dir_delete("_site"),
      error = function(e) { Sys.sleep(1); fs::dir_delete("_site") }
    )

  cli::cli_h2("Rendu Quarto")
  quarto::quarto_render(output_format = "all", as_job = FALSE)

  if(fs::dir_exists("_site"))
    fs::dir_ls("_site", recurse = TRUE, regexp = "DS_Store$",
               type = "file", all = TRUE) |>
      fs::file_delete()

  cli::cli_h2("Construction du sitemap")
  tryCatch(build_sitemap(root, progress = progress),
           error = function(e)
             cli::cli_alert_warning("Sitemap non généré : {conditionMessage(e)}"))

  cli::cli_h2("Patch des html (bootstrap css hashé)")
  tryCatch(patch_sitelibs_hashes(NULL, root, progress = progress),
           error = function(e)
             cli::cli_alert_warning("Patch site_libs ignoré : {conditionMessage(e)}"))

  tictoc::toc()

  status <- gert::git_status(staged = TRUE)

  if(site2branch)
    ofceweb::site2branch(root, progress = progress, trigger = trigger)
  else
    cli::cli_text(
      "Pour publier _site, lancer {.run ofceweb::deploy_site()}")

  if(render_site) {
    cli::cli_h2("Prévisualisation du site")
    # Réécrit les URLs absolues des other-links en chemins relatifs à chaque
    # page pour que la navigation fonctionne en local (servr).
    tryCatch(rewrite_absolute_hrefs(root),
             error = function(e)
               cli::cli_alert_warning(
                 "Réécriture des liens locale ignorée : {conditionMessage(e)}"))
    servr::httw("_site", daemon = TRUE)
  }

  invisible(status)
}

# Réécrit dans _site/**/*.html les occurrences de l'URL absolue du site
# (site-url + site-path) en chemins relatifs à chaque page.
# N'altère pas le _quarto.yml ; n'affecte que les fichiers HTML déjà rendus.
rewrite_absolute_hrefs <- function(root) {
  yml_path <- fs::path(root, "_quarto.yml")
  if(!fs::file_exists(yml_path)) return(invisible(NULL))
  yml <- yaml::read_yaml(yml_path)

  site_url  <- yml$website$`site-url`
  site_path <- yml$website$`site-path`
  bases <- character()
  if(!is.null(site_url) && nzchar(site_url)) {
    b <- sub("/?$", "/", site_url)
    if(!is.null(site_path) && nzchar(site_path))
      b <- paste0(b, sub("^/", "", sub("/?$", "/", site_path)))
    bases <- c(bases, b)
  }
  remotes <- tryCatch(gert::git_remote_list(repo = root),
                      error = function(e) NULL)
  if(!is.null(remotes) && nrow(remotes) > 0) {
    o <- remotes[remotes$name == "origin", , drop = FALSE]
    url <- if(nrow(o) > 0) o$url[[1]] else remotes$url[[1]]
    url2 <- sub("\\.git$", "", url)
    m <- if(grepl("^git@", url2))
      regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
    else
      regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
    if(length(m) >= 3)
      bases <- c(bases, sprintf("https://%s.github.io/%s/", m[[2]], m[[3]]))
  }
  bases <- unique(bases[nzchar(bases)])
  if(length(bases) == 0) return(invisible(NULL))

  site_dir <- fs::path(root, "_site")
  if(!fs::dir_exists(site_dir)) return(invisible(NULL))

  html_files <- fs::dir_ls(site_dir, recurse = TRUE, glob = "*.html", type = "file")
  n_patched <- 0L
  for(f in html_files) {
    rel_to_site <- fs::path_rel(f, site_dir)
    depth <- length(strsplit(as.character(rel_to_site), "/", fixed = TRUE)[[1]]) - 1L
    prefix <- if(depth <= 0) "" else paste(rep("../", depth), collapse = "")
    txt <- readLines(f, warn = FALSE, encoding = "UTF-8")
    new_txt <- txt
    for(b in bases)
      new_txt <- gsub(b, prefix, new_txt, fixed = TRUE)
    if(!identical(new_txt, txt)) {
      writeLines(new_txt, f, useBytes = TRUE)
      n_patched <- n_patched + 1L
    }
  }
  cli::cli_alert_success(
    "Liens locaux réécrits dans {n_patched} fichier{?s} HTML.")
  invisible(n_patched)
}


#' Rend et déploie un site OFCE générique
#'
#' Enchaîne [render_site()] (sans prévisualisation locale) puis [deploy_site()]
#' pour construire et pousser le site en une seule commande. Si le `site-path`
#' du `_quarto.yml` contient un segment de version (`/v[0-9]+`), appelle
#' automatiquement [push_site_redirect()] pour maintenir l'URL stable à jour.
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param check_repo Logique. Passé à [render_site()]. Défaut `TRUE`.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Passé à [deploy_site()] et [push_site_redirect()]. Défaut `TRUE`.
#' @param full_deploy Passé à [deploy_site()]. Défaut `FALSE`.
#' @param workers Entier. Nombre de workers parallèles pour le rendu. Défaut `8L`.
#'
#' @returns Invisible `NULL`.
#' @seealso [render_site()], [deploy_site()], [push_site_redirect()], [setup_site()]
#' @export
stage_site <- function(
    path        = ".",
    check_repo  = TRUE,
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE,
    workers     = 8L) {

  render_site(
    path        = path,
    check_repo  = check_repo,
    progress    = progress,
    render_site = FALSE,
    site2branch = FALSE,
    workers     = workers
  )

  deploy_site(
    path        = path,
    progress    = progress,
    trigger     = trigger,
    full_deploy = full_deploy
  )

  # Redirect vers la version courante (no-op si site-path sans segment /vN)
  push_site_redirect(path = path, progress = progress, trigger = trigger)

  invisible(NULL)
}
