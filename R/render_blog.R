#' Rend le blog bilingue
#'
#' Orchestre un build complet du blog Quarto en français et en anglais.
#' Reconstruit la base des posts, rend chaque version de langue en parallèle,
#' met à jour l'index de recherche Algolia et le sitemap, patche les hash CSS
#' Bootstrap, commite les changements de cache dans git et, en option,
#' déploie le site ou lance un serveur de prévisualisation local.
#'
#' La fonction doit être exécutée depuis un projet RStudio contenant un
#' répertoire `posts/`. Elle s'attend aussi à ce que le projet se trouve dans
#' un répertoire nommé `webblog` et demande confirmation dans le cas
#' contraire.
#'
#' Deux variables sont lues depuis l'environnement appelant (pas des
#' arguments de la fonction) :
#' - `typst` : transmise à [copy_post()] pour contrôler le rendu PDF Typst.
#' - `push_site_deploy` : si `TRUE`, appelle [site2branch()] pour pousser
#'   `_site` vers la branche de déploiement ; sinon affiche les instructions
#'   pour le faire manuellement.
#'
#' @param path Chemin vers le dossier du blog. Défaut `"."`.
#' @param force_freeze Logique. Si `TRUE` (défaut), les posts sont re-rendus
#'   même si une version en cache existe. Mettre `FALSE` pour réutiliser le
#'   cache autant que possible.
#' @param workers Entier. Nombre de workers parallèles transmis à
#'   [future.mirai::mirai_multisession()]. Défaut `8L`.
#' @param check_repo Logique. Si `TRUE` (défaut), appelle
#'   [check_repo_status()] avant le rendu pour s'assurer que le dépôt git est
#'   dans un état propre.
#' @param progress Logique. Si `TRUE` (défaut), des barres de progression
#'   sont affichées pendant les étapes longues.
#' @param render_site Logique. Si `TRUE` (défaut), démarre un démon HTTP
#'   local via [servr::httw()] pour prévisualiser `_site` une fois le build
#'   terminé.
#' @param check_freeze Logique. Si `TRUE`, la fonction s'arrête dès qu'un post
#'   est absent du cache (mode freeze strict). Défaut `FALSE`.
#' @param site2branch Logique. Paramètre réservé (actuellement inutilisé dans
#'   le corps de la fonction ; le déploiement est contrôlé par la variable
#'   d'environnement `push_site_deploy`). Défaut `FALSE`.
#' @param trigger Logique. Transmis à [site2branch()] pour déclencher en
#'   option un workflow GitHub Actions après le déploiement. Défaut `FALSE`.
#' @param freeze Logique. Si `TRUE` (défaut), transmis à [copy_files()] pour
#'   activer le mode freeze de Quarto lors de la copie de l'ossature du
#'   projet.
#'
#' @return Un data frame des changements git préparés (sortie de
#'   [gert::git_status()]), renvoyé invisiblement.
#'
#' @seealso [site2branch()]
#' @export
#'
#' @examples
#' \dontrun{
#' render_blog()
#' }

