
#' Collecte récursivement les fichiers d'un répertoire GitHub
#'
#' Parcourt l'arborescence d'un répertoire de dépôt GitHub via l'API Contents
#' et renvoie une liste de paires `(url, dest)` pour chaque fichier
#' correspondant au filtre d'extension optionnel. Les répertoires sont
#' parcourus récursivement jusqu'à `max_depth` niveaux.
#'
#' @param owner Nom de l'utilisateur ou de l'organisation GitHub.
#' @param repo  Nom du dépôt.
#' @param path  Chemin de départ dans le dépôt (ex. `"posts"`).
#' @param destdir Répertoire local de destination. Défaut `path`.
#' @param ref   Référence Git (branche, tag ou SHA) à lire. Défaut `"HEAD"`.
#' @param ext   Si non `NULL`, seuls les fichiers dont le nom se termine par
#'   cette chaîne sont collectés (ex. `".qmd"`).
#' @param max_depth Profondeur maximale de récursion. `Inf` signifie illimité.
#' @param .depth Compteur interne de récursion — ne pas définir manuellement.
#'
#' @return Une liste de listes nommées, chacune avec les éléments `url` (l'URL
#'   de téléchargement brute) et `dest` (le chemin local du fichier).
#'
#' @keywords internal
#' @noRd
collect_gh_files <- function(owner, repo, path, destdir=path, ref = "HEAD", ext = NULL, max_depth = Inf, .depth = 0) {
  contents <- gh::gh(
    "GET /repos/{owner}/{repo}/contents/{path}",
    owner = owner, repo = repo, path = path, ref = ref
  )

  files <- list()
  for (item in contents) {
    dest <- file.path(destdir, item$name)
    if (item$type == "file") {
      if (is.null(ext) || endsWith(item$name, ext)) {
        files <- c(files, list(list(url = item$download_url, dest = dest)))
      }
    } else if (item$type == "dir" && .depth < max_depth) {
      dir.create(dest, recursive = TRUE, showWarnings = FALSE)
      files <- c(files, collect_gh_files(owner, repo, item$path, dest, ref, ext, max_depth, .depth + 1))
    }
  }
  files
}

#' Variante parallèle de \code{collect_gh_files}
#'
#' Liste les sous-répertoires de premier niveau de `path` et délègue chaque
#' sous-arbre à [collect_gh_files()] en parallèle via `futurize::futurize()`,
#' ce qui réduit le temps d'exécution pour les dépôts avec de nombreux
#' répertoires de premier niveau.
#'
#' @inheritParams collect_gh_files
#'
#' @return Même structure que [collect_gh_files()] : une liste plate de
#'   paires `list(url, dest)`.
#'
#' @keywords internal
#' @noRd
fast_collect_gh_files  <-  function(owner, repo, path, destdir=path, ref = "HEAD", ext = NULL, max_depth = Inf, .depth = 0) {
  contents <- gh::gh(
    "GET /repos/{owner}/{repo}/contents/{path}",
    owner = owner, repo = repo, path = path, ref = ref
  )

  contents <- contents |> purrr::keep(~.x$type == "dir")

  purrr::map( contents,
              ~collect_gh_files(owner, repo, .x$path, destdir = .x$path, ref=ref, ext=ext, max_depth = max_depth, .depth=1) ) |>
    futurize::futurize() |>
    purrr::list_c()

}

