# Résout le chemin d'un fichier .qmd depuis un dossier ou un chemin direct.
# Erreur si zéro ou plusieurs .qmd trouvés.
.resolve_qmd <- function(path) {
  path <- path |>
    fs::path_expand() |> fs::path_abs() |> fs::path_norm() |> as.character()

  if (fs::is_file(path)) {
    if (!identical(tolower(fs::path_ext(path)), "qmd"))
      cli::cli_abort("Le fichier {.file {fs::path_file(path)}} n'est pas un {.code .qmd}.")
    return(path)
  }

  if (!fs::is_dir(path))
    cli::cli_abort("Chemin introuvable : {.path {path}}.")

  qmds <- fs::dir_ls(path, glob = "*.qmd", type = "file")
  qmds <- qmds[!startsWith(fs::path_file(qmds) |> as.character(), "_")]

  if (length(qmds) == 0L)
    cli::cli_abort("Aucun {.code .qmd} dans {.path {path}}.")

  if (length(qmds) > 1L) {
    nms <- paste0("{.file ", fs::path_file(qmds), "}")
    cli::cli_abort(c(
      "Plusieurs {.code .qmd} dans {.path {path}} : {.and {nms}}",
      "i" = "Passez le chemin direct vers le {.code .qmd} cible."
    ))
  }

  as.character(qmds)
}


# Détecte les noms de packages R utilisés dans un .qmd (library/require/::).
# Exclut les packages de base R.
.detect_packages <- function(qmd_path) {
  body <- paste(readLines(qmd_path, warn = FALSE), collapse = "\n")

  pkgs <- character()

  m <- stringr::str_match_all(
    body,
    "(?:library|require)\\s*\\(\\s*[\"']?([A-Za-z][\\w.]*)[\"']?\\s*\\)"
  )[[1L]]
  if (nrow(m) > 0L) pkgs <- c(pkgs, m[, 2L])

  m <- stringr::str_match_all(body, "([A-Za-z][\\w.]*)::(?:[\\w.]+)")[[1L]]
  if (nrow(m) > 0L) pkgs <- c(pkgs, m[, 2L])

  base_pkgs <- c(
    "base", "utils", "stats", "methods", "graphics", "grDevices",
    "datasets", "tools", "compiler", "parallel", "grid", "splines"
  )
  unique(pkgs[!is.na(pkgs) & !pkgs %in% base_pkgs])
}


#' Scanne un .qmd pour identifier tous les fichiers nécessaires à sa compilation
#'
#' Analyse le YAML frontmatter et le corps du document pour extraire les
#' références à des fichiers locaux (données, bibliographie, images, includes).
#' Seuls les chemins relatifs pointant dans le dossier du `.qmd` ou ses
#' sous-dossiers sont retenus — les URLs, chemins absolus et remontées `../`
#' sont exclus.
#'
#' @param qmd_path Chemin vers le fichier `.qmd`.
#' @return Vecteur de caractères : chemins relatifs depuis le dossier du `.qmd`.
#' @importFrom fs path_norm path_abs path_expand
#' @importFrom stringr str_match_all
#' @keywords internal
scan_qmd_deps <- function(qmd_path) {
  qmd_path <- qmd_path |>
    fs::path_abs() |> fs::path_norm() |> as.character()

  yml   <- tryCatch(get_yaml(qmd_path), error = function(e) list())
  lines <- readLines(qmd_path, warn = FALSE)

  delims     <- grep("^---\\s*$", lines)
  body_lines <- if (length(delims) >= 2L) lines[(delims[2L] + 1L):length(lines)] else lines
  body       <- paste(body_lines, collapse = "\n")

  refs <- character()

  # Champs YAML pointant directement vers des fichiers
  for (field in c("bibliography", "image", "csl")) {
    val <- yml[[field]]
    if (!is.null(val) && is.character(val) && nzchar(val))
      refs <- c(refs, val)
  }

  # Patterns de référence à des fichiers dans le corps du document
  patterns <- c(
    'source(?:_data)?\\s*\\(\\s*["\']([^"\']+?)["\']',
    'read_csv2?\\s*\\(\\s*["\']([^"\']+?)["\']',
    'read_xlsx?\\s*\\(\\s*["\']([^"\']+?)["\']',
    'readRDS\\s*\\(\\s*["\']([^"\']+?)["\']',
    'readLines\\s*\\(\\s*["\']([^"\']+?)["\']',
    'qs(?:2)?::qs_read\\s*\\(\\s*["\']([^"\']+?)["\']',
    'include_graphics\\s*\\(\\s*["\']([^"\']+?)["\']',
    '!\\[[^\\]]*\\]\\(([^)#?\\s][^)]*?)\\)',
    '\\{\\{<\\s*include\\s+([^\\s>]+?)\\s*>\\}\\}'
  )

  for (pat in patterns) {
    m <- stringr::str_match_all(body, pat)[[1L]]
    if (nrow(m) > 0L) refs <- c(refs, m[, 2L])
  }

  refs <- refs[!is.na(refs)]
  refs <- refs[!grepl("^https?://", refs)]   # pas d'URL
  refs <- refs[!grepl("^/", refs)]           # pas de chemin absolu
  refs <- refs[!grepl("\\.\\./", refs)]      # pas de remontée ../
  unique(refs)
}


