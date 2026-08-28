#' Met à jour la navbar du `_quarto.yml` depuis la source centralisée
#'
#' Lit la définition unique de la navbar (`inst/share/navbar.yml` du package)
#' et remplace les clés `left`, `right` et `tools` de la section
#' `website.navbar` du `_quarto.yml` du site. Les autres clés navbar propres
#' au site (`title`, `logo`, `background`, ...) sont préservées : seuls les
#' menus sont centralisés.
#'
#' Supprime également la clé `website.title` si elle est encore présente :
#' `setup_wp()`, `setup_prev()` et `setup_site()` ne l'écrivent plus (le
#' titre affiché à côté du logo reste porté par la navbar centralisée, pas
#' par un titre calculé par site) ; cet appel nettoie les dépôts initialisés
#' avant ce changement.
#'
#' Les fichiers de profils (`_quarto-fr.yml`, `_quarto-en.yml`, ...) ne sont
#' pas modifiés : s'ils redéfinissent une clé navbar (ex. le sélecteur de
#' langue FR/EN du blog dans `right`), c'est une surcharge locale volontaire
#' qui prime au render. Un message signale les profils concernés.
#'
#' La navbar doit être réécrite dans chaque site à chaque évolution de
#' `navbar.yml` : exécuter `update_navbar()` à la racine du site, relire le
#' diff, committer.
#'
#' @section Édition du YAML :
#' La mise à jour patche uniquement les clés `website.navbar.left`,
#' `.tools`, `.logo`, `.logo-href` et `.logo-alt` dans le texte du fichier :
#' commentaires, indentation et mise en page du reste du `_quarto.yml` sont
#' préservés.
#'
#' @param root Chemin vers la racine du dépôt du site. Défaut `"."`.
#'
#' @returns Invisible `NULL`. Appelée pour ses effets de bord.
#' @seealso [site_version_up()], [setup_site()]
#' @export
update_navbar <- function(root = ".") {
  root <- root |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  yml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(yml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")

  navbar_path <- system.file("share", "navbar.yml", package = "ofceweb")
  if (!nzchar(navbar_path))
    cli::cli_abort(
      "{.file share/navbar.yml} introuvable dans le package {.pkg ofceweb}.")

  navbar <- yaml::read_yaml(navbar_path)
  yml    <- yaml::read_yaml(yml_path)

  if (is.null(yml$website))
    cli::cli_abort(
      "Pas de section {.code website} dans le {.file _quarto.yml}.")

  count_items <- function(section) {
    if (is.null(section)) 0L else length(section)
  }

  old_navbar <- yml$website$navbar
  navbar_keys <- c("left", "tools", "logo", "logo-href", "logo-alt")
  had_title <- !is.null(yml$website$title)

  lines <- readLines(yml_path, warn = FALSE)
  if (had_title) {
    lines <- yaml_patch_delete(lines, "website.title")
  }
  for (key in navbar_keys) {
    lines <- yaml_patch_block(lines, paste0("website.navbar.", key), navbar[[key]])
  }
  writeLines(lines, yml_path)

  cli::cli_alert_success("Navbar mise à jour dans {.file {yml_path}}.")
  if (had_title) {
    cli::cli_alert_info(
      "Clé {.code website.title} supprimée (plus écrite par setup_wp() / \\
       setup_prev() / setup_site()).")
  }
  changed_keys <- Filter(
    function(key) !identical(count_items(old_navbar[[key]]), count_items(navbar[[key]])),
    navbar_keys
  )
  if (length(changed_keys) > 0L) {
    detail <- vapply(
      changed_keys,
      function(key) sprintf(
        "%s (%d \u2192 %d)", key, count_items(old_navbar[[key]]), count_items(navbar[[key]])
      ),
      character(1L)
    )
    cli::cli_alert_info("Contenu modifi\u00e9 : {paste(detail, collapse = ', ')}.")
  }

  profile_paths <- fs::dir_ls(root, regexp = "/_quarto-[^/]+[.]yml$")
  for (profile_path in profile_paths) {
    profile_yml <- yaml::read_yaml(profile_path)
    profile_keys <- names(profile_yml$website$navbar)
    if (length(profile_keys) > 0) {
      cli::cli_alert_info(
        "Le profil {.file {fs::path_file(profile_path)}} surcharge \\
         {.code navbar.{profile_keys}} — non modifié (surcharge locale).")
    }
  }

  invisible(NULL)
}
