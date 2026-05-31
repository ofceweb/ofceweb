#' Render the bilingual blog
#'
#' Orchestrates a full build of the Quarto blog in both French and English.
#' It rebuilds the posts database, renders each language version in parallel,
#' updates the Algolia search index and sitemap, patches Bootstrap CSS hashes,
#' commits cache changes to git, and optionally deploys the site or launches a
#' local preview server.
#'
#' The function must be run from within an RStudio project that contains a
#' `posts/` directory. It also expects the project to live under a directory
#' named `webblog` and will prompt for confirmation otherwise.
#'
#' Two variables are read from the calling environment (not function arguments):
#' - `typst`: passed to [copy_post()] to control Typst PDF rendering.
#' - `push_site_deploy`: if `TRUE`, calls [site2branch()] to push `_site` to the
#'   deployment branch; otherwise prints instructions for doing so manually.
#'
#' @param path Character path to the blog folder, default to ".".
#' @param force_freeze Logical. If `TRUE` (default), posts are re-rendered even
#'   when a cached version exists. Set to `FALSE` to reuse the cache wherever
#'   possible.
#' @param workers Integer. Number of parallel workers passed to
#'   [future.mirai::mirai_multisession()]. Defaults to `8L`.
#' @param check_repo Logical. If `TRUE` (default), calls [check_repo_status()]
#'   before rendering to ensure the git repository is in a clean state.
#' @param progress Logical. If `TRUE` (default), progress bars are displayed
#'   during long-running steps.
#' @param render_site Logical. If `TRUE` (default), starts a local HTTP daemon
#'   via [servr::httw()] to preview `_site` after the build completes.
#' @param check_freeze Logical. If `TRUE`, the function aborts when any post is
#'   missing from the cache (strict freeze mode). Defaults to `FALSE`.
#' @param site2branch Logical. Reserved parameter (currently unused inside the
#'   function body; deployment is controlled by the `push_site_deploy`
#'   environment variable). Defaults to `FALSE`.
#' @param trigger Logical. Passed to [site2branch()] to optionally trigger a
#'   GitHub Actions workflow after deploying. Defaults to `FALSE`.
#' @param freeze Logical. If `TRUE` (default), passed to [copy_files()] to
#'   enable Quarto freeze mode when copying project scaffolding.
#'
#' @return A data frame of staged git changes (output of [gert::git_status()]),
#'   returned invisibly.
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

#' Publish the bilingual blog
#'
#' A convenience wrapper around [render_blog()] that sets `site2branch = TRUE`
#' to deploy `_site` to the deployment branch after rendering.
#'
#' @inheritParams render_blog
#' @return A data frame of staged git changes, returned invisibly.
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
    render_site = TRUE,
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