#' Vérifie la structure d'un post de blog avant soumission
#'
#' Inspecte le YAML frontmatter du `.qmd` et les fichiers qu'il référence pour
#' détecter les problèmes bloquants (champs obligatoires manquants, fichiers
#' introuvables) et les avertissements (dépendances manquantes).
#'
#' @param path Chemin vers le `.qmd` ou son dossier parent. Défaut `"."`.
#' @param verbose Logique. Affiche les diagnostics. Défaut `TRUE`.
#' @return Data frame (invisible) : colonnes `field`, `status`, `message`.
#' @importFrom fs path_dir path_file path file_exists
#' @importFrom cli cli_h1 cli_rule cli_alert_success cli_alert_warning cli_alert_danger
#' @importFrom purrr transpose
#' @export
check_blog <- function(path = ".", verbose = TRUE) {

  qmd_path <- .resolve_qmd(path)
  root     <- fs::path_dir(qmd_path) |> as.character()

  diags <- list()
  add_diag <- function(field, status, msg) {
    n        <- length(diags) + 1L
    diags[[n]] <<- list(field = field, status = status, message = msg)
  }

  if (verbose) cli::cli_h1("check_blog : {fs::path_file(qmd_path)}")

  yml <- tryCatch(get_yaml(qmd_path), error = function(e) {
    add_diag("yaml", "error", paste0("YAML illisible : ", e$message))
    NULL
  })

  if (!is.null(yml)) {
    for (field in c("title", "author", "date", "categories")) {
      if (is.null(yml[[field]]))
        add_diag(field, "error",  paste0("Champ `", field, "` absent."))
      else
        add_diag(field, "ok",     paste0("Champ `", field, "` présent."))
    }

    for (field in c("bibliography", "image", "csl")) {
      val <- yml[[field]]
      if (!is.null(val) && is.character(val) && nzchar(val)) {
        if (fs::file_exists(fs::path(root, val)))
          add_diag(field, "ok",    paste0(field, " trouvé : ", val))
        else
          add_diag(field, "error", paste0(field, " déclaré mais introuvable : ", val))
      }
    }
  }

  deps <- tryCatch(scan_qmd_deps(qmd_path), error = function(e) character())
  for (dep in deps) {
    if (grepl("\\.\\./", dep))
      add_diag(dep, "error",   paste0("Chemin interdit (remontée hors dossier) : ", dep))
    else if (!fs::file_exists(fs::path(root, dep)))
      add_diag(dep, "warning", paste0("Fichier référencé introuvable : ", dep))
  }

  df <- if (length(diags) > 0L) {
    td <- purrr::transpose(diags)
    data.frame(
      field   = unlist(td$field),
      status  = unlist(td$status),
      message = unlist(td$message),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      field = character(), status = character(),
      message = character(), stringsAsFactors = FALSE
    )
  }

  if (verbose) {
    cli::cli_rule("Diagnostics check_blog()")
    for (i in seq_len(nrow(df))) {
      switch(df$status[i],
        "error"   = cli::cli_alert_danger( "{.strong {df$field[i]}} : {df$message[i]}"),
        "warning" = cli::cli_alert_warning("{df$field[i]} : {df$message[i]}"),
                    cli::cli_alert_success("{df$field[i]} : {df$message[i]}")
      )
    }
    n_err  <- sum(df$status == "error")
    n_warn <- sum(df$status == "warning")
    cli::cli_rule()
    if (n_err > 0L)
      cli::cli_alert_danger("{n_err} erreur{?s} bloquante{?s}, {n_warn} avertissement{?s}.")
    else
      cli::cli_alert_success("Aucune erreur bloquante. {n_warn} avertissement{?s}.")
  }

  invisible(df)
}


