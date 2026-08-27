
#' Recursively collect files from a GitHub directory
#'
#' Traverses a GitHub repository directory tree via the Contents API and
#' returns a list of `(url, dest)` pairs for every file that matches the
#' optional extension filter.  Directories are recursed up to `max_depth`
#' levels deep.
#'
#' @param owner GitHub user or organisation name.
#' @param repo  Repository name.
#' @param path  Path inside the repository to start from (e.g. `"posts"`).
#' @param destdir Local destination directory.  Defaults to `path`.
#' @param ref   Git ref (branch, tag, or SHA) to read from.  Defaults to
#'   `"HEAD"`.
#' @param ext   If non-`NULL`, only files whose names end with this string are
#'   collected (e.g. `".qmd"`).
#' @param max_depth Maximum recursion depth.  `Inf` means unlimited.
#' @param .depth Internal recursion counter — do not set manually.
#'
#' @return A list of named lists, each with elements `url` (the raw download
#'   URL) and `dest` (the local file path).
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

#' Parallel variant of \code{collect_gh_files}
#'
#' Lists the top-level subdirectories of `path` and delegates each subtree to
#' [collect_gh_files()] concurrently via `futurize::futurize()`, reducing
#' wall-clock time for repositories with many first-level directories.
#'
#' @inheritParams collect_gh_files
#'
#' @return Same structure as [collect_gh_files()]: a flat list of
#'   `list(url, dest)` pairs.
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

#' Download a directory from a GitHub repository
#'
#' Recursively walks a GitHub repository directory, collects all matching
#' files in parallel with [fast_collect_gh_files()], then downloads them
#' locally using `curl`, adding a Bearer token header when a GitHub PAT is
#' available (required for private repositories).
#'
#' @param owner     GitHub user or organisation name.
#' @param repo      Repository name.
#' @param path      Path inside the repository to download (e.g. `"posts"`).
#' @param destdir   Local directory to write files into.  Defaults to `path`.
#' @param ref       Git ref (branch, tag, or SHA).  Defaults to `"HEAD"`.
#' @param ext       If non-`NULL`, only files ending with this string are
#'   downloaded (e.g. `".qmd"`).
#' @param max_depth Maximum directory recursion depth.  Defaults to `3`.
#'
#' @return `invisible(NULL)`, called for its side-effect of writing files to
#'   `destdir`.
#'
#' @examples
#' \dontrun{
#' # Download only .qmd files from the posts/ directory
#' download_gh_dir("OFCE", "Blog_OFCE", "posts", ext = ".qmd", max_depth = 3)
#' }
#'
#' @section Other:
#'
#' @export
download_gh_dir <- function(owner, repo, path, destdir = path, ref = "HEAD",
                            ext = NULL, max_depth = 3) {
  dir.create(destdir, recursive = TRUE, showWarnings = FALSE)

  message("Collecting file list...")
  files <- fast_collect_gh_files(owner, repo, path, destdir, ref, ext, max_depth)

  if (length(files) == 0) {
    message("No matching files found.")
    return(invisible(NULL))
  }

  urls  <- purrr::map_chr(files, "url")
  dests <- purrr::map_chr(files, "dest")

  # Ensure all destination subdirectories exist
  purrr::walk(unique(dirname(dests)), dir.create, recursive = TRUE, showWarnings = FALSE)

  # multi_download doesn't pass auth headers; raw.githubusercontent.com requires
  # a token for private repos, so we use curl_download with a handle per file.
  token <- tryCatch(gh::gh_token(), error = function(e) "")

  message("Downloading ", length(urls), " file(s)...")
  purrr::walk2(urls, dests, function(url, dest) {
    h <- curl::new_handle()
    if (nchar(token) > 0) {
      curl::handle_setheaders(h, "Authorization" = paste("token", token))
    }
    curl::curl_download(url, dest, handle = h)
  }) |>
    futurize::futurize()

  message("Done: ", length(urls), " file(s) downloaded to ", destdir)
  invisible(NULL)
}

