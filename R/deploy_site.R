#' Déploie le site selon l'hébergement déclaré dans `_quarto.yml`
#'
#' Lit la clé `ofce_host` du `_quarto.yml` à la racine du dépôt. Si `TRUE`,
#' délègue à [site2branch()] (push de `_site` vers la branche de déploiement
#' FTP) et affiche l'URL finale déduite de `website.site-url`/`site-path`.
#' Si `FALSE`, lance `quarto publish gh-pages` et affiche l'URL GitHub Pages
#' réellement servie, recalculée depuis le remote `origin` du dépôt (et non
#' `website.site-url`, qui décrit l'hébergement OFCE cible et non l'URL
#' GitHub Pages).
#'
#' @param path Chemin vers la racine du dépôt. Défaut `"."`.
#' @param progress Logique. Affichage de la progression. Défaut `TRUE`.
#' @param trigger Passé à [site2branch()] (hébergement OFCE uniquement).
#'   Défaut `TRUE`.
#' @param full_deploy Passé à [site2branch()]. Défaut `FALSE`.
#' @param ... Arguments supplémentaires passés à [site2branch()] le cas échéant.
#'
#' @returns Invisible `NULL`.
#' @seealso [site2branch()], [setup_site()]
#' @export
deploy_site <- function(
    path = ".",
    progress = TRUE,
    trigger = TRUE,
    full_deploy = FALSE,
    ...) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if(!fs::file_exists(yml_path))
    cli::cli_abort(
      "Pas de {.file _quarto.yml} dans {.path {root}}. Lancer {.run ofceweb::setup_site()}.")

  yml <- yaml::read_yaml(yml_path)
  ofce_host <- isTRUE(yml$ofce_host)

  # ---- Hébergement OFCE (site2branch \u2192 FTP) : l'URL finale vient de
  # website.site-url/site-path, qui décrit précisément où le contenu est
  # réellement servi dans ce cas. ---------------------------------------------
  if(ofce_host) {
    site_url <- yml$website$`site-url`
    site_path <- yml$website$`site-path`
    final_url <- NULL
    if(!is.null(site_url) && nzchar(site_url)) {
      final_url <- sub("/?$", "/", site_url)
      if(!is.null(site_path) && nzchar(site_path))
        final_url <- paste0(final_url, sub("^/", "", sub("/?$", "/", site_path)))
      final_url <- paste0(final_url, "index.html")
    }

    cli::cli_h2("Déploiement OFCE (site2branch)")
    res <- site2branch(
      path = root,
      progress = progress,
      trigger = trigger,
      full_deploy = full_deploy,
      ...)
    if(!is.null(final_url))
      cli::cli_alert_success("Site disponible : {.url {final_url}}")
    return(invisible(res))
  }

  # ---- GitHub Pages ----------------------------------------------------------
  # website.site-url dans _quarto.yml n'est pas fiable ici : il décrit
  # l'hébergement OFCE cible (souvent une URL staging.ofce.fr/www.ofce.fr),
  # pas l'URL GitHub Pages réellement servie par `quarto publish gh-pages`.
  # On la recalcule donc depuis le remote `origin` du dépôt (même logique
  # que deploy_wp()) plutôt que de faire confiance à une valeur potentiellement
  # trompeuse.
  gh_pages_url <- NULL
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
      gh_pages_url <- sprintf("https://%s.github.io/%s/index.html", m[[2]], m[[3]])
  }

  cli::cli_h2("Publication GitHub Pages (quarto publish gh-pages)")

  if(!fs::dir_exists(fs::path(root, "_site")))
    cli::cli_alert_warning(
      "Pas de dossier {.path _site} — Quarto va le générer.")

  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(root)

  status <- system2(
    "quarto",
    args = c("publish", "gh-pages", "--no-prompt", "--no-browser"))

  if(!identical(status, 0L))
    cli::cli_abort("Échec de {.code quarto publish gh-pages} (code {status}).")

  cli::cli_alert_success("Publié sur gh-pages")
  if(!is.null(gh_pages_url))
    cli::cli_alert_success("Site disponible : {.url {gh_pages_url}}")
  invisible(NULL)
}
