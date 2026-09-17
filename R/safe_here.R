#' Résout un chemin ancré à la racine du projet, robuste aux copies temporaires de `render_folder()`
#'
#' Remplacement direct de [here::here()] : même signature, même résultat dans
#' tous les cas... sauf un. [render_folder()] rend le dossier ciblé depuis une
#' copie temporaire isolée (voir sa section *Self-contained folders*), copie
#' qui ne contient aucun marqueur de racine (`.Rproj`, `.git`, `.here`) et qui
#' n'inclut pas les fichiers situés hors du dossier copié. Dans ce contexte,
#' [here::here()] ne peut ni retrouver la vraie racine du projet, ni (même
#' s'il le pouvait) atteindre des fichiers jamais copiés.
#'
#' `safe_here()` contourne les deux problèmes : si un marqueur laissé par
#' [render_folder()] (`.safe_here-root`, écrit par `render_folder_worker()`
#' avant la copie) est trouvé en remontant l'arborescence depuis le
#' répertoire de travail courant, le chemin est résolu par rapport à la
#' racine *réelle* du projet — sur le disque, hors de la copie temporaire —
#' exactement comme si le rendu avait eu lieu directement dans le projet
#' (y compris pour des fichiers situés hors du dossier copié). Sinon (cas
#' normal, hors `render_folder()`), l'appel est simplement transmis à
#' [here::here()].
#'
#' ## Limites
#'
#' `safe_here()` corrige la résolution de chemin côté R (`source()`,
#' `read.csv()`, etc.) : ces fichiers sont alors lus directement dans
#' l'arborescence réelle, jamais copiée. Cela ne rend pas pour autant les
#' fichiers hors dossier accessibles à Quarto lui-même — un chemin relatif
#' brut dans le Markdown, ou `{{< include ../ailleurs.qmd >}}`, ne passe pas
#' par `safe_here()`/[here::here()] et nécessite toujours que le fichier
#' soit physiquement présent dans la copie.
#'
#' @param ... Transmis à [here::here()] (segments de chemin relatifs à la
#'   racine).
#'
#' @returns `[character(1)]` Un chemin, comme [here::here()].
#' @seealso [render_folder()]
#' @importFrom fs path path_abs path_dir file_exists
#' @export
safe_here <- function(...) {
  marker <- find_safe_here_marker(getwd())
  if (is.null(marker)) return(here::here(...))

  root <- readLines(marker, n = 1, warn = FALSE)
  fs::path(root, ...)
}

#' Recherche le marqueur `.safe_here-root` en remontant l'arborescence
#'
#' Utilisée par [safe_here()]. La recherche part de `start` et remonte
#' répertoire par répertoire (comme le ferait `rprojroot`/`here` pour leurs
#' propres marqueurs), car Quarto/knitr exécutent chaque chunk avec le
#' répertoire de travail réglé sur celui du document — potentiellement
#' plusieurs niveaux sous la racine de la copie temporaire, notamment pour
#' les chunks de fichiers inclus via `{{< include sous-dossier/x.qmd >}}`.
#'
#' @param start `[character(1)]`\cr Répertoire de départ (typiquement
#'   `getwd()`).
#'
#' @returns `[character(1)]` Chemin vers le marqueur trouvé, ou `NULL` si
#'   aucun marqueur n'existe jusqu'à la racine du système de fichiers.
#' @keywords internal
find_safe_here_marker <- function(start) {
  dir <- fs::path_abs(start)
  repeat {
    candidate <- fs::path(dir, ".safe_here-root")
    if (fs::file_exists(candidate)) return(as.character(candidate))
    parent <- fs::path_dir(dir)
    if (as.character(parent) == as.character(dir)) return(NULL)
    dir <- parent
  }
}

#' Détermine la racine « réelle » du projet pour un futur marqueur `safe_here()`
#'
#' Appelée par `render_folder_worker()`, avant toute copie, pour déterminer la
#' racine que [safe_here()] devra utiliser une fois le rendu effectué depuis
#' la copie temporaire. Utilise directement [rprojroot::find_root()] avec un
#' critère équivalent à celui de [here::here()] (fichier `.here`, `*.Rproj`,
#' `_quarto.yml`, paquet R, dépôt Git/SVN, `remake.yml`, `.projectile`),
#' plutôt que d'appeler [here::here()] lui-même.
#'
#' C'est un choix délibéré, pas une simplification anodine : [here::here()]
#' mémorise sa racine pour toute la durée de la session R dès son premier
#' appel et ne la recalcule jamais ensuite, quel que soit le répertoire de
#' travail courant au moment d'un appel ultérieur. Si `render_folder()` a
#' déjà rendu un dossier plus tôt dans la même session, le `_quarto.yml`
#' minimal qu'il écrit dans sa copie temporaire (reconnu comme racine par ce
#' même critère) aurait alors pu être mis en cache comme racine -- et y
#' resterait pour le reste de la session, contaminant silencieusement tout
#' appel ultérieur à [here::here()], y compris ici. Reproduit et vérifié
#' empiriquement : appeler [here::here()] après un premier `render_folder()`
#' dans une session RStudio renvoie la racine (fausse) du rendu précédent,
#' quel que soit le dossier réellement ciblé ensuite. [rprojroot::find_root()]
#' recalcule toujours à neuf à partir de `target`, sans effet de bord sur
#' l'état de la session ni sur celui du paquet `here`.
#'
#' @param target `[character(1)]`\cr Chemin absolu du dossier source.
#'
#' @returns `[character(1)]` La racine trouvée, ou `NA_character_` si aucun
#'   marqueur de racine n'est trouvé jusqu'à la racine du système de fichiers.
#' @keywords internal
resolve_origin_root <- function(target) {
  criterion <-
    rprojroot::has_file(".here") |
    rprojroot::is_rstudio_project |
    rprojroot::is_r_package |
    rprojroot::is_remake_project |
    rprojroot::is_projectile_project |
    rprojroot::is_vcs_root |
    rprojroot::has_file("_quarto.yml")

  tryCatch(
    as.character(rprojroot::find_root(criterion, path = target)),
    error = function(e) NA_character_
  )
}

#' Écrit le marqueur `.safe_here-root` dans une copie temporaire
#'
#' Appelée par `render_folder_worker()` juste après avoir copié le dossier
#' ciblé dans son répertoire temporaire de rendu. N'écrit rien si
#' `origin_root` est `NA` (racine introuvable même dans l'arborescence
#' réelle) : [safe_here()] se comportera alors, dans la copie, exactement
#' comme [here::here()] — même échec, pas de régression.
#'
#' @param temp_dir `[character(1)]`\cr Racine de la copie temporaire.
#' @param origin_root `[character(1)]`\cr Racine réelle du projet (résultat
#'   de [here::here()] appelé depuis le dossier source, avant copie), ou
#'   `NA_character_`.
#'
#' @returns Invisiblement `NULL`.
#' @keywords internal
write_safe_here_marker <- function(temp_dir, origin_root) {
  if (is.na(origin_root)) return(invisible(NULL))
  writeLines(origin_root, fs::path(temp_dir, ".safe_here-root"))
  invisible(NULL)
}