#' Download a single file from a GitHub repository
#'
#' Looks up a file by path in the GitHub Contents API and downloads it to a
#' local destination using `curl`.  A Bearer token is attached automatically
#' when a GitHub PAT is configured (needed for private repositories).
#'
#' @param path  Path to the file inside the repository (e.g.
#'   `"posts/2024-01-01/index.qmd"`).
#' @param dest  Local path to write the file to.  Defaults to `path`.
#' @param owner GitHub user or organisation name.  Defaults to `"ofceweb"`.
#' @param repo  Repository name.  Defaults to `"webblog"`.
#' @param ref   Git ref (branch, tag, or SHA).  Defaults to `"site-deploy"`.
#'
#' @return The local path `dest` on success, or `NULL` if the file was not
#'   found in the repository.
#'
#' @examples
#' \dontrun{
#' download_gh_file("posts/my-post/index.qmd", dest = "local/index.qmd")
#' }
#'
#' @section Other:
#'
#' @export
download_gh_file <- function(path, dest = path, owner="ofceweb", repo = "webblog", ref="site-deploy") {

  contents <- gh::gh(
    "GET /repos/{owner}/{repo}/contents/.",
    owner = owner, repo = repo, path = fs::path_dir(path), ref = ref
  ) |>
    purrr::keep(~.x[["name"]] == fs::path_file(path))

  if(length(contents)!=1)
    return(NULL)

  url  <- contents[[1]] [["download_url"]]

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

#' Vérifie la connexion GitHub (`gh::gh("GET /user")`)
#'
#' Diagnostic partagé par [check_wp()], [setup_prev()], [stage_prev()] et
#' [publish_prev()] : appelle `gh::gh("GET /user")` et affiche le login
#' GitHub de l'utilisateur (succès) ou un avertissement non bloquant si
#' aucune authentification n'est détectée.
#'
#' @param verbose Logique. Si `TRUE` (défaut), affiche le résultat via
#'   [cli::cli_alert_success()] / [cli::cli_alert_warning()].
#' @return Chaîne (login GitHub) ou `NA_character_` si non connecté —
#'   invisible.
#' @keywords internal
#' @noRd
check_gh_login <- function(verbose = TRUE) {
  gh_user <- tryCatch(gh::gh("GET /user"), error = function(e) NULL)
  if (!is.null(gh_user) && !is.null(gh_user$login)) {
    if (verbose)
      cli::cli_alert_success(
        "Connect\u00e9 \u00e0 GitHub en tant que @{gh_user$login}.")
    return(invisible(gh_user$login))
  }
  if (verbose)
    cli::cli_alert_warning(
      "Non connect\u00e9 \u00e0 GitHub (gh::gh('GET /user') a \u00e9chou\u00e9). \\
       Les op\u00e9rations staging et registry seront indisponibles.")
  invisible(NA_character_)
}

check_repo_status <- function(repo = ".", prompt = TRUE, timeout = 10) {
  # Fetch latest refs from remote (no merge).
  # Runs in a callr subprocess so the timeout is enforced cross-platform.
  fetch <- tryCatch(
    callr::r(
      function(repo) gert::git_fetch(repo = repo, verbose = FALSE),
      args    = list(repo = repo),
      timeout = timeout
    ),
    error = function(e) {
      if (inherits(e, "callr_timeout_error")) {
        cli::cli_alert_warning(
          "V\u00e9rification du d\u00e9p\u00f4t ignor\u00e9e \u2014 GitHub n'a pas r\u00e9pondu en {timeout}\u00a0s.")
      } else {
        cli::cli_alert_warning("Fetch \u00e9chou\u00e9 : {conditionMessage(e)}")
      }
      NULL
    }
  )
  if (is.null(fetch)) return(invisible(NULL))

  # Get current local branch
  branch <- gert::git_branch(repo = repo)

  # Get upstream tracking branch (e.g. "origin/main")
  branches  <- gert::git_branch_list(repo = repo)
  upstream  <- branches$upstream[branches$name == branch]

  if (is.na(upstream) || length(upstream) == 0) {
    cli::cli_alert_danger("Branch '", branch, "' has no upstream configured.")
    return(invisible(NULL))
  }

  # Compare local vs remote
  ab <- gert::git_ahead_behind(upstream = upstream, repo = repo)

  cli::cli_text(
    "Branch        : {branch}")
  cli::cli_text(
    "Upstream      : {upstream}")
  cli::cli_text(
    "Commits ahead : {ab$ahead} (local commits not pushed)")
  cli::cli_text(
    "Commits behind: {ab$behind} (remote commits not pulled)")

  if (ab$ahead == 0 && ab$behind == 0) {
    cli::cli_alert_info(
      "Status        : up to date")
  }
  if (ab$ahead > 0) {
    cli::cli_alert_info(
      "Status        : ahead of remote — unpushed local commits\n")
  }

  if (ab$behind > 0) {
    cli::cli_alert_danger(
      "Status        : BEHIND remote — run git_branch_fast_forward() or git pull")
    if(prompt) {
      answer <- readline("Are you sure you want to proceed? [y/N] ")
      if (!tolower(answer) %in% c("y", "yes")) {
        message("Aborted.")
        stop("Your blog repo is behind origin")
      }
    }
  }
  invisible(ab)
}

#' Liste des années disponibles dans `wp-registry` (`wp/index.json`)
#'
#' Télécharge `wp/index.json` (lecture publique, non authentifiée) du dépôt
#' registre. Utilisé pour savoir quels fichiers `wp/{année}.json` interroger.
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Vecteur entier des années, ou `NULL` si `wp/index.json` est
#'   inaccessible (registre indisponible ou pas encore migré vers la
#'   disposition `wp/`).
#' @keywords internal
#' @noRd
fetch_wp_index <- function(registry_repo = "ofceweb/wp-registry") {
  index_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/wp/index.json", registry_repo)
  tryCatch({
    years <- jsonlite::fromJSON(index_url, simplifyVector = TRUE)$years
    as.integer(years)
  }, error = function(e) NULL)
}

#' Lit les entrées d'une année du registre (`wp/{année}.json`)
#'
#' @param annee Entier. Année à lire.
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Liste d'entrées (`registry$wp`), ou `NULL` si le fichier est
#'   introuvable ou illisible (année pas encore créée, ou erreur réseau).
#' @keywords internal
#' @noRd
fetch_wp_year <- function(annee, registry_repo = "ofceweb/wp-registry") {
  year_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/wp/%d.json",
    registry_repo, as.integer(annee))
  tryCatch(
    jsonlite::fromJSON(year_url, simplifyVector = FALSE)$wp,
    error = function(e) NULL
  )
}

#' Fusionne toutes les entrées du registre central `wp-registry`
#'
#' Télécharge `wp/index.json` puis chaque `wp/{année}.json` qui y est listé,
#' et fusionne toutes les entrées obtenues. Tolérant : une année illisible
#' individuellement est ignorée avec un avertissement, sans bloquer la
#' lecture des autres années.
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#' @return Liste fusionnée d'entrées, ou `NULL` si `wp/index.json` lui-même
#'   est inaccessible (à distinguer d'une liste vide, qui signifie un
#'   registre lu avec succès mais sans années ou sans entrées).
#' @keywords internal
#' @noRd
fetch_wp_entries <- function(registry_repo = "ofceweb/wp-registry") {
  years <- fetch_wp_index(registry_repo)
  if (is.null(years)) return(NULL)

  entries <- list()
  for (y in years) {
    yr_entries <- fetch_wp_year(y, registry_repo)
    if (is.null(yr_entries)) {
      cli::cli_alert_warning(
        "Ann\u00e9e {.val {y}} du registre illisible ({.url wp/{y}.json}) \u2014 ignor\u00e9e.")
      next
    }
    entries <- c(entries, yr_entries)
  }
  entries
}

#' Résout le slug GitHub `"owner/repo"` depuis le remote `origin`
#'
#' Fonctionne avec les URLs HTTPS et SSH. Retire le suffixe `.git` si présent.
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
