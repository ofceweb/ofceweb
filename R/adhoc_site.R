#' Render an arbitrary folder as a standalone Quarto site
#'
#' Renders any folder — anywhere inside a larger git project — as a small
#' standalone Quarto site in an isolated temp directory, leaving only a `_site/`
#' artifact inside that folder. The generated site is marked with a small OFCE
#' quick-publish banner for context. The slug (unique identifier) is computed
#' from the folder's relative path within its repo and persisted in `_site/.adhoc-meta.json`.
#'
#' @param path `[character(1)]`\cr
#'   Folder to render (relative or absolute). Defaults to `"."`.
#' @param index `[character(1)]`\cr
#'   Filename (relative to `path`) of the file to treat as the home page
#'   (e.g., `"slides.qmd"`, `"notes.md"`). Must be a single `.qmd` or `.md`
#'   file. If `NULL` (default), auto-detects when exactly one `.qmd` exists
#'   directly in `path`; otherwise errors with a list of candidates.
#' @param slug `[character(1)]`\cr
#'   Override the auto-computed slug (unique identifier). If `NULL` (default),
#'   computed from the folder's relative path using [adhoc_slug()]. Persisted
#'   in `_site/.adhoc-meta.json` for [deploy_folder()].
#' @param progress `[logical(1)]`\cr
#'   If `TRUE` (default), progress is reported to the console.
#' @param preview `[logical(1)]`\cr
#'   If `TRUE` (default), launches a live preview server via [servr::httw()]
#'   on the rendered site **when `as_job = FALSE`** only (ignored when
#'   `as_job = TRUE` — use [preview_folder()] afterwards instead).
#' @param as_job `[logical(1)]`\cr
#'   If `TRUE` (default), and RStudio is available (checked via
#'   `rstudioapi::isAvailable()`), runs the render pipeline as a background job
#'   in RStudio's Background Jobs pane. All output (including errors) streams
#'   live to the Jobs pane console; when done, a summary appears in the global
#'   environment as `adhoc_last_render` (a list with `ok`, `url`, and optionally
#'   `error`). If `FALSE` or RStudio is unavailable, runs synchronously in the
#'   current session. See Details for integration patterns.
#'
#' @return Invisibly returns `NULL` when synchronous (`as_job = FALSE`) or
#'   RStudio unavailable. When `as_job = TRUE` with RStudio available, returns
#'   immediately and populates `adhoc_last_render` in the global environment
#'   when the job finishes.
#'
#' @details
#'
#' ## Render pipeline
#'
#' 1. Resolves the enclosing git repository root from `path`.
#' 2. Computes a deterministic `slug` (if not overridden).
#' 3. Creates a scratch temp directory and copies `path`'s contents into it
#'    (excluding `_site/`, `.quarto/`, `_freeze/`, `.git*`).
#' 4. Collects any `_extensions/` directories from `path` or its ancestors
#'    (up to the repo root) and includes them in the temp copy so extension
#'    shortcodes resolve correctly.
#' 5. If the temp copy has no `_quarto.yml`, writes a minimal default one.
#' 6. Renders the folder via `quarto::quarto_render()` in the temp directory.
#' 7. Locates the HTML output for `index` and copies it to `_site/index.html`
#'    (preserving the original filename too).
#' 8. Post-processes all `*.html` files to inject a small OFCE quick-publish
#'    banner right after the opening `<body...>` tag.
#' 9. Cleans `.DS_Store` files, then copies the temp `_site/` into `<path>/_site/`
#'    (replacing if present). Writes metadata (slug, index, timestamp) to
#'    `_site/.adhoc-meta.json`.
#' 10. If `preview = TRUE` and `as_job = FALSE`, launches [preview_folder()].
#'
#' ## Self-contained folders
#'
#' The folder must be reasonably self-contained. Relative paths that climb
#' outside it (e.g., `../shared-bib.bib`, `../../www/logo.png`) won't resolve
#' in the temp copy, since only the folder itself (plus discovered `_extensions/`)
#' is copied over. If `quarto_render()` fails on a missing file, check whether
#' any includes are pointing outside the folder.
#'
#' ## `.gitignore` housekeeping
#'
#' We recommend adding `_site/` to the folder's `.gitignore` if not already
#' present, so it isn't accidentally committed:
#' ```
#' echo "_site/" >> <path>/.gitignore
#' ```
#'
#' @seealso [deploy_folder()], [publish_folder()], [preview_folder()], [render_prev()]
#' @importFrom fs path_expand path_abs path_norm path_rel dir_create dir_copy
#'             file_exists dir_exists dir_delete dir_ls file_delete
#'             path_file path_join
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_alert_success cli_alert_info
#' @importFrom quarto quarto_render
#' @importFrom yaml read_yaml write_yaml
#' @importFrom servr httw
#' @importFrom jsonlite toJSON fromJSON
#' @importFrom glue glue
#' @importFrom stringr str_replace_all str_trim
#' @importFrom rlang env env_names
#' @export
render_folder <- function(
    path     = ".",
    index    = NULL,
    slug     = NULL,
    progress = TRUE,
    preview  = TRUE,
    as_job   = TRUE) {

  # If as_job = TRUE and RStudio is available, spin off a background job
  if (as_job && rstudioapi::isAvailable()) {
    args_env <- rlang::env(
      path     = path,
      index    = index,
      slug     = slug,
      progress = progress,
      preview  = preview
    )

    # Create a job script that will run the worker, capture errors, and export result
    job_script <- tempfile(fileext = ".R")
    script_content <- glue::glue(
      '# Auto-generated job script for render_folder
       result <- tryCatch({{
         url <- ofceweb:::render_folder_worker(
          path = "{path}", index = {if (is.null(index)) "NULL" else paste0("\\"", index, "\\"")}, slug = {if (is.null(slug)) "NULL" else paste0("\\"", slug, "\\"")},
          progress = {progress}, preview = {preview}
        )
        list(ok = TRUE, url = url)
      }, error = function(e) {{
        message(conditionMessage(e))
        list(ok = FALSE, error = conditionMessage(e))
      }})
      adhoc_last_render <- result',
      .open = "{", .close = "}"
    )

    writeLines(script_content, job_script)
    # Note: do NOT unlink(job_script) here — jobRunScript() launches the job
    # asynchronously, so the calling function returns (and any on.exit would
    # fire) well before the background process has read the script. The temp
    # file is cleaned up automatically when the R session's tempdir is purged.

    repo_root <- find_git_root(path)
    rstudioapi::jobRunScript(
      path        = job_script,
      workingDir  = repo_root,
      importEnv   = TRUE,
      exportEnv   = "R_GlobalEnv"
    )

    cli::cli_alert_info(
      "Rendu lancé en arrière-plan (onglet {.emph Jobs}). \\
       À la fin, {.code adhoc_last_render} apparaîtra dans votre environnement."
    )
    return(invisible(NULL))
  }

  # Otherwise run synchronously
  ofceweb:::render_folder_worker(
    path     = path,
    index    = index,
    slug     = slug,
    progress = progress,
    preview  = preview
  )

  invisible(NULL)
}


#' Worker function for render_folder (internal synchronous implementation)
#'
#' This function contains the actual render logic, separated so it can be
#' called either directly (synchronous) or from a background job script.
#'
#' @inheritParams render_folder
#' @keywords internal
#' @return Invisibly returns the resulting URL (character string).
render_folder_worker <- function(
    path,
    index,
    slug,
    progress,
    preview) {

  # Resolve paths
  target <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  repo_root <- find_git_root(target)

  if (!fs::dir_exists(target))
    cli::cli_abort("Dossier {.path {target}} non trouvé.")

  # Auto-detect index if not supplied
  if (is.null(index)) {
    qmd_files <- fs::dir_ls(target, type = "file", regexp = "\\.(qmd)$") |>
      fs::path_file() |> as.character()
    qmd_files <- qmd_files[!startsWith(qmd_files, "_")]
    if (length(qmd_files) == 1) {
      index <- qmd_files[[1]]
    } else if (length(qmd_files) > 1) {
      cli::cli_abort(c(
        "Impossible de détecter un seul fichier index.",
        "i" = "Candidats trouvés : {paste(qmd_files, collapse = ', ')}",
        "i" = "Veuillez spécifier {.arg index} explicitement."
      ))
    } else {
      cli::cli_abort("Aucun fichier .qmd trouvé dans {.path {target}}.")
    }
  }

  index_path <- fs::path(target, index)
  if (!fs::file_exists(index_path))
    cli::cli_abort("Fichier index {.path {index}} non trouvé dans {.path {target}}.")

  # Compute slug if not supplied
  if (is.null(slug)) {
    rel_path <- fs::path_rel(target, repo_root)
    slug <- adhoc_slug(rel_path)
  }

  if (progress)
    cli::cli_h1("Rendu du dossier {.path {fs::path_file(target)}} (slug: {.code {slug}})")

  # Create temp directory
  temp_dir <- fs::path(
    tempdir(),
    glue::glue("adhoc-{slug}-{as.integer(Sys.time())}")
  )
  fs::dir_create(temp_dir, recurse = TRUE)
  on.exit(fs::dir_delete(temp_dir), add = TRUE)

  # Copy target folder contents into temp (excluding build artifacts)
  fs::dir_copy(
    target,
    temp_dir,
    overwrite = TRUE
  )

  # Remove any pre-existing build artifacts from temp copy
  for (artifact in c("_site", ".quarto", "_freeze", ".git")) {
    artifact_path <- fs::path(temp_dir, artifact)
    if (file.exists(artifact_path)) {
      if (dir.exists(artifact_path)) {
        fs::dir_delete(artifact_path)
      } else {
        fs::file_delete(artifact_path)
      }
    }
  }

  # Collect _extensions from target and ancestors
  if (progress)
    cli::cli_h2("Collecte des extensions Quarto")

  extensions_dir <- fs::path(temp_dir, "_extensions")
  current <- target
  while (current != "/" && current != dirname(current)) {
    ext_candidate <- fs::path(current, "_extensions")
    if (fs::dir_exists(ext_candidate)) {
      if (!fs::dir_exists(extensions_dir))
        fs::dir_create(extensions_dir, recurse = TRUE)
      # Copy extension directories (first match wins for each name)
      for (ext_subdir in fs::dir_ls(ext_candidate, type = "dir")) {
        ext_name <- fs::path_file(ext_subdir)
        dest_ext <- fs::path(extensions_dir, ext_name)
        if (!fs::dir_exists(dest_ext)) {
          fs::dir_copy(ext_subdir, dest_ext, overwrite = TRUE)
          if (progress)
            cli::cli_alert_info("Extension trouvée : {ext_name}")
        }
      }
    }
    if (current == repo_root) break
    current <- dirname(current)
  }

  # Ensure _quarto.yml exists in temp
  quarto_yml <- fs::path(temp_dir, "_quarto.yml")
  if (!fs::file_exists(quarto_yml)) {
    if (progress)
      cli::cli_h2("Création d'une configuration Quarto minimale")
    minimal_config <- list(
      project = list(
        type      = "default",
        `output-dir` = "_site"
      ),
      format = list(
        html = list(
          theme = "cosmo"
        )
      )
    )
    yaml::write_yaml(minimal_config, quarto_yml)
  }

  # Render
  if (progress)
    cli::cli_h2("Rendu Quarto")

  oldwd <- getwd()
  on.exit(setwd(oldwd), add = TRUE)
  setwd(temp_dir)

  quarto::quarto_render(as_job = FALSE)

  setwd(oldwd)

  # Find the rendered HTML for index
  index_basename <- fs::path_file(index_path) |>
    as.character() |>
    sub(pattern = "\\.(qmd|md)$", replacement = ".html")

  site_dir <- fs::path(temp_dir, "_site")
  rendered_html <- fs::path(site_dir, index_basename)

  if (!fs::file_exists(rendered_html))
    cli::cli_abort(
      "Fichier rendu {.path {index_basename}} non trouvé dans {.path _site}."
    )

  # Copy as index.html if not already named that
  if (index_basename != "index.html") {
    fs::file_copy(rendered_html, fs::path(site_dir, "index.html"), overwrite = TRUE)
    if (progress)
      cli::cli_alert_info(
        "Copie de {.path {index_basename}} vers {.path index.html}"
      )
  }

  # Inject banner into all HTML files
  if (progress)
    cli::cli_h2("Injection de la bannière OFCE")

  inject_quick_publish_banner(site_dir)

  # Clean .DS_Store
  if (progress)
    cli::cli_h2("Nettoyage")

  fs::dir_ls(site_dir, recurse = TRUE, regexp = "\\.DS_Store$", type = "file", all = TRUE) |>
    fs::file_delete()

  # Copy _site to target/_site
  output_dir <- fs::path(target, "_site")
  if (fs::dir_exists(output_dir))
    fs::dir_delete(output_dir)

  fs::dir_copy(site_dir, output_dir, overwrite = TRUE)

  # Write metadata
  metadata <- list(
    slug         = slug,
    index        = index,
    rendered_at  = as.character(Sys.time())
  )
  meta_file <- fs::path(output_dir, ".adhoc-meta.json")
  # auto_unbox = TRUE: without it, write_json() wraps every scalar in a
  # single-element JSON array (e.g. "slug": ["x"]), which round-trips back
  # as a length-1 list on read and silently breaks anything expecting a
  # plain string (e.g. workflow_dispatch inputs).
  jsonlite::write_json(metadata, meta_file, auto_unbox = TRUE, pretty = TRUE)

  # Compute and return the URL (but don't display it until deployed)
  repo_slug <- gh_slug_from_remote(repo_root)
  if (is.na(repo_slug))
    cli::cli_warn("Impossible de déterminer le slug du dépôt depuis le remote.")

  url <- glue::glue("https://staging.ofce.fr/{strsplit(repo_slug, '/')[[1]][2]}/{slug}/")

  if (progress) {
    cli::cli_alert_success("Rendu terminé")
    if (!preview) {
      cli::cli_alert_info(
        "Pour prévisualiser : {.code ofceweb::preview_folder('{path}')}"
      )
    }
  }

  # Launch preview if requested and synchronous
  if (preview) {
    preview_folder(path)
  }

  invisible(url)
}


#' Deploy a rendered ad-hoc folder site to staging
#'
#' Pushes the `_site/` folder (previously rendered by [render_folder()]) to a
#' git branch and triggers FTP deployment to `staging.ofce.fr`. The slug is read
#' from the persisted metadata (`_site/.adhoc-meta.json`) if not supplied.
#'
#' @param path `[character(1)]`\cr
#'   Folder to deploy (relative or absolute). Defaults to `"."`.
#' @param slug `[character(1)]`\cr
#'   Deployment identifier (must match the slug used in [render_folder()]).
#'   If `NULL` (default), read from `_site/.adhoc-meta.json` or recomputed
#'   from the folder's path.
#' @param encrypt `[logical(1)]`\cr
#'   If `TRUE` (default), the deployed site is encrypted via staticrypt
#'   (if `STATICRYPT_PASSWORD` is configured). Set to `FALSE` to publish
#'   unencrypted even if the password is set (via a `.no-staticrypt` marker
#'   file; requires the updated `ftp_deploy_profile.yml` workflow).
#' @param progress `[logical(1)]`\cr
#'   If `TRUE` (default), progress is reported to the console.
#' @param trigger `[logical(1)]`\cr
#'   If `TRUE` (default), triggers the FTP deployment workflow via
#'   `workflow_dispatch` after the git push. Set to `FALSE` to push only.
#' @param full_deploy `[logical(1)]`\cr
#'   If `TRUE`, forces the FTP workflow to re-upload all files
#'   (ignores incremental upload state). Defaults to `FALSE`.
#' @param as_job `[logical(1)]`\cr
#'   If `TRUE` and RStudio is available, runs as a background job.
#'   Defaults to `FALSE` (push+trigger is usually fast enough).
#'
#' @return Invisibly returns `NULL`. Prints the resulting URL on success.
#'
#' @details
#'
#' ## Pre-flight checks
#'
#' - Verifies that `<path>/_site/` exists (must have been created by
#'   [render_folder()] or manually).
#' - If `encrypt = FALSE` is requested, checks whether the installed
#'   `ftp_deploy_profile.yml` workflow supports the `.no-staticrypt` marker
#'   (added in recent versions). If not, warns and proceeds with encryption.
#'
#' ## Workflow auto-install
#'
#' The first time `deploy_folder()` is called on a repo, it auto-installs
#' `.github/workflows/ftp_deploy_profile.yml` from the package if missing.
#' This is an idempotent, additive operation:
#'
#' - On unprotected default branches, the workflow is committed directly.
#' - On protected default branches, a PR is opened and you're asked to merge it
#'   (one-time per repo). After merge, subsequent calls proceed normally.
#'
#' @seealso [render_folder()], [publish_folder()], [preview_folder()], [deploy_prev()]
#' @importFrom fs path_expand path_abs path_norm path_rel path_file dir_exists file_exists
#' @importFrom cli cli_h1 cli_abort cli_alert_success cli_alert_warning cli_alert_info
#' @importFrom rlang env
#' @export
deploy_folder <- function(
    path        = ".",
    slug        = NULL,
    encrypt     = TRUE,
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE,
    as_job      = FALSE) {

  # If as_job = TRUE and RStudio available, spin off a background job
  if (as_job && rstudioapi::isAvailable()) {
    args_env <- rlang::env(
      path        = path,
      slug        = slug,
      encrypt     = encrypt,
      progress    = progress,
      trigger     = trigger,
      full_deploy = full_deploy
    )

    job_script <- tempfile(fileext = ".R")
    script_content <- glue::glue(
      '# Auto-generated job script for deploy_folder
       result <- tryCatch({{
         url <- ofceweb::deploy_folder_worker(
           path = "{path}", slug = {if (is.null(slug)) "NULL" else paste0("\\"", slug, "\\"")},
           encrypt = {encrypt}, progress = {progress}, trigger = {trigger},
           full_deploy = {full_deploy}
         )
         list(ok = TRUE, url = url)
       }, error = function(e) {{
         message(conditionMessage(e))
         list(ok = FALSE, error = conditionMessage(e))
       }})
       adhoc_last_deploy <- result',
      .open = "{", .close = "}"
    )

    writeLines(script_content, job_script)
    # Note: do NOT unlink(job_script) here — see the equivalent comment in
    # render_folder() above; the job reads the file asynchronously.

    repo_root <- find_git_root(path)
    rstudioapi::jobRunScript(
      path        = job_script,
      workingDir  = repo_root,
      importEnv   = TRUE,
      exportEnv   = "R_GlobalEnv"
    )

    cli::cli_alert_info(
      "Déploiement lancé en arrière-plan (onglet {.emph Jobs}). \\
       À la fin, {.code adhoc_last_deploy} apparaîtra dans votre environnement."
    )
    return(invisible(NULL))
  }

  # Otherwise run synchronously
  deploy_folder_worker(
    path        = path,
    slug        = slug,
    encrypt     = encrypt,
    progress    = progress,
    trigger     = trigger,
    full_deploy = full_deploy
  )

  invisible(NULL)
}


#' Worker function for deploy_folder (internal synchronous implementation)
#'
#' @inheritParams deploy_folder
#' @keywords internal
#' @return Invisibly returns the resulting URL (character string).
deploy_folder_worker <- function(
    path,
    slug,
    encrypt,
    progress,
    trigger,
    full_deploy) {

  # Resolve paths
  target <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  repo_root <- find_git_root(target)

  # Check for _site
  site_dir <- fs::path(target, "_site")
  if (!fs::dir_exists(site_dir))
    cli::cli_abort(
      "Dossier {.path _site} non trouvé dans {.path {target}}. \\
       Veuillez d'abord lancer {.code ofceweb::render_folder()}."
    )

  if (progress)
    cli::cli_h1("Déploiement du dossier {.path {fs::path_file(target)}}")

  # Resolve slug
  if (is.null(slug)) {
    meta_file <- fs::path(site_dir, ".adhoc-meta.json")
    if (fs::file_exists(meta_file)) {
      # simplifyVector = TRUE so scalar fields come back as plain character
      # vectors, not length-1 lists -- a list would later serialize as a
      # JSON array (e.g. ["slug"]) when passed as the `profile` input to
      # workflow_dispatch, which GitHub rejects as an invalid string value.
      metadata <- jsonlite::read_json(meta_file, simplifyVector = TRUE)
      slug <- as.character(metadata$slug)[[1]]
      if (progress)
        cli::cli_alert_info("Slug lu depuis les métadonnées : {.code {slug}}")
    } else {
      rel_path <- fs::path_rel(target, repo_root)
      slug <- adhoc_slug(rel_path)
      if (progress)
        cli::cli_alert_info("Slug recalculé : {.code {slug}}")
    }
  }

  # Ensure workflow is installed
  if (progress)
    cli::cli_h2("Vérification et installation du workflow")
  ensure_adhoc_workflow(repo_root, progress = progress)

  # Handle encryption opt-out
  marker_file <- fs::path(site_dir, ".no-staticrypt")
  if (!encrypt) {
    writeLines("", marker_file)
    if (progress)
      cli::cli_alert_info("Chiffrement désactivé (marqueur {.path .no-staticrypt} écrit)")
  } else {
    if (fs::file_exists(marker_file))
      fs::file_delete(marker_file)
  }

  # Stamp the banner with the actual push date/time (Paris time), not the
  # render time
  stamp_banner_push_time(site_dir)

  # Push via site2branch
  # Note: workflow_dispatch runs the workflow against whatever ref it is
  # dispatched to (the repo's *default* branch here, since trigger_action()
  # doesn't target the site branch) — github.ref_name in that run is "main",
  # NOT "site-{slug}". Relying on the branch-name fallback in the workflow's
  # vars step only works for the automatic push-triggered run (branches:
  # site-**), not for this explicit dispatch. So we must pass the profile
  # explicitly as an input to get the right branch name in both cases.
  rel_site_path <- fs::path_rel(site_dir, repo_root)

  site2branch(
    path        = repo_root,
    branch      = glue::glue("site-{slug}"),
    source      = rel_site_path,
    progress    = progress,
    trigger     = trigger,
    workflow    = "ftp_deploy_profile.yml",
    full_deploy = full_deploy,
    inputs      = list(profile = slug)
  )

  # Compute and report URL
  repo_slug <- gh_slug_from_remote(repo_root)
  if (is.na(repo_slug))
    cli::cli_warn("Impossible de déterminer le slug du dépôt.")

  repo_name <- strsplit(repo_slug, "/")[[1]][2]
  url <- glue::glue("https://staging.ofce.fr/{repo_name}/{slug}/")

  if (progress) {
    cli::cli_alert_success("Déploiement lancé : {.url {url}}")

    # Check if STATICRYPT_PASSWORD is set
    has_password <- tryCatch({
      pat <- Sys.getenv("DEPLOY_PAT", "")
      if (!nchar(pat))
        pat <- tryCatch(
          gitcreds::gitcreds_get("https://github.com")$password,
          error = \(e) ""
        )
      if (!nchar(pat)) {
        cli::cli_warn("Impossible de vérifier si le mot de passe est configuré.")
        return(FALSE)
      }

      owner_repo <- strsplit(repo_slug, "/")[[1]]
      owner <- owner_repo[1]
      repo <- owner_repo[2]

      # Check if STATICRYPT_PASSWORD secret exists
      secrets_url <- sprintf(
        "https://api.github.com/repos/%s/%s/actions/secrets",
        owner, repo
      )
      resp <- httr2::request(secrets_url) |>
        httr2::req_auth_bearer_token(pat) |>
        httr2::req_headers(
          "Accept"               = "application/vnd.github+json",
          "X-GitHub-Api-Version" = "2022-11-28"
        ) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform()

      if (httr2::resp_status(resp) == 200) {
        body <- httr2::resp_body_json(resp)
        any(sapply(body$secrets, \(s) s$name == "STATICRYPT_PASSWORD"))
      } else {
        FALSE
      }
    }, error = \(e) FALSE)

    if (encrypt && has_password) {
      cli::cli_alert_info(
        "Accès protégé par mot de passe (secret {.code STATICRYPT_PASSWORD} configuré)."
      )
    } else if (encrypt && !has_password) {
      cli::cli_alert_warning(
        "Aucun secret {.code STATICRYPT_PASSWORD} détecté — le site sera accessible sans mot de passe."
      )
    }
  }

  invisible(url)
}


#' Render and deploy a folder as a standalone Quarto site, in one step
#'
#' Convenience wrapper chaining [render_folder()] and [deploy_folder()]:
#' renders `path` as a standalone Quarto site, then immediately pushes and
#' deploys it to `staging.ofce.fr`. This is the typical entry point for ad-hoc
#' folder publishing. Call [render_folder()] and [deploy_folder()] separately
#' instead when you want to iterate on the render (e.g. via [preview_folder()])
#' before deploying.
#'
#' @param path `[character(1)]`\cr
#'   Folder to render and deploy (relative or absolute). Defaults to `"."`.
#' @param index `[character(1)]`\cr
#'   See [render_folder()].
#' @param slug `[character(1)]`\cr
#'   Override the auto-computed slug (unique identifier). If `NULL` (default),
#'   [render_folder()] computes it and persists it in `_site/.adhoc-meta.json`,
#'   from which [deploy_folder()] then reads it back — so both steps agree on
#'   the same slug without it needing to be passed explicitly.
#' @param encrypt `[logical(1)]`\cr
#'   See [deploy_folder()]. Defaults to `TRUE`.
#' @param progress `[logical(1)]`\cr
#'   If `TRUE` (default), progress is reported to the console (or the Jobs
#'   pane console when `as_job = TRUE`).
#' @param trigger `[logical(1)]`\cr
#'   See [deploy_folder()]. Defaults to `TRUE`.
#' @param full_deploy `[logical(1)]`\cr
#'   See [deploy_folder()]. Defaults to `FALSE`.
#' @param as_job `[logical(1)]`\cr
#'   If `TRUE` (default) and RStudio is available (checked via
#'   `rstudioapi::isAvailable()`), runs the full render + deploy pipeline as a
#'   single background job in RStudio's Background Jobs pane. All output
#'   (including errors) streams live to the Jobs pane console; when done, a
#'   summary appears in the global environment as `adhoc_last_publish` (a list
#'   with `ok`, `url`, and optionally `error`). If `FALSE` or RStudio is
#'   unavailable, runs synchronously in the current session. The local
#'   preview server ([preview_folder()]) is not launched in either mode —
#'   call it separately if you want a local preview.
#'
#' @return Invisibly returns the resulting URL (character string) when
#'   synchronous (`as_job = FALSE`) or RStudio unavailable. When
#'   `as_job = TRUE` with RStudio available, returns `NULL` immediately and
#'   populates `adhoc_last_publish` in the global environment when the job
#'   finishes.
#'
#' @seealso [render_folder()], [deploy_folder()], [preview_folder()]
#' @importFrom rlang env
#' @export
publish_folder <- function(
    path        = ".",
    index       = NULL,
    slug        = NULL,
    encrypt     = TRUE,
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE,
    as_job      = TRUE) {

  # If as_job = TRUE and RStudio is available, spin off a single background
  # job that runs both steps sequentially (rather than two separate jobs,
  # which would race: deploy_folder() needs render_folder()'s _site/ output).
  if (as_job && rstudioapi::isAvailable()) {
    job_script <- tempfile(fileext = ".R")
    script_content <- glue::glue(
      '# Auto-generated job script for publish_folder
       result <- tryCatch({{
         ofceweb:::render_folder_worker(
           path = "{path}", index = {if (is.null(index)) "NULL" else paste0("\\"", index, "\\"")}, slug = {if (is.null(slug)) "NULL" else paste0("\\"", slug, "\\"")},
           progress = {progress}, preview = FALSE
         )
         url <- ofceweb:::deploy_folder_worker(
           path = "{path}", slug = {if (is.null(slug)) "NULL" else paste0("\\"", slug, "\\"")},
           encrypt = {encrypt}, progress = {progress}, trigger = {trigger},
           full_deploy = {full_deploy}
         )
         list(ok = TRUE, url = url)
       }, error = function(e) {{
         message(conditionMessage(e))
         list(ok = FALSE, error = conditionMessage(e))
       }})
       adhoc_last_publish <- result',
      .open = "{", .close = "}"
    )

    writeLines(script_content, job_script)
    # Note: do NOT unlink(job_script) here — see the equivalent comment in
    # render_folder() above; the job reads the file asynchronously.

    repo_root <- find_git_root(path)
    rstudioapi::jobRunScript(
      path        = job_script,
      workingDir  = repo_root,
      importEnv   = TRUE,
      exportEnv   = "R_GlobalEnv"
    )

    cli::cli_alert_info(
      "Publication (rendu + d\u00e9ploiement) lanc\u00e9e en arri\u00e8re-plan (onglet {.emph Jobs}). \\
       \u00c0 la fin, {.code adhoc_last_publish} appara\u00eetra dans votre environnement."
    )
    return(invisible(NULL))
  }

  # Otherwise run both steps synchronously in the current session
  ofceweb:::render_folder_worker(
    path     = path,
    index    = index,
    slug     = slug,
    progress = progress,
    preview  = FALSE
  )

  url <- ofceweb:::deploy_folder_worker(
    path        = path,
    slug        = slug,
    encrypt     = encrypt,
    progress    = progress,
    trigger     = trigger,
    full_deploy = full_deploy
  )

  invisible(url)
}


#' RStudio addin: Render + deploy current folder as ad-hoc site
#'
#' Interactive wrapper for [publish_folder()] designed for use as an RStudio
#' addin. Detects the current project directory, prompts for optional index
#' and encryption preference, then renders and deploys as a single background
#' job.
#'
#' @return Invisibly returns `NULL`. Called for its side effect of launching a
#'   publish job.
#'
#' @keywords internal
#' @noRd
publish_folder_addin <- function() {
  # Get the current project root (RStudio's active project or current working dir)
  proj_dir <- tryCatch({
    if (rstudioapi::isAvailable()) {
      project_dir <- rstudioapi::getActiveProject()
      if (!is.null(project_dir)) project_dir else getwd()
    } else {
      getwd()
    }
  }, error = \(e) getwd())

  cli::cli_h1("Publier le dossier ad-hoc : {.path {fs::path_file(proj_dir)}}")

  # Optional: ask for index file
  index_choice <- rstudioapi::selectFile(
    caption  = "Choisir le fichier index (laisser vide pour auto-d\u00e9tection)",
    label    = "Index file",
    path     = proj_dir,
    filter   = "Quarto files (*.qmd *.md)"
  )

  index <- if (!is.null(index_choice) && nzchar(index_choice)) {
    fs::path_file(index_choice)
  } else {
    NULL
  }

  # Ask for encryption preference
  encrypt_choice <- rstudioapi::showDialog(
    title   = "Chiffrement staticrypt",
    message = "Publier avec chiffrement (si STATICRYPT_PASSWORD est configur\u00e9) ?"
  )

  encrypt <- !identical(encrypt_choice, "No")

  # Publish (render + deploy) with as_job = TRUE
  publish_folder(
    path        = proj_dir,
    index       = index,
    slug        = NULL,
    encrypt     = encrypt,
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE,
    as_job      = TRUE
  )

  invisible(NULL)
}


#' Preview a rendered ad-hoc folder site locally
#'
#' Launches a live preview server on the `_site/` folder via [servr::httw()],
#' allowing real-time browser refresh as files change. Works any time after
#' [render_folder()] has produced `_site/`, including mid-iteration
#' (re-running `render_folder()` while preview is active auto-reloads the
#' browser tab).
#'
#' @param path `[character(1)]`\cr
#'   Folder containing the `_site/` directory. Defaults to `"."`.
#'
#' @return Invisibly returns `NULL`. Starts a daemon server.
#'
#' @seealso [render_folder()], [preview_qmd()]
#' @importFrom fs path_expand path_abs path_norm path dir_exists
#' @importFrom cli cli_h1 cli_abort cli_alert_success
#' @importFrom servr httw
#' @export
preview_folder <- function(path = ".") {
  target <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  site_dir <- fs::path(target, "_site")
  if (!fs::dir_exists(site_dir))
    cli::cli_abort(
      "Dossier {.path _site} non trouvé dans {.path {target}}. \\
       Veuillez d'abord lancer {.code ofceweb::render_folder()}."
    )

  cli::cli_h1("Prévisualisation : {.path {fs::path_file(target)}}/_site/")

  # Stop any existing daemon server before starting a new one
  tryCatch(
    servr::daemon_stop(),
    error = function(e) NULL
  )

  cli::cli_alert_success("Serveur lancé sur http://127.0.0.1:8080/")

  servr::httw(
    dir    = as.character(site_dir),
    port   = 8080,
    daemon = TRUE
  )

  invisible(NULL)
}


#' Find the enclosing git repository root
#'
#' Walks up the directory tree from `start` looking for `.git/`.
#'
#' @param start `[character(1)]`\cr
#'   Starting directory (defaults to current working directory).
#'
#' @return Character path to the repository root, or errors if not found.
#'
#' @keywords internal
#' @noRd
find_git_root <- function(start = ".") {
  current <- start |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  while (current != "/" && current != dirname(current)) {
    if (fs::dir_exists(fs::path(current, ".git"))) {
      return(current)
    }
    current <- dirname(current)
  }

  cli::cli_abort(
    "Pas de dépôt Git trouvé en remontant depuis {.path {start}}."
  )
}


#' Compute a deterministic slug for a folder path
#'
#' Generates a stable, URL-safe identifier for an arbitrary folder within a repo.
#' Slugification: lowercase the relative path, replace non-alphanumeric sequences
#' with `-`, trim leading/trailing dashes, truncate to 40 characters, then append
#' a 6-character CRC32 hash of the original path to avoid collisions.
#'
#' @param rel_path `[character(1)]`\cr
#'   Relative path (from repo root) to the folder.
#'
#' @return A character string slug (e.g., `"notes-slides-abc123"`).
#'
#' @keywords internal
#' @noRd
adhoc_slug <- function(rel_path) {
  base <- rel_path |>
    tolower() |>
    stringr::str_replace_all("[^a-z0-9]+", "-") |>
    stringr::str_replace_all("^-|-$", "") |>
    substr(1, 40)

  hash <- digest::digest(rel_path, algo = "crc32") |>
    substr(1, 6)

  glue::glue("{base}-{hash}")
}


#' Inject OFCE quick-publish banner into HTML files
#'
#' Post-processes all `*.html` files in a directory tree, injecting a small
#' fixed banner right after the opening `<body...>` tag (or at the start of
#' the file if no body tag exists). Banner announces the page as an OFCE
#' quick-publish, unindexed page.
#'
#' @param site_dir `[character(1)]`\cr
#'   Root directory to search for `*.html` files (recursive).
#'
#' @keywords internal
#' @noRd
inject_quick_publish_banner <- function(site_dir) {
  # The <span class="ofce-push-ts"> placeholder is left empty here (render
  # time) and filled in later by stamp_banner_push_time(), called right
  # before the git push in deploy_folder_worker() — so the banner reflects
  # when the site was actually pushed, not when it was rendered.
  banner_html <- paste(
    '<div style="position:fixed;top:0;left:0;right:0;z-index:9999;',
    'background:#e6142d;color:#fff;font:13px sans-serif;',
    'padding:4px 10px;text-align:center;">',
    'OFCE — publication rapide — page non indexée',
    '<span class="ofce-push-ts"></span>',
    '</div>',
    sep = ""
  )

  html_files <- fs::dir_ls(
    site_dir,
    type    = "file",
    regexp  = "\\.html$",
    recurse = TRUE,
    all     = TRUE
  )

  for (html_file in html_files) {
    content <- readLines(html_file, warn = FALSE)
    content_str <- paste(content, collapse = "\n")

    # Try to inject after <body...> tag
    if (grepl("<body[^>]*>", content_str, ignore.case = TRUE)) {
      content_str <- sub(
        "(<body[^>]*>)",
        paste0("\\1\n", banner_html, "\n"),
        content_str,
        ignore.case = TRUE
      )
    } else {
      # Fallback: inject at the beginning
      content_str <- paste0(banner_html, "\n", content_str)
    }

    writeLines(content_str, html_file)
  }
}

#' Stamp the OFCE quick-publish banner with the push date/time
#'
#' Fills in the `<span class="ofce-push-ts">` placeholder left by
#' [inject_quick_publish_banner()] in every `*.html` file under `site_dir`,
#' with the current date/time in the `Europe/Paris` timezone. Called from
#' [deploy_folder_worker()] right before the git push, so the banner reflects
#' when the site was actually deployed rather than when it was rendered.
#' Idempotent: re-running it (e.g. on a redeploy) overwrites the previous
#' timestamp instead of appending to it. HTML files without the placeholder
#' (e.g. produced by an older `ofceweb` version) are left untouched.
#'
#' @param site_dir `[character(1)]`\cr
#'   Root directory to search for `*.html` files (recursive).
#'
#' @keywords internal
#' @noRd
stamp_banner_push_time <- function(site_dir) {
  pushed_at <- format(Sys.time(), "%d/%m/%Y %H:%M", tz = "Europe/Paris")
  label     <- glue::glue(" \u2014 publi\u00e9 le {pushed_at} (heure de Paris)")

  html_files <- fs::dir_ls(
    site_dir,
    type    = "file",
    regexp  = "\\.html$",
    recurse = TRUE,
    all     = TRUE
  )

  for (html_file in html_files) {
    content <- readLines(html_file, warn = FALSE)
    content_str <- paste(content, collapse = "\n")

    if (!grepl('class="ofce-push-ts"', content_str, fixed = TRUE))
      next

    content_str <- sub(
      '(<span class="ofce-push-ts">)[^<]*(</span>)',
      paste0("\\1", label, "\\2"),
      content_str
    )

    writeLines(content_str, html_file)
  }
}


#' Ensure ftp_deploy_profile.yml workflow exists (auto-install if missing)
#'
#' Checks whether `.github/workflows/ftp_deploy_profile.yml` exists on the
#' repository's default branch. If missing, attempts to install it from the
#' package:
#'
#' - On unprotected default branches, commits directly.
#' - On protected default branches, opens a PR for manual merge.
#'
#' This is idempotent — subsequent calls see the file present and skip it.
#'
#' @param repo_root `[character(1)]`\cr
#'   Path to the repository root.
#' @param progress `[logical(1)]`\cr
#'   If `TRUE`, report progress to console.
#'
#' @keywords internal
#' @noRd
ensure_adhoc_workflow <- function(repo_root, progress = TRUE) {
  # Get owner/repo
  remotes <- gert::git_remote_list(repo = repo_root)
  origin_url <- remotes$url[remotes$name == "origin"]
  if (length(origin_url) == 0)
    cli::cli_abort("Pas de remote 'origin' trouvé.")

  slug  <- origin_url |>
    sub(pattern = "\\.git$", replacement = "") |>
    sub(pattern = "^git@[^:]+:", replacement = "") |>
    sub(pattern = "^https://[^/]+/", replacement = "")
  parts <- strsplit(slug, "/")[[1]]
  owner <- parts[1]; repo <- parts[2]

  # Get default branch
  remotes_list <- gert::git_remote_list(repo = repo_root)
  default_branch <- tryCatch({
    repo_url <- sprintf("https://api.github.com/repos/%s/%s", owner, repo)
    pat <- Sys.getenv("DEPLOY_PAT", "")
    if (!nchar(pat))
      pat <- tryCatch(gitcreds::gitcreds_get("https://github.com")$password, error = \(e) "")

    req <- httr2::request(repo_url) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      )
    if (nchar(pat))
      req <- req |> httr2::req_auth_bearer_token(pat)

    resp <- req |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(resp) == 200) {
      httr2::resp_body_json(resp)$default_branch
    } else {
      "main"
    }
  }, error = \(e) "main")

  if (progress)
    cli::cli_h2("Vérification du workflow {.path ftp_deploy_profile.yml}")

  # Check if workflow exists on default branch
  workflow_path <- ".github/workflows/ftp_deploy_profile.yml"
  workflow_exists <- tryCatch({
    pat <- Sys.getenv("DEPLOY_PAT", "")
    if (!nchar(pat))
      pat <- tryCatch(gitcreds::gitcreds_get("https://github.com")$password, error = \(e) "")

    contents_url <- sprintf(
      "https://api.github.com/repos/%s/%s/contents/%s",
      owner, repo, workflow_path
    )
    req <- httr2::request(contents_url) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      )
    if (nchar(pat))
      req <- req |> httr2::req_auth_bearer_token(pat)

    resp <- req |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    httr2::resp_status(resp) == 200
  }, error = \(e) FALSE)

  # Read workflow from package (needed whether workflow exists or not, to compare)
  pkg_workflow_path <- system.file(
    "setup_prev", "workflows", "ftp_deploy_profile.yml",
    package = "ofceweb"
  )
  if (!nzchar(pkg_workflow_path))
    cli::cli_abort("Impossible de localiser {.path ftp_deploy_profile.yml} dans le paquet.")

  pkg_workflow_content <- readLines(pkg_workflow_path)

  # If workflow exists, check if it needs updating
  if (workflow_exists) {
    # Fetch current workflow from GitHub to compare
    pat <- Sys.getenv("DEPLOY_PAT", "")
    if (!nchar(pat))
      pat <- tryCatch(gitcreds::gitcreds_get("https://github.com")$password, error = \(e) "")

    contents_url <- sprintf(
      "https://api.github.com/repos/%s/%s/contents/%s",
      owner, repo, workflow_path
    )
    req <- httr2::request(contents_url) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      )
    if (nchar(pat))
      req <- req |> httr2::req_auth_bearer_token(pat)

    current_resp <- req |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    needs_update <- TRUE
    if (httr2::resp_status(current_resp) == 200) {
      # Decode base64 content from GitHub
      github_data <- httr2::resp_body_json(current_resp)
      current_content_b64 <- github_data$content
      current_content_decoded <- rawToChar(openssl::base64_decode(current_content_b64))
      current_lines <- strsplit(current_content_decoded, "\n")[[1]]

      # Compare content (trim trailing empty lines for comparison)
      pkg_trimmed <- trimws(paste(pkg_workflow_content, collapse = "\n"))
      current_trimmed <- trimws(paste(current_lines, collapse = "\n"))

      if (identical(pkg_trimmed, current_trimmed)) {
        needs_update <- FALSE
      }
    }

    if (!needs_update) {
      if (progress)
        cli::cli_alert_info("Workflow déjà installé et à jour.")
      return(invisible(NULL))
    }

    if (progress)
      cli::cli_alert_info("Workflow détecté, mais version obsolète — mise à jour en cours...")
  } else {
    # Attempt to install
    if (progress)
      cli::cli_alert_info("Workflow manquant — installation en cours...")
  }

  workflow_content <- pkg_workflow_content

  # Try direct commit+push to default branch
  pat <- Sys.getenv("DEPLOY_PAT", "")
  if (!nchar(pat))
    pat <- tryCatch(gitcreds::gitcreds_get("https://github.com")$password, error = \(e) "")

  if (!nchar(pat))
    cli::cli_abort(
      "Aucun token GitHub trouvé pour installer le workflow. \\
       Définissez {.envvar DEPLOY_PAT}."
    )

  # Prepare the file content (base64 for GitHub API)
  file_content_b64 <- openssl::base64_encode(paste(workflow_content, collapse = "\n"))

  # If updating an existing file, fetch its SHA for the API request
  sha_for_update <- NULL
  if (workflow_exists) {
    contents_url <- sprintf(
      "https://api.github.com/repos/%s/%s/contents/%s",
      owner, repo, workflow_path
    )
    req <- httr2::request(contents_url) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      )
    if (nchar(pat))
      req <- req |> httr2::req_auth_bearer_token(pat)

    resp <- req |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(resp) == 200) {
      sha_for_update <- httr2::resp_body_json(resp)$sha
    }
  }

  direct_attempt <- tryCatch({
    create_url <- sprintf(
      "https://api.github.com/repos/%s/%s/contents/%s",
      owner, repo, workflow_path
    )

    body <- list(
      message = if (workflow_exists) "Update ftp_deploy_profile.yml workflow" else "Add ftp_deploy_profile.yml workflow (auto-installed)",
      content = file_content_b64,
      branch  = default_branch
    )
    if (!is.null(sha_for_update))
      body$sha <- sha_for_update

    resp <- httr2::request(create_url) |>
      httr2::req_method("PUT") |>
      httr2::req_auth_bearer_token(pat) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      ) |>
      httr2::req_body_json(body) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    list(status = httr2::resp_status(resp), body = httr2::resp_body_json(resp))
  }, error = \(e) list(status = 500, error = conditionMessage(e)))

  if (direct_attempt$status %in% c(201, 200)) {
    success_msg <- if (workflow_exists) "Workflow mis à jour sur la branche par défaut." else "Workflow installé sur la branche par défaut."
    if (progress)
      cli::cli_alert_success(success_msg)
    return(invisible(NULL))
  }

  # Direct push failed — try PR fallback
  if (progress)
    cli::cli_alert_warning(
      "Push direct échoué (protection de branche détectée). \\
       Ouverture d'une PR..."
    )

  # Create a side branch
  side_branch <- "add-ftp-deploy-profile-workflow"
  tryCatch({
    # Get the SHA of the default branch
    repo_url <- sprintf(
      "https://api.github.com/repos/%s/%s",
      owner, repo
    )
    repo_resp <- httr2::request(repo_url) |>
      httr2::req_auth_bearer_token(pat) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      ) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(repo_resp) != 200)
      stop("Impossible d'accéder aux infos du dépôt.")

    repo_data <- httr2::resp_body_json(repo_resp)
    default_sha <- {
      refs_url <- sprintf(
        "https://api.github.com/repos/%s/%s/git/refs/heads/%s",
        owner, repo, default_branch
      )
      ref_resp <- httr2::request(refs_url) |>
        httr2::req_auth_bearer_token(pat) |>
        httr2::req_headers(
          "Accept"               = "application/vnd.github+json",
          "X-GitHub-Api-Version" = "2022-11-28"
        ) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform()
      if (httr2::resp_status(ref_resp) == 200) {
        httr2::resp_body_json(ref_resp)$object$sha
      } else {
        NA_character_
      }
    }

    if (is.na(default_sha))
      stop("Impossible de déterminer la SHA de la branche par défaut.")

    # Create side branch
    create_ref_body <- list(ref = glue::glue("refs/heads/{side_branch}"), sha = default_sha)
    refs_create <- httr2::request(
      sprintf("https://api.github.com/repos/%s/%s/git/refs", owner, repo)
    ) |>
      httr2::req_auth_bearer_token(pat) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      ) |>
      httr2::req_body_json(create_ref_body) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    # 201 = branch created; 422 = branch already exists (e.g. leftover from a
    # previous attempt) — both are fine, we just commit onto whatever the
    # branch currently points to. Anything else is a real failure.
    if (!httr2::resp_status(refs_create) %in% c(201, 422)) {
      stop(sprintf(
        "Impossible de créer la branche '%s' (HTTP %d) : %s",
        side_branch,
        httr2::resp_status(refs_create),
        tryCatch(httr2::resp_body_json(refs_create)$message, error = \(e) "réponse illisible")
      ))
    }

    # Commit the workflow file to the side branch
    file_body <- list(
      message = "Add ftp_deploy_profile.yml workflow",
      content = file_content_b64,
      branch  = side_branch
    )
    file_resp <- httr2::request(
      sprintf(
        "https://api.github.com/repos/%s/%s/contents/%s",
        owner, repo, workflow_path
      )
    ) |>
      httr2::req_method("PUT") |>
      httr2::req_auth_bearer_token(pat) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      ) |>
      httr2::req_body_json(file_body) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    if (!httr2::resp_status(file_resp) %in% c(200, 201)) {
      stop(sprintf(
        "Impossible d'ajouter %s sur la branche '%s' (HTTP %d) : %s",
        workflow_path,
        side_branch,
        httr2::resp_status(file_resp),
        tryCatch(httr2::resp_body_json(file_resp)$message, error = \(e) "réponse illisible")
      ))
    }

    # Open a PR
    pr_body <- list(
      title = "Add ftp_deploy_profile.yml workflow for ad-hoc site publishing",
      body  = "Auto-generated PR to install the FTP deployment workflow. \\
               Please merge to enable `render_folder()`/`deploy_folder()` functionality.",
      head  = side_branch,
      base  = default_branch
    )

    pr_resp <- httr2::request(
      sprintf("https://api.github.com/repos/%s/%s/pulls", owner, repo)
    ) |>
      httr2::req_auth_bearer_token(pat) |>
      httr2::req_headers(
        "Accept"               = "application/vnd.github+json",
        "X-GitHub-Api-Version" = "2022-11-28"
      ) |>
      httr2::req_body_json(pr_body) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(pr_resp) == 201) {
      pr_data <- httr2::resp_body_json(pr_resp)
      pr_url <- pr_data$html_url
      if (progress) {
        cli::cli_alert_warning(
          "PR ouverte : {.url {pr_url}}"
        )
        cli::cli_alert_warning(
          "Veuillez la fusionner avant de relancer {.code deploy_folder()}."
        )
      }
      return(invisible(NULL))
    } else {
      stop("Impossible d'ouvrir la PR.")
    }
  }, error = \(e) {
    cli::cli_warn(
      "Échec de l'installation du workflow : {conditionMessage(e)}"
    )
    return(invisible(NULL))
  })
}