#' Télécharge un répertoire depuis un dépôt GitHub
#'
#' Parcourt récursivement un répertoire de dépôt GitHub, collecte tous les
#' fichiers correspondants en parallèle avec [fast_collect_gh_files()], puis
#' les télécharge localement via `curl`, en ajoutant un en-tête Bearer token
#' quand un PAT GitHub est disponible (nécessaire pour les dépôts privés).
#'
#' @param owner     Nom de l'utilisateur ou de l'organisation GitHub.
#' @param repo      Nom du dépôt.
#' @param path      Chemin du répertoire à télécharger dans le dépôt (ex.
#'   `"posts"`).
#' @param destdir   Répertoire local où écrire les fichiers. Défaut `path`.
#' @param ref       Référence Git (branche, tag ou SHA). Défaut `"HEAD"`.
#' @param ext       Si non `NULL`, seuls les fichiers se terminant par cette
#'   chaîne sont téléchargés (ex. `".qmd"`).
#' @param max_depth Profondeur maximale de récursion. Défaut `3`.
#'
#' @return `invisible(NULL)`, appelée pour son effet de bord d'écriture des
#'   fichiers dans `destdir`.
#'
#' @examples
#' \dontrun{
#' # Ne télécharger que les fichiers .qmd du répertoire posts/
#' download_gh_dir("OFCE", "Blog_OFCE", "posts", ext = ".qmd", max_depth = 3)
#' }
#'
#' @export
download_gh_dir <- function(owner, repo, path, destdir = path, ref = "HEAD",
                            ext = NULL, max_depth = 3) {
  dir.create(destdir, recursive = TRUE, showWarnings = FALSE)

  message("Collecte de la liste des fichiers...")
  files <- fast_collect_gh_files(owner, repo, path, destdir, ref, ext, max_depth)

  if (length(files) == 0) {
    message("Aucun fichier correspondant trouvé.")
    return(invisible(NULL))
  }

  urls  <- purrr::map_chr(files, "url")
  dests <- purrr::map_chr(files, "dest")

  # Ensure all destination subdirectories exist
  purrr::walk(unique(dirname(dests)), dir.create, recursive = TRUE, showWarnings = FALSE)

  # multi_download doesn't pass auth headers; raw.githubusercontent.com requires
  # a token for private repos, so we use curl_download with a handle per file.
  token <- tryCatch(gh::gh_token(), error = function(e) "")

  message("Téléchargement de ", length(urls), " fichier(s)...")
  purrr::walk2(urls, dests, function(url, dest) {
    h <- curl::new_handle()
    if (nchar(token) > 0) {
      curl::handle_setheaders(h, "Authorization" = paste("token", token))
    }
    curl::curl_download(url, dest, handle = h)
  }) |>
    futurize::futurize()

  message("Terminé : ", length(urls), " fichier(s) téléchargé(s) dans ", destdir)
  invisible(NULL)
}

#' Télécharge un seul fichier depuis un dépôt GitHub
#'
#' Recherche un fichier par son chemin via l'API Contents de GitHub et le
#' télécharge vers une destination locale via `curl`. Un Bearer token est
#' attaché automatiquement quand un PAT GitHub est configuré (nécessaire pour
#' les dépôts privés).
#'
#' @param path  Chemin du fichier dans le dépôt (ex.
#'   `"posts/2024-01-01/index.qmd"`).
#' @param dest  Chemin local où écrire le fichier. Défaut `path`.
#' @param owner Nom de l'utilisateur ou de l'organisation GitHub. Défaut
#'   `"ofceweb"`.
#' @param repo  Nom du dépôt. Défaut `"webblog"`.
#' @param ref   Référence Git (branche, tag ou SHA). Défaut `"site-deploy"`.
#'
#' @return Le chemin local `dest` en cas de succès, ou `NULL` si le fichier
#'   n'a pas été trouvé dans le dépôt.
#'
#' @examples
#' \dontrun{
#' download_gh_file("posts/my-post/index.qmd", dest = "local/index.qmd")
#' }
#'
#' @export
download_gh_file <- function(path, dest = path, owner="ofceweb", repo = "webblog", ref="site-deploy") {

  contents <- tryCatch(
    gh::gh(
      "GET /repos/{owner}/{repo}/contents/{path}",
      owner = owner, repo = repo, path = path, ref = ref
    ),
    error = function(e) NULL
  )

  # A file path returns a single object; a directory path (or a 404 wrapped
  # by tryCatch) would not carry a download_url, and is treated as "not found".
  if(is.null(contents) || is.null(contents[["download_url"]]))
    return(NULL)

  url  <- contents[["download_url"]]

  token <- tryCatch(gh::gh_token(), error = function(e) "")

  h <- curl::new_handle()

  if (nchar(token) > 0) {
    curl::handle_setheaders(h, "Authorization" = paste("token", token))
  }
  curl::curl_download(url, dest, handle = h)
  return(dest)
}

