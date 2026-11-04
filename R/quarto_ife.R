#' Installe ou met à jour l'extension Quarto quarto-ife
#'
#' L'extension `quarto-ife` (format `ife-html`, type de projet
#' `ife-website`) vit dans le dépôt public `ofceweb/quarto-ife`. Une version
#' publiée y est une étiquette `vX.Y.Z`. `update_quarto_ife()` installe dans
#' `_extensions/ife/` la plus haute de ces versions, avec
#' `quarto add ofceweb/quarto-ife@vX.Y.Z`, si elle n'y est pas déjà.
#'
#' Un dépôt de site l'appelle en `pre-render` de son `_quarto.yml`, et suit
#' ainsi la dernière version à chaque rendu :
#'
#' ```yaml
#' project:
#'   pre-render: Rscript -e "ofceweb::update_quarto_ife()"
#' ```
#'
#' Un dépôt de document (WP, PB, prévision) garde la version installée à sa
#' création : [setup_wp()], [setup_pb()] et [setup_prev()] l'appellent avec
#' `only_if_absent = TRUE`. Un appel sans argument le fait passer à la
#' dernière version.
#'
#' La fonction ne lève jamais d'erreur. Si la liste des versions est
#' inaccessible (réseau, `git` absent) ou si l'installation échoue, elle
#' affiche un avertissement et garde la version en place, de sorte qu'un
#' rendu aboutit sans GitHub.
#'
#' @param path Racine du projet Quarto. Défaut `"."`.
#' @param only_if_absent Si `TRUE`, n'installe l'extension que si elle est
#'   absente, sans chercher de version plus récente. Défaut `FALSE`.
#' @param quiet Si `TRUE`, n'affiche que les avertissements. Défaut `FALSE`.
#' @returns Invisible, la version installée après l'appel (`"0.2.0"`), ou
#'   `NULL` si l'extension est absente.
#' @export
update_quarto_ife <- function(path = ".", only_if_absent = FALSE, quiet = FALSE) {
  installed <- quarto_ife_installed_version(path)
  kept <- installed %||% "aucune"

  if (only_if_absent && !is.null(installed)) {
    if (!quiet) cli::cli_alert_info("quarto-ife {installed} déjà installée.")
    return(invisible(installed))
  }

  latest <- tryCatch(
    quarto_ife_latest_tag(quarto_ife_remote_tags()),
    error = function(e) {
      cli::cli_alert_warning(
        "Dernière version de quarto-ife introuvable ({conditionMessage(e)}) : \\
         version gardée {.val {kept}}."
      )
      NULL
    }
  )
  if (is.null(latest)) return(invisible(installed))

  if (identical(installed, latest)) {
    if (!quiet) cli::cli_alert_success("quarto-ife {installed} à jour.")
    return(invisible(installed))
  }

  ok <- tryCatch({
    quarto_ife_install(path, latest)
    TRUE
  }, error = function(e) {
    cli::cli_alert_warning(
      "Installation de quarto-ife {latest} échouée ({conditionMessage(e)}) : \\
       version gardée {.val {kept}}."
    )
    FALSE
  })

  now <- quarto_ife_installed_version(path)
  if (ok && !identical(now, latest)) {
    cli::cli_alert_warning(
      "Installation de quarto-ife {latest} incomplète : version en place \\
       {.val {now %||% 'aucune'}}."
    )
  } else if (ok && !quiet) {
    cli::cli_alert_success("quarto-ife {latest} installée (précédente : {kept}).")
  }
  invisible(now)
}

quarto_ife_repo <- "ofceweb/quarto-ife"

#' Version de quarto-ife installée dans un projet
#'
#' @param path Racine du projet Quarto.
#' @returns La version lue dans `_extensions/ife/ife/_extension.yml`, ou
#'   `NULL` si le fichier est absent ou illisible.
#' @keywords internal
quarto_ife_installed_version <- function(path = ".") {
  f <- fs::path(path, "_extensions", "ife", "ife", "_extension.yml")
  if (!fs::file_exists(f)) return(NULL)
  v <- tryCatch(yaml::read_yaml(f)[["version"]], error = function(e) NULL)
  if (is.null(v)) NULL else as.character(v)
}

#' Étiquettes du dépôt quarto-ife
#'
#' Lit les étiquettes par `git ls-remote`, sans jeton ni quota d'API GitHub.
#'
#' @returns Le vecteur des noms d'étiquettes (`"v0.1.0"`). Erreur si `git`
#'   échoue.
#' @keywords internal
quarto_ife_remote_tags <- function() {
  url <- paste0("https://github.com/", quarto_ife_repo, ".git")
  out <- suppressWarnings(system2(
    "git", c("ls-remote", "--tags", "--refs", url),
    stdout = TRUE, stderr = TRUE,
    env = "GIT_TERMINAL_PROMPT=0", timeout = 30
  ))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    cli::cli_abort("git ls-remote : {paste(out, collapse = ' ')}")
  }
  sub("^.*refs/tags/", "", out)
}

#' Plus haute version publiée parmi des étiquettes
#'
#' @param tags Noms d'étiquettes. Seules celles de forme `vX.Y.Z` comptent.
#' @returns La plus haute version, sans le `v` (`"0.10.0"`). Erreur si
#'   aucune étiquette n'a cette forme.
#' @keywords internal
quarto_ife_latest_tag <- function(tags) {
  tags <- grep("^v[0-9]+\\.[0-9]+\\.[0-9]+$", tags, value = TRUE)
  if (length(tags) == 0) cli::cli_abort("aucune version publiée")
  as.character(max(numeric_version(sub("^v", "", tags))))
}

#' Installe une version de quarto-ife
#'
#' @param path Racine du projet Quarto.
#' @param version Version à installer, sans le `v`.
#' @keywords internal
quarto_ife_install <- function(path, version) {
  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(path)
  quarto::quarto_add_extension(
    paste0(quarto_ife_repo, "@v", version),
    no_prompt = TRUE, quiet = TRUE
  )
}