#' RStudio addin: Render current folder as ad-hoc site
#'
#' Interactive wrapper for [render_folder()] designed for use as an RStudio addin.
#' Detects the current project directory, prompts for optional index and slug
#' parameters, then renders as a background job.
#'
#' @return Invisibly returns `NULL`. Called for its side effect of launching a render job.
#'
#' @keywords internal
#' @noRd
render_folder_addin <- function() {
  # Get the current project root (RStudio's active project or current working dir)
  proj_dir <- tryCatch({
    if (rstudioapi::isAvailable()) {
      project_dir <- rstudioapi::getActiveProject()
      if (!is.null(project_dir)) project_dir else getwd()
    } else {
      getwd()
    }
  }, error = \(e) getwd())

  cli::cli_h1("Rendre le dossier ad-hoc : {.path {fs::path_file(proj_dir)}}")

  # Optional: ask for index and slug
  index_choice <- rstudioapi::selectFile(
    caption  = "Choisir le fichier index (laisser vide pour auto-détection)",
    label    = "Index file",
    path     = proj_dir,
    filter   = "Quarto files (*.qmd *.md)"
  )

  index <- if (!is.null(index_choice) && nzchar(index_choice)) {
    fs::path_file(index_choice)
  } else {
    NULL
  }

  # Render with as_job = TRUE (forces background execution)
  render_folder(
    path     = proj_dir,
    index    = index,
    slug     = NULL,
    progress = TRUE,
    preview  = TRUE,
    as_job   = TRUE
  )

  invisible(NULL)
}