# Example — download only .qmd files
# download_gh_dir("OFCE", "Blog_OFCE", "posts", ext = ".qmd", max_depth = 3)


# Crée ou met à jour une GitHub Actions repository variable (publique).
# Utilise PATCH pour mettre à jour, POST pour créer si 404.
# Avertit sans lever d'erreur en cas d'absence de token ou d'échec API.
set_gh_var <- function(root = ".", name, value) {
  remotes <- tryCatch(gert::git_remote_list(repo = root), error = function(e) NULL)
  if (is.null(remotes) || nrow(remotes) == 0) {
    cli::cli_alert_warning("Pas de remote git — variable GitHub {.val {name}} non définie.")
    return(invisible(NULL))
  }
  origin_url <- remotes$url[remotes$name == "origin"]
  if (length(origin_url) == 0) origin_url <- remotes$url[[1]]

  slug <- origin_url |>
    sub(pattern = "\\.git$",           replacement = "") |>
    sub(pattern = "^git@[^:]+:",       replacement = "") |>
    sub(pattern = "^https://[^/]+/",   replacement = "")
  parts <- strsplit(slug, "/")[[1]]
  owner <- parts[[1]]; repo <- parts[[2]]

  token <- Sys.getenv("DEPLOY_PAT", "")
  if (!nchar(token))
    token <- tryCatch(
      gitcreds::gitcreds_get("https://github.com")$password,
      error = function(e) ""
    )
  if (!nchar(token)) {
    cli::cli_alert_warning(c(
      "Pas de token GitHub — variable {.val {name}} non définie sur GitHub.",
      "i" = "Définissez {.envvar DEPLOY_PAT} ou connectez-vous avec {.run usethis::create_github_token()}."
    ))
    return(invisible(NULL))
  }

  value <- as.character(value)

  gh_req <- function(method, endpoint, body) {
    httr2::request(sprintf("https://api.github.com%s", endpoint)) |>
      httr2::req_method(method) |>
      httr2::req_auth_bearer_token(token) |>
      httr2::req_headers(
        Accept                 = "application/vnd.github+json",
        `X-GitHub-Api-Version` = "2022-11-28"
      ) |>
      httr2::req_body_json(body) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()
  }

  # PATCH pour mise à jour ; POST pour création si 404
  patch_resp <- gh_req(
    "PATCH",
    sprintf("/repos/%s/%s/actions/variables/%s", owner, repo, name),
    list(name = name, value = value)
  )

  if (httr2::resp_status(patch_resp) == 204L) {
    cli::cli_alert_success("Variable GitHub {.val {name}} mise à jour : {.val {value}}")
    return(invisible(NULL))
  }

  if (httr2::resp_status(patch_resp) == 404L) {
    post_resp <- gh_req(
      "POST",
      sprintf("/repos/%s/%s/actions/variables", owner, repo),
      list(name = name, value = value)
    )
    if (httr2::resp_status(post_resp) == 201L) {
      cli::cli_alert_success("Variable GitHub {.val {name}} créée : {.val {value}}")
      return(invisible(NULL))
    }
    body_msg <- tryCatch(httr2::resp_body_json(post_resp)$message, error = \(e) "?")
    cli::cli_alert_warning(
      "Impossible de créer la variable GitHub {.val {name}} \\
       (HTTP {httr2::resp_status(post_resp)}) : {body_msg}"
    )
    return(invisible(NULL))
  }

  body_msg <- tryCatch(httr2::resp_body_json(patch_resp)$message, error = \(e) "?")
  cli::cli_alert_warning(
    "Impossible de mettre à jour la variable GitHub {.val {name}} \\
     (HTTP {httr2::resp_status(patch_resp)}) : {body_msg}"
  )
  invisible(NULL)
}

