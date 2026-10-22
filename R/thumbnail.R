#' Reporte les vignettes générées pendant le rendu vers les posts source
#'
#' Pendant l'exécution d'un post, le hook `thumbnail_hook()` du blog
#' (`_utils/thumbnail.R`) écrit l'image déclarée dans le YAML (`image:`) à
#' partir du premier ggplot passé à `girafy()`. Cette image n'existe que dans
#' la copie de rendu (`_fr/fr/...`) : elle est ici recopiée dans `posts/`.
#'
#' Pour chaque post re-rendu, l'image est reportée si elle a été générée,
#' c'est-à-dire si des graphes ont été enregistrés dans `_sav_graph/` pour ce
#' document, et si elle est absente de `posts/` (ou nommée `thumbnail*` ou
#' `fig-*.png`, donc régénérée à chaque exécution). Une image fournie par
#' l'auteur n'est jamais écrasée.
#'
#' Avec `image: fig-{label}` dans le YAML du post (transformé en
#' `fig-{label}.png` par [copy_post()]), la vignette vient du chunk `{label}`.
#'
#' @param cached Data frame renvoyé par [get_from_cache()] (colonnes
#'   `from_cache`, `origin`, `source`, `name`, `yaml`).
#' @param lang Chaîne. `"fr"` ou `"en"`.
#' @param savegraph_dir Dossier des graphes enregistrés par
#'   `ofce::save_graph()`, relatif à `_{lang}/`.
#' @return Invisiblement, le nombre de vignettes reportées.
#' @keywords internal
sync_back_thumbnail <- function(
    cached, lang,
    savegraph_dir = getOption("ofce.savegraph.dir", "_sav_graph")) {
  to_sync <- dplyr::filter(cached, !from_cache)

  n <- purrr::pmap_int(to_sync, \(origin, source, name, yaml, ...) {
    image <- yaml[["image"]]
    if (is.null(image)) return(0L)
    generated <- fs::path_join(c(origin, image))
    label <- thumbnail_label(name, lang, savegraph_dir, image)
    if (is.null(label) || !fs::file_exists(generated)) return(0L)

    target <- fs::path_join(c(source, image))
    if (fs::file_exists(target) && !thumbnail_generated(image))
      return(0L)

    fs::file_copy(generated, target, overwrite = TRUE)
    cli::cli_alert_success(
      "{name} ({lang}) : image créée à partir du #{label} du document")
    1L
  })

  if (sum(n) == 0L)
    cli::cli_alert_info("Vignettes ({lang}) : aucune image créée.")
  invisible(sum(n))
}

# Images régénérées à chaque exécution du post
thumbnail_generated <- function(image) {
  file <- fs::path_file(image)
  stringr::str_starts(file, "thumbnail") ||
    stringr::str_detect(file, "^fig-[^.]+\\.png$")
}

# Label du chunk du graphe utilisé pour la vignette : celui demandé par
# `image: fig-{label}` s'il a été enregistré, sinon le premier (ordre
# d'exécution), NULL si aucun. Les fichiers suivent la convention de
# ofce::save_object() : `{lang}-{annee}/{post}-index-{label}.ggplot`.
thumbnail_label <- function(name, lang, savegraph_dir = "_sav_graph",
                            image = NULL) {
  prefix <- fs::path_join(c(
    stringr::str_c("_", lang), savegraph_dir,
    stringr::str_c(lang, "-", name, "-index-"))) |>
    as.character()
  dir <- fs::path_dir(prefix)
  if (!fs::dir_exists(dir)) return(NULL)
  files <- fs::dir_ls(dir, glob = "*.ggplot") |>
    purrr::keep(~ stringr::str_starts(.x, stringr::fixed(prefix)))
  if (length(files) == 0L) return(NULL)
  labels <- files |>
    fs::path_ext_remove() |>
    stringr::str_remove(stringr::fixed(prefix))
  if (!is.null(image) && thumbnail_generated(image)) {
    wanted <- tolower(fs::path_ext_remove(fs::path_file(image)))
    if (wanted %in% labels) return(wanted)
  }
  first <- files[order(fs::file_info(files)$modification_time)][[1]]
  first |>
    fs::path_ext_remove() |>
    stringr::str_remove(stringr::fixed(prefix))
}