#' RStudio addin: Deploy current folder's ad-hoc site
#'
#' Interactive wrapper for [deploy_folder()] designed for use as an RStudio addin.
#' Detects the current project directory, prompts for optional slug override and
#' encryption preference, then deploys as a background job.
#'
#' @return Invisibly returns `NULL`. Called for its side effect of launching a deploy job.
#'
#' @keywords internal
#' @noRd
deploy_folder_addin <- function() {
  # Get the current project root
  proj_dir <- tryCatch({
    if (rstudioapi::isAvailable()) {
      project_dir <- rstudioapi::getActiveProject()
      if (!is.null(project_dir)) project_dir else getwd()
    } else {
      getwd()
    }
  }, error = \(e) getwd())

  cli::cli_h1("Déployer le dossier ad-hoc : {.path {fs::path_file(proj_dir)}}")

  # Check if _site exists
  site_dir <- fs::path(proj_dir, "_site")
  if (!fs::dir_exists(site_dir)) {
    cli::cli_abort(
      "Dossier {.path _site} non trouvé. Lancez d'abord {.code render_folder()}."
    )
  }

  # Ask for encryption preference
  encrypt_choice <- rstudioapi::showDialog(
    title   = "Chiffrement staticrypt",
    message = "Publier avec chiffrement (si STATICRYPT_PASSWORD est configuré) ?"
  )

  encrypt <- !identical(encrypt_choice, "No")

  # Deploy with as_job = TRUE
  deploy_folder(
    path        = proj_dir,
    slug        = NULL,
    encrypt     = encrypt,
    progress    = TRUE,
    trigger     = TRUE,
    full_deploy = FALSE,
    as_job      = TRUE
  )

  invisible(NULL)
}