check_repo_status <- function(repo = ".", prompt = TRUE) {
  # Fetch latest refs from remote (no merge)
  fetch <- tryCatch(
    gert::git_fetch(repo = repo, verbose = FALSE),
    error = function(e) { warning(sprintf("Échec du fetch : %s", e$message)); NULL }
  )
  if (is.null(fetch)) return(NULL)

  # Get current local branch
  branch <- gert::git_branch(repo = repo)

  # Get upstream tracking branch (e.g. "origin/main")
  branches  <- gert::git_branch_list(repo = repo)
  upstream  <- branches$upstream[branches$name == branch]

  if (is.na(upstream) || length(upstream) == 0) {
    cli::cli_alert_danger("La branche '{branch}' n'a pas d'upstream configuré.")
    return(invisible(NULL))
  }

  # Compare local vs remote
  ab <- gert::git_ahead_behind(upstream = upstream, repo = repo)

  cli::cli_text(
    "Branche         : {branch}")
  cli::cli_text(
    "Upstream        : {upstream}")
  cli::cli_text(
    "Commits en avance : {ab$ahead} (commits locaux non poussés)")
  cli::cli_text(
    "Commits en retard : {ab$behind} (commits distants non récupérés)")

  if (ab$ahead == 0 && ab$behind == 0) {
    cli::cli_alert_info(
      "Statut          : à jour")
  }
  if (ab$ahead > 0) {
    cli::cli_alert_info(
      "Statut          : en avance sur le remote — commits locaux non poussés\n")
  }

  if (ab$behind > 0) {
    cli::cli_alert_danger(
      "Statut          : EN RETARD sur le remote — lancer git_branch_fast_forward() ou git pull")
    if(prompt) {
      answer <- readline("Êtes-vous sûr·e de vouloir continuer ? [o/N] ")
      if (!tolower(answer) %in% c("o", "oui")) {
        message("Abandonné.")
        stop("Le dépôt local est en retard par rapport à origin")
      }
    }
  }
  invisible(ab)
}

#' Résout le slug GitHub `"owner/repo"` depuis le remote `origin`
#'
#' Utilisé pour tagger les artefacts déployés (ex. `manifest.json`) avec leur
#' dépôt d'origine, au même format que le contexte `github.repository` des
#' workflows GitHub Actions — ce qui permet de comparer directement les deux
#' valeurs sans reformatage.
#'
#' @param root Chemin vers la racine du dépôt Git local. Défaut `"."`.
#' @return Chaîne `"owner/repo"`, ou `NA_character_` si le remote `origin`
#'   est absent ou non reconnu.
#' @keywords internal
#' @noRd
gh_slug_from_remote <- function(root = ".") {
  remotes <- tryCatch(gert::git_remote_list(repo = root), error = function(e) NULL)
  if (is.null(remotes) || nrow(remotes) == 0) return(NA_character_)
  o   <- remotes[remotes$name == "origin", , drop = FALSE]
  url <- if (nrow(o) > 0) o$url[[1]] else remotes$url[[1]]
  url2 <- sub("\\.git$", "", url)
  if (grepl("^git@", url2)) {
    m <- regmatches(url2, regexec("git@[^:]+:([^/]+)/(.+)$", url2))[[1]]
  } else {
    m <- regmatches(url2, regexec("https?://[^/]+/([^/]+)/(.+)$", url2))[[1]]
  }
  if (length(m) < 3) return(NA_character_)
  paste0(m[[2]], "/", m[[3]])
}