render_blog <- function(
    path = ".",
    force_freeze = TRUE,
    workers = 8L,
    check_repo = TRUE,
    progress = TRUE,
    render_site = TRUE,
    check_freeze = FALSE,
    site2branch = FALSE,
    trigger = site2branch, freeze = TRUE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  project <- fs::path_file(root) |> as.character()
  cli::cli_h1("repo {project}")

  typst <- TRUE

  if(!dir.exists(fs::path_join(c(root, "posts")))) {
    cli::cli_abort("Le projet ne contient pas de dossier posts")
  }

  if(project != "webblog") {
    cli::cli_alert_danger(
      "Ce n'est pas le repo {.emph webblog}, mais {.emph {project}}")
    answer <- readline("Etes vous sûr.e de vouloir continuer ? [o/N] ")
    if (!tolower(answer) %in% c("o", "oui"))
      cli::cli_abort("ABORT")
  }
  oldwd <- getwd()
  on.exit({
    setwd(oldwd)
    }
    )
  setwd(root)

  if (check_repo) check_repo_status()

  tictoc::tic()
  servr::daemon_stop()
  future::plan(future.mirai::mirai_multisession, workers = workers)
  posts <- posts_db("posts")
  qs2::qs_save(posts, "posts_db.qs2")

  if(fs::dir_exists("_site"))
    tryCatch(
      fs::dir_delete("_site"),
      error = function(e) { Sys.sleep(1); fs::dir_delete("_site") }
    )

  # en français
  cli::cli_h2("Génération du blog en {.emph français}")
  copy_files("fr", freeze = freeze, progress = progress)
  copy_post(
    posts = posts,
    lang = "fr",
    typst = typst,
    force_freeze = force_freeze,
    progress = progress)
  cached_fr <- get_from_cache(
    lang = "fr",
    root = root,
    force_freeze = force_freeze,
    progress = progress)
  render_lang("fr", posts, root)
  cache_posts(
    cached_fr,
    "fr",
    root,
    progress = progress)
  sync_back_sourcoise(cached_fr, "fr")

  # en anglais
  cli::cli_h2("Génération du blog en {.emph anglais}")
  copy_files("en", freeze = freeze)
  copy_post(
    posts = posts,
    lang = "en",
    typst = typst,
    force_freeze = force_freeze,
    progress = progress)
  cached_en <- get_from_cache(
    lang = "en",
    root = root,
    force_freeze = force_freeze,
    progress = progress)

  render_lang("en", posts, root)
  cache_posts(
    cached_en,
    "en",
    root,
    progress = progress)
  sync_back_sourcoise(cached_en, "en")

  if (check_freeze) {
    uncached <- dplyr::bind_rows(cached_fr, cached_en) |>
      dplyr::filter(!from_cache)
    if (nrow(uncached) > 0) {
      cli::cli_abort(c(
        "Mode freeze: {nrow(uncached)} post{?s} absent{?s} du cache.",
        i = "Posts: {uncached$name}",
        i = "Relancer avec FORCE_FREEZE=false ou mettre \u00e0 jour _posts_cache/."))
    }
  }

  fs::dir_ls("_site", recurse=TRUE, regexp = "DS_Store$",  type = "file", all = TRUE) |>
    fs::file_delete()

  cli::cli_h2("Indexation des contenus textes pour Algolia")
  augment_search(root, progress = progress)

  cli::cli_h2("Construction du sitemap complet")
  build_sitemap(root, progress = progress)

  cli::cli_h2("Patch des html (bootstrap css hashé)")
  patch_sitelibs_hashes(
    dplyr::bind_rows(cached_fr, cached_en),
    root,
    progress = progress)

  tictoc::toc()
  now <- lubridate::stamp("28/12/2026 12:32:54", quiet=TRUE)(lubridate::now(tzone = "Europe/Paris"))
  cache <- gert::git_add("_posts_cache", force=TRUE)
  gert::git_add("posts_db.qs2", force=TRUE)
  gert::git_add("posts", force=FALSE)
  ds_store <- gert::git_status(staged = TRUE) |>
    dplyr::filter(stringr::str_detect(file, "DS_Store$"), staged)
  status <- gert::git_status(staged = TRUE)

  if (nrow(status) > 0) {
    cli::cli_alert_info("changements commit 'Full render {now}'")
    gert::git_commit("Full render {now}" |> glue::glue())
  } else {
    cli::cli_alert_info("Rien de nouveau dans _posts_cache.")
  }
  if (nrow(ds_store) > 0)
    gert::git_rm(ds_store$file)

  if(nrow(status) > 0)
    cli::cli_h2(
      "Commit '_posts_cache' (Full render \u00e0 {now}), {.emph push} possible")

  if (site2branch)
    ofceweb::site2branch(root, progress = progress, trigger = trigger)
  else {
    cli::cli_text(
      "Pour publier _site, lancer {.run ofceweb::site2branch()}"
    )
  }

  if(render_site) {
    cli::cli_h2("Render du site")
    servr::httw("_site", daemon = TRUE)
  }
  return(invisible(status))
}

#' Publie le blog bilingue
#'
#' Enveloppe pratique autour de [render_blog()] qui fixe `site2branch = TRUE`
#' pour déployer `_site` vers la branche de déploiement après le rendu.
#'
#' @inheritParams render_blog
#' @return Un data frame des changements git préparés, renvoyé invisiblement.
#' @seealso [render_blog()], [site2branch()]
#' @export
#'
#' @examples
#' \dontrun{
#' publish_blog()
#' }
publish_blog <- function(
    path = ".",
    force_freeze = TRUE,
    workers = 8L,
    check_repo = TRUE,
    progress = TRUE,
    render_site = FALSE,
    check_freeze = FALSE,
    trigger = TRUE,
    freeze = TRUE) {
  render_blog(
    path = path,
    force_freeze = force_freeze,
    workers = workers,
    check_repo = check_repo,
    progress = progress,
    render_site = render_site,
    check_freeze = check_freeze,
    site2branch = TRUE,
    trigger = trigger,
    freeze = freeze
  )
}

# Helpers -----------------------------------

render_lang <- function(lang = "fr", posts, root) {
  cli::cli_h2("Rendu du site en {lang}")
  dir <- stringr::str_c("_", lang)
  profile_yml <- glue::glue("_quarto-{lang}.yml")
  output_dir <- "_site"

  setwd(dir)

  yaml <- get_yaml(profile_yml)
  yaml$project[["output-dir"]] <- output_dir
  put_yaml(yaml, profile_yml)

  yaml <- get_yaml("index.qmd")
  if(!lang%in% yaml$listing$contents) {
    yaml$listing$contents <- lang
    put_yaml(yaml, "index.qmd")
  }

  quarto::quarto_render(profile = lang, output_format = "all", as_job = FALSE)

  setwd(root)
  output_dir <- fs::path_join(c(dir, output_dir))
  if(lang=="fr") {
    fs::dir_copy("_fr/_site", "_site", overwrite=TRUE)
  }
  if(lang=="en") {
    if(fs::dir_exists("_en/_site/en"))
      fs::dir_copy("_en/_site/en", "_site/en", overwrite=TRUE)
    fs::file_move("_en/_site/index.html", "_site/index.en.html")
    #fs::file_move("_en/_site/index.html", "_site/about.en.html")
    fs::dir_delete("_en/_site")
  }
}
