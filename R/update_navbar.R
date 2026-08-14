#' Met à jour la navbar du `_quarto.yml` depuis la source centralisée
#'
#' Lit la définition unique de la navbar (`inst/share/navbar.yml` du package)
#' et remplace les clés `left`, `right` et `tools` de la section
#' `website.navbar` du `_quarto.yml` du site. Les autres clés navbar propres
#' au site (`title`, `logo`, `background`, ...) sont préservées : seuls les
#' menus sont centralisés.
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
#' @section Reformatage YAML :
#' La réécriture via [yaml::write_yaml()] normalise l'ensemble du fichier :
#' les commentaires sont supprimés et l'indentation peut changer. C'est un
#' comportement normal — relire le diff avant de committer.
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
  yml <- yaml::read_yaml(yml_path)

  if (is.null(yml$website))
    cli::cli_abort(
      "Pas de section {.code website} dans le {.file _quarto.yml}.")

  count_items <- function(section) {
    if (is.null(section)) 0L else length(section)
  }

  old_navbar <- yml$website$navbar
  for (key in c("left", "tools", "logo", "logo-href", "logo-alt")) {
    yml$website$navbar[[key]] <- navbar[[key]]
  }

  yaml::write_yaml(
    yml,
    yml_path,
    indent.mapping.sequence = TRUE,
    handlers = list(logical = yaml::verbatim_logical)
  )

  cli::cli_alert_success("Navbar mise à jour dans {.file {yml_path}}.")
  cli::cli_alert_warning(
    "Le fichier a été reformaté par {.pkg yaml} : les commentaires sont \\
     supprimés et l'indentation peut avoir changé. Relisez le diff avant \\
     de committer."
  )
  for (key in c("left", "tools", "logo", "logo-href", "logo-alt")) {
    cli::cli_alert_info(
      "{.code {key}} : {count_items(old_navbar[[key]])} -> \\
       {count_items(navbar[[key]])} item{?s}.")
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