#' Soumet un post de blog pour relecture dans ofce/Blog_relecture
#'
#' Orchestre la soumission d'un post de blog Quarto :
#' \enumerate{
#'   \item Vérifie la structure du post via [check_blog()].
#'   \item Scanne le `.qmd` pour identifier toutes ses dépendances fichier via
#'     [scan_qmd_deps()].
#'   \item Met à jour le clone local de `blog_relecture`.
#'   \item Crée une branche `relecture/<slug>`.
#'   \item Copie le `.qmd` et ses dépendances dans `relecture/<slug>/`.
#'   \item Teste la compilation dans l'environnement renv de `blog_relecture`
#'     via [callr::r()] ; installe les packages manquants et met à jour le
#'     lockfile si nécessaire.
#'   \item Committe et pousse la branche.
#'   \item Ouvre une pull request vers `main`.
#' }
#'
#' En cas d'échec de la compilation, la branche et les fichiers copiés sont
#' supprimés — `blog_relecture` n'est pas modifié.
#'
#' @param path Chemin vers le dossier du post ou vers le `.qmd` directement.
#'   Défaut `"."`.
#' @param slug Identifiant du post (nom du sous-dossier créé dans `relecture/`).
#'   Dérivé automatiquement du nom du `.qmd` si `NULL`.
#' @param blog_relecture_path Chemin local vers le clone de `ofce/Blog_relecture`.
#'   Défaut `"~/Documents/GitHub/blog_relecture"`.
#' @param open_pr Logique. Ouvre une pull request GitHub après le push.
#'   Défaut `TRUE`.
#' @param check Logique. Lance [check_blog()] avant la soumission et bloque sur
#'   les erreurs. Défaut `TRUE`.
#'
#' @return Invisible : URL de la PR créée, ou `NULL` si `open_pr = FALSE`.
#' @seealso [check_blog()], [scan_qmd_deps()]
#' @importFrom fs path_norm path_abs path_expand path_dir path_file path_ext path_ext_remove path is_file is_dir dir_exists file_exists dir_create dir_delete file_copy path_rel dir_ls
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_alert_info cli_alert_success cli_alert_warning cli_alert_danger
#' @importFrom gert git_branch git_branch_list git_branch_checkout git_branch_create git_branch_delete git_fetch git_pull git_status git_add git_commit git_push git_remote_list
#' @importFrom gh gh
#' @importFrom stringr str_match_all
#' @export
submit_blog <- function(
    path                = ".",
    slug                = NULL,
    blog_relecture_path = "~/Documents/GitHub/blog_relecture",
    open_pr             = TRUE,
    check               = TRUE) {

  # ---- 1. Résolution des chemins -------------------------------------------
  qmd_path  <- .resolve_qmd(path)
  qmd_dir   <- fs::path_dir(qmd_path)  |> as.character()
  qmd_name  <- fs::path_file(qmd_path) |> as.character()
  blog_root <- blog_relecture_path |>
    fs::path_expand() |> fs::path_abs() |> fs::path_norm() |> as.character()

  if (!fs::dir_exists(blog_root))
    cli::cli_abort(c(
      "Dépôt blog_relecture introuvable : {.path {blog_root}}.",
      "i" = "Ajustez {.arg blog_relecture_path}."
    ))

  if (is.null(slug)) {
    slug <- qmd_name |>
      fs::path_ext_remove() |> as.character() |> tolower() |>
      gsub(pattern = "[^a-z0-9_-]", replacement = "_") |>
      gsub(pattern = "_+",          replacement = "_")  |>
      gsub(pattern = "^_|_$",       replacement = "")
  }

  cli::cli_h1("submit_blog : {slug}")

  # ---- 2. Vérification du post ---------------------------------------------
  if (check) {
    cli::cli_h2("Vérification")
    diags <- check_blog(qmd_path, verbose = TRUE)
    if (any(diags$status == "error"))
      cli::cli_abort("Erreurs bloquantes détectées — corrigez avant de soumettre.")
  }

  # ---- 3. Scan des dépendances ---------------------------------------------
  deps <- scan_qmd_deps(qmd_path)
  pkgs <- .detect_packages(qmd_path)

  cli::cli_alert_info("{length(deps)} dépendance(s) fichier identifiée(s).")
  if (length(pkgs) > 0L)
    cli::cli_alert_info("Packages R détectés : {.pkg {pkgs}}")

  # ---- 4. Mise à jour du clone ---------------------------------------------
  cli::cli_h2("Mise à jour de blog_relecture")
  curr_branch <- gert::git_branch(repo = blog_root)
  if (!identical(curr_branch, "main"))
    gert::git_branch_checkout("main", repo = blog_root)
  tryCatch(
    gert::git_pull(repo = blog_root),
    error = function(e)
      cli::cli_alert_warning("git pull échoué : {e$message}. Poursuite avec l'état actuel.")
  )
  cli::cli_alert_success("blog_relecture à jour.")

  # ---- 5. Création de la branche -------------------------------------------
  branch_name  <- paste0("relecture/", slug)
  all_branches <- gert::git_branch_list(repo = blog_root)$name

  if (branch_name %in% all_branches) {
    cli::cli_alert_warning("Branche {.val {branch_name}} existante — suppression.")
    gert::git_branch_delete(branch_name, repo = blog_root)
  }
  gert::git_branch_create(branch_name, checkout = TRUE, repo = blog_root)
  cli::cli_alert_success("Branche {.val {branch_name}} créée.")

  # ---- 6. Copie des fichiers ------------------------------------------------
  target_dir   <- fs::path(blog_root, "relecture", slug) |> as.character()
  missing_deps <- character()

  fs::dir_create(target_dir, recurse = TRUE)
  cli::cli_h2("Copie des fichiers")

  fs::file_copy(qmd_path, fs::path(target_dir, qmd_name), overwrite = TRUE)
  cli::cli_alert_success("Copié : {.file {qmd_name}}")

  for (dep in deps) {
    src <- fs::path(qmd_dir, dep)    |> as.character()
    dst <- fs::path(target_dir, dep) |> as.character()
    if (!fs::file_exists(src)) {
      cli::cli_alert_warning("Introuvable (ignoré) : {.file {dep}}")
      missing_deps <- c(missing_deps, dep)
      next
    }
    fs::dir_create(fs::path_dir(dst), recurse = TRUE)
    fs::file_copy(src, dst, overwrite = TRUE)
    cli::cli_alert_success("Copié : {.file {dep}}")
  }

  # ---- 7. Compilation dans l'environnement renv ----------------------------
  cli::cli_h2("Test de compilation (renv)")
  qmd_dest <- fs::path(target_dir, qmd_name) |> as.character()

  render_ok <- tryCatch({
    callr::r(
      func = function(qmd_path, blog_root, pkgs) {
        # Le .Rprofile de blog_root active renv automatiquement
        renv::restore(project = blog_root, prompt = FALSE)

        if (length(pkgs) > 0L) {
          missing_pkgs <- pkgs[!pkgs %in% rownames(installed.packages())]
          if (length(missing_pkgs) > 0L) {
            message("Installation des packages manquants : ",
                    paste(missing_pkgs, collapse = ", "))
            renv::install(missing_pkgs, prompt = FALSE, project = blog_root)
          }
        }

        quarto::quarto_render(input = qmd_path, as_job = FALSE, quiet = FALSE)
        renv::snapshot(project = blog_root, prompt = FALSE)
        invisible(TRUE)
      },
      args         = list(qmd_path = qmd_dest, blog_root = blog_root, pkgs = pkgs),
      wd           = blog_root,
      user_profile = "project"  # active le .Rprofile → renv
    )
    TRUE
  }, error = function(e) {
    cli::cli_alert_danger("Échec de la compilation :\n{e$message}")
    FALSE
  })

  # Nettoyage en cas d'échec
  if (!render_ok) {
    cli::cli_h2("Nettoyage")
    gert::git_branch_checkout("main", repo = blog_root)
    tryCatch(gert::git_branch_delete(branch_name, repo = blog_root), error = function(e) NULL)
    if (fs::dir_exists(target_dir)) fs::dir_delete(target_dir)
    cli::cli_abort("Compilation échouée — blog_relecture n'a pas été modifié.")
  }

  cli::cli_alert_success("Compilation réussie !")

  # ---- 8. Commit -----------------------------------------------------------
  cli::cli_h2("Commit")
  git_st      <- gert::git_status(repo = blog_root)
  slug_prefix <- paste0("relecture/", slug, "/")

  files_post <- git_st$file[
    startsWith(git_st$file, slug_prefix) &
    git_st$status %in% c("new", "modified")
  ]
  files_renv <- git_st$file[
    git_st$file == "renv.lock" & git_st$status %in% c("new", "modified")
  ]
  files_to_commit <- c(files_post, files_renv)

  if (length(files_to_commit) == 0L) {
    cli::cli_alert_warning("Aucun fichier à committer.")
  } else {
    gert::git_add(files_to_commit, repo = blog_root)
    commit_msg <- if (length(files_renv) > 0L)
      paste0("submit: ", slug, " [renv update]")
    else
      paste0("submit: ", slug)
    gert::git_commit(message = commit_msg, repo = blog_root)
    cli::cli_alert_success("Commit : {.val {commit_msg}}")
  }

  # ---- 9. Push -------------------------------------------------------------
  cli::cli_h2("Push")
  gert::git_push(
    remote  = "origin",
    refspec = paste0("refs/heads/", branch_name, ":refs/heads/", branch_name),
    repo    = blog_root,
    verbose = TRUE
  )

  if (!open_pr) return(invisible(NULL))

  # ---- 10. Pull Request ----------------------------------------------------
  cli::cli_h2("Pull Request")

  remotes    <- gert::git_remote_list(repo = blog_root)
  origin_url <- remotes$url[remotes$name == "origin"]
  gh_slug    <- origin_url |>
    sub(pattern = "\\.git$",           replacement = "") |>
    sub(pattern = "^git@[^:]+:",       replacement = "") |>
    sub(pattern = "^https?://[^/]+/",  replacement = "")
  gh_parts   <- strsplit(gh_slug, "/")[[1L]]
  gh_owner   <- gh_parts[[1L]]
  gh_repo    <- gh_parts[[2L]]

  qmd_yml  <- tryCatch(get_yaml(qmd_dest), error = function(e) list())
  pr_title <- if (!is.null(qmd_yml$title)) as.character(qmd_yml$title) else slug

  authors <- if (!is.null(qmd_yml$author)) {
    auth <- qmd_yml$author
    if (is.character(auth)) {
      auth
    } else if (is.list(auth)) {
      vapply(auth, function(a) {
        if (is.list(a)) { nm <- a[["name"]]; if (is.null(nm)) "" else as.character(nm) }
        else as.character(a)
      }, character(1L))
    } else character()
  } else character()
  authors <- authors[nzchar(authors)]

  all_files <- c(qmd_name, deps)
  dep_lines <- paste0("- `relecture/", slug, "/", all_files, "`", collapse = "\n")

  missing_note <- if (length(missing_deps) > 0L)
    paste0(
      "\n> **Note :** ", length(missing_deps),
      " fichier(s) déclaré(s) dans le `.qmd` non trouvé(s) lors de la soumission : ",
      paste0("`", missing_deps, "`", collapse = ", "), ".\n"
    )
  else ""

  pr_body <- paste0(
    "## Soumission : `", slug, "`\n\n",
    if (length(authors) > 0L)
      paste0("**Auteur(s) :** ", paste(authors, collapse = ", "), "\n\n")
    else "",
    if (!is.null(qmd_yml$date))
      paste0("**Date :** ", qmd_yml$date, "\n\n")
    else "",
    "### Fichiers inclus\n\n", dep_lines, "\n",
    missing_note,
    "\n---\n*Soumis via `ofceweb::submit_blog()`*"
  )

  pr <- gh::gh(
    "POST /repos/{owner}/{repo}/pulls",
    owner = gh_owner,
    repo  = gh_repo,
    title = pr_title,
    head  = branch_name,
    base  = "main",
    body  = pr_body
  )

  cli::cli_alert_success("PR créée : {.url {pr$html_url}}")
  invisible(pr$html_url)
}
