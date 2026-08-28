#' Demande d'enregistrement d'un WP dans le registre central
#'
#' Calcule le triplet `{annee, wp, source-repo}` pour le dépôt WP local et
#' ouvre une pull request contre `ofceweb/wp-registry` proposant d'ajouter
#' l'entrée correspondante à `wp/{annee}.json` (et, si c'est la première
#' demande pour cette année, crée ce fichier et met à jour `wp/index.json`
#' dans le même commit). N'attend pas la fusion (fire-and-forget) — un·e
#' admin doit approuver manuellement. Relancer [setup_wp()] une fois la PR
#' fusionnée : c'est `setup_wp()` (pas `render_wp()`, qui ne consulte plus
#' le registre) qui synchronise `wp`/`annee`/`draft` et recalcule
#' `site-path`/`citation.*` depuis l'entrée confirmée, pour basculer du
#' mode staging au mode publication.
#'
#' @param path Chemin vers la racine du dépôt WP local. Défaut `"."`.
#' @param annee Entier. Année du WP. Défaut : `annee` dans `_quarto.yml`
#'   si présent, sinon l'année courante.
#' @param wp Entier ou `NULL`. Numéro de WP souhaité. Si `NULL` (défaut),
#'   calculé automatiquement comme `max(wp existants pour cette annee) + 1`
#'   d'après `wp/{annee}.json` au moment de l'appel (tous types confondus ;
#'   `1` si le fichier n'existe pas encore). Si fourni explicitement, la
#'   fonction vérifie l'absence de collision avant d'ouvrir la PR et échoue
#'   localement en cas de conflit.
#' @param contact Adresse de contact de l'auteur·e. Défaut : valeur de
#'   `git config user.email` pour ce dépôt (config locale avec repli sur la
#'   globale). La fonction échoue si aucune valeur ne peut être résolue.
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#'   Défaut `"ofceweb/wp-registry"`.
#' @param dry_run Si `TRUE`, calcule et affiche l'entrée proposée sans ouvrir
#'   de pull request. Défaut `FALSE`.
#'
#' @returns Invisiblement, une liste avec `entry` (l'entrée proposée) et
#'   `pr_url` (URL de la PR ouverte, `NULL` en mode `dry_run`).
#' @seealso [setup_wp()], [render_wp()], [deploy_wp()]
#' @importFrom fs path_expand path_abs path_norm path dir_delete path_file
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_alert_success cli_alert_warning cli_alert_info cli_text cli_verbatim
#' @importFrom yaml read_yaml
#' @importFrom jsonlite fromJSON toJSON read_json
#' @importFrom gert git_clone git_branch_create git_add git_commit git_signature
#' @importFrom httr2 request req_url_path req_auth_bearer_token req_headers req_body_json req_perform resp_status resp_body_json
#' @export
wp_registry_request <- function(
    path          = ".",
    annee         = NULL,
    wp            = NULL,
    contact       = NULL,
    registry_repo = "ofceweb/wp-registry",
    dry_run       = FALSE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  cli::cli_h1("wp_registry_request : {fs::path_file(root)}")

  # ---- 1. Organisation ofce requise ----------------------------------------
  source_repo <- tryCatch(gh_slug_from_remote(root), error = function(e) NA_character_)
  if (is.na(source_repo))
    cli::cli_abort(c(
      "Impossible de r\u00e9soudre le remote origin.",
      "i" = "V\u00e9rifier que le d\u00e9p\u00f4t a un remote {.val origin} configur\u00e9."
    ))

  repo_owner <- strsplit(source_repo, "/", fixed = TRUE)[[1L]][[1L]]
  if (!identical(tolower(repo_owner), "ofce"))
    cli::cli_abort(c(
      "Ce d\u00e9p\u00f4t est sous {.strong {repo_owner}}, pas sous {.strong ofce}.",
      "i" = "Transf\u00e9rer via GitHub \u2192 Settings \u2192 Danger Zone \u2192 Transfer repository \u2192 ofce.",
      "x" = "{.fn wp_registry_request} ne peut pas ouvrir une PR depuis un d\u00e9p\u00f4t hors de l'organisation {.strong ofce}."
    ))

  # ---- 2. Lecture _quarto.yml (annee) --------------------------------------
  yml <- tryCatch(
    yaml::read_yaml(fs::path(root, "_quarto.yml")),
    error = function(e) list()
  )
  if (is.null(annee))
    annee <- yml$annee %||% as.integer(format(Sys.Date(), "%Y"))
  annee <- suppressWarnings(as.integer(annee))
  if (is.na(annee))
    cli::cli_abort("{.arg annee} doit \u00eatre un entier.")

  # ---- 3. Lecture du fichier annuel du registre (non authentifi\u00e9) ---------
  year_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/wp/%d.json", registry_repo, annee)
  cli::cli_alert_info("Lecture du registre : {.url {year_url}}")
  new_year <- FALSE
  entries <- fetch_wp_year(annee, registry_repo)
  if (is.null(entries)) {
    new_year <- TRUE
    entries  <- list()
    cli::cli_alert_info(
      "Aucun fichier {.file wp/{annee}.json} existant \u2014 ce sera la premi\u00e8re \\
       entr\u00e9e enregistr\u00e9e pour {.val {annee}}.")
  }

  # ---- 4. R\u00e9solution du num\u00e9ro WP ----------------------------------------
  # `entries` provient d\u00e9j\u00e0 de wp/{annee}.json (une seule ann\u00e9e), mais on
  # filtre \u00e0 nouveau par `annee` par prudence (d\u00e9fensif si le champ ne
  # correspondait pas au nom de fichier).
  annee_entries <- Filter(function(e) identical(as.integer(e$annee), annee), entries)
  if (is.null(wp)) {
    # Auto-num\u00e9rotation : max(wp pour cette ann\u00e9e, tous types) + 1
    annee_wps <- vapply(
      annee_entries,
      function(e) suppressWarnings(as.integer(e$wp %||% 0L)),
      integer(1L)
    )
    wp <- if (length(annee_wps) == 0L) 1L else max(annee_wps, na.rm = TRUE) + 1L
    cli::cli_alert_info(
      "Num\u00e9ro WP attribu\u00e9 automatiquement : {.val {annee}/{wp}}")
  } else {
    wp <- suppressWarnings(as.integer(wp))
    if (is.na(wp))
      cli::cli_abort("{.arg wp} doit \u00eatre un entier ou NULL.")
    # V\u00e9rification collision
    collision <- Filter(
      function(e) identical(as.integer(e$wp), wp),
      annee_entries
    )
    if (length(collision) > 0L)
      cli::cli_abort(c(
        "Le num\u00e9ro WP {.val {annee}/{wp}} est d\u00e9j\u00e0 enregistr\u00e9.",
        "i" = "source-repo existant : {.val {collision[[1L]][[\"source-repo\"]]}}"
      ))
  }

  # ---- 5. Contact (git config user.email) ----------------------------------
  if (is.null(contact)) {
    contact <- tryCatch(
      gert::git_config_get("user.email", repo = root),
      error = function(e) NULL
    )
    if (is.null(contact) || !nzchar(trimws(contact)))
      cli::cli_abort(c(
        "Impossible de r\u00e9soudre le contact depuis {.code git config user.email}.",
        "i" = "Fournir explicitement : {.code wp_registry_request(contact = \"prenom.nom@ofce.sciences-po.fr\")}"
      ))
  }

  # ---- 6. Token GitHub + login ---------------------------------------------
  token <- .registry_gh_token()

  registered_by <- tryCatch({
    resp <- httr2::request("https://api.github.com/user") |>
      httr2::req_auth_bearer_token(token) |>
      httr2::req_headers(
        Accept                 = "application/vnd.github+json",
        `X-GitHub-Api-Version` = "2022-11-28"
      ) |>
      httr2::req_perform()
    httr2::resp_body_json(resp)$login
  }, error = function(e) {
    cli::cli_alert_warning("Login GitHub non r\u00e9solu : {conditionMessage(e)}")
    NA_character_
  })

  # ---- 7. Construction de l'entr\u00e9e -----------------------------------------
  new_entry <- list(
    annee           = annee,
    wp              = wp,
    type            = "repo",
    `source-repo`   = source_repo,
    contact         = contact,
    `registered-by` = if (!is.na(registered_by)) registered_by else NULL,
    `registered-at` = format(Sys.Date(), "%Y-%m-%d")
  )

  cli::cli_h2("Entr\u00e9e propos\u00e9e")
  # cli_verbatim() (pas cli_text()) : le JSON pretty-printed contient des
  # accolades litt\u00e9rales que cli_text() tenterait d'interpr\u00e9ter comme des
  # expressions glue.
  cli::cli_verbatim(
    jsonlite::toJSON(new_entry, auto_unbox = TRUE, pretty = TRUE, null = "null"))

  if (dry_run) {
    cli::cli_alert_info("Mode {.code dry_run} : aucune PR ouverte.")
    return(invisible(list(entry = new_entry, pr_url = NULL)))
  }

  # ---- 8. Clonage du registre dans un dossier temporaire ------------------
  tmp <- fs::path(tempdir(),
                  paste0("wp-registry-", format(Sys.time(), "%Y%m%d%H%M%S")))
  on.exit(try(fs::dir_delete(tmp), silent = TRUE), add = TRUE)

  registry_https <- sprintf("https://github.com/%s.git", registry_repo)
  cli::cli_alert_info("Clonage de {.val {registry_repo}}...")
  gert::git_clone(url = registry_https, path = tmp, verbose = FALSE)

  # ---- 9. Modification de wp/{annee}.json et wp/index.json -----------------
  wp_dir <- fs::path(tmp, "wp")
  fs::dir_create(wp_dir, recurse = TRUE)

  year_path <- fs::path(wp_dir, sprintf("%d.json", annee))
  current_year_reg <- if (fs::file_exists(year_path))
    jsonlite::read_json(year_path)
  else
    list(wp = list())
  current_year_reg$wp <- c(current_year_reg$wp %||% list(), list(new_entry))
  writeLines(
    jsonlite::toJSON(current_year_reg, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    year_path
  )

  # wp/index.json doit rester coh\u00e9rent : ajouter l'ann\u00e9e si absente. Toujours
  # r\u00e9\u00e9crire le fichier (idempotent) pour simplifier le code, m\u00eame si le
  # contenu ne change pas.
  index_path <- fs::path(wp_dir, "index.json")
  current_index <- if (fs::file_exists(index_path))
    jsonlite::read_json(index_path)
  else
    list(years = list())
  index_years <- sort(unique(c(vapply(current_index$years %||% list(), as.integer, integer(1L)), annee)))
  current_index$years <- as.list(as.integer(index_years))
  writeLines(
    jsonlite::toJSON(current_index, auto_unbox = TRUE, pretty = TRUE),
    index_path
  )

  # ---- 10. Branche, commit, push -------------------------------------------
  branch_name <- sprintf("request/%d/%d", annee, wp)
  gert::git_branch_create(branch = branch_name, repo = tmp, checkout = TRUE)
  gert::git_add(c(sprintf("wp/%d.json", annee), "wp/index.json"), repo = tmp)
  gert::git_commit(
    message = sprintf("request: %d/%d \u2014 %s", annee, wp, source_repo),
    repo    = tmp,
    author  = gert::git_signature(
      name  = registered_by %||% source_repo,
      email = contact
    )
  )

  push_url <- sub("https://",
                  sprintf("https://x-access-token:%s@", token),
                  registry_https)
  push_ret <- system2(
    "git",
    c("-C", shQuote(tmp),
      "-c", "credential.helper=",
      "push", push_url,
      sprintf("HEAD:refs/heads/%s", branch_name)),
    stdout = FALSE, stderr = FALSE
  )
  if (!identical(push_ret, 0L))
    cli::cli_abort(
      "git push a \u00e9chou\u00e9 (code {push_ret}). \\
       V\u00e9rifier que le token a les droits {.code repo} sur {.val {registry_repo}}.")

  # ---- 11. Ouverture de la PR ----------------------------------------------
  pr_title <- sprintf(
    "Enregistrement WP %d/%d \u2014 %s", annee, wp, source_repo)
  pr_body <- paste0(
    "## Demande d\u2019enregistrement WP\n\n",
    "| Champ | Valeur |\n|---|---|\n",
    sprintf("| `annee` | %d |\n", annee),
    sprintf("| `wp` | %d |\n", wp),
    sprintf("| `type` | repo |\n"),
    sprintf("| `source-repo` | `%s` |\n", source_repo),
    sprintf("| `contact` | %s |\n", contact),
    sprintf("| `registered-by` | %s |\n",
            if (!is.na(registered_by)) registered_by else "_(non r\u00e9solu)_"),
    if (new_year) sprintf(
      "\n_Premi\u00e8re demande pour %d : cr\u00e9e `wp/%d.json` et met \u00e0 jour `wp/index.json`._\n",
      annee, annee) else "",
    "\n_Ouvert automatiquement par `ofceweb::wp_registry_request()`._"
  )

  pr_resp <- httr2::request("https://api.github.com") |>
    httr2::req_url_path(sprintf("/repos/%s/pulls", registry_repo)) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_headers(
      Accept                 = "application/vnd.github+json",
      `X-GitHub-Api-Version` = "2022-11-28"
    ) |>
    httr2::req_body_json(list(
      title = pr_title,
      head  = branch_name,
      base  = "main",
      body  = pr_body
    )) |>
    httr2::req_perform()

  if (httr2::resp_status(pr_resp) != 201L) {
    body_msg <- tryCatch(httr2::resp_body_json(pr_resp)$message, error = \(e) "?")
    cli::cli_abort(
      "Impossible d\u2019ouvrir la PR (HTTP {httr2::resp_status(pr_resp)}) : {body_msg}")
  }

  pr_url <- httr2::resp_body_json(pr_resp)$html_url
  cli::cli_alert_success("PR ouverte : {.url {pr_url}}")
  cli::cli_text(
    "Un\u00b7e admin doit approuver et fusionner la PR avant que le d\u00e9p\u00f4t \\
     puisse publier sur le chemin num\u00e9rot\u00e9.")
  cli::cli_text(
    "Relancer {.run ofceweb::setup_wp()} une fois la PR fusionn\u00e9e \
     (pas {.fn render_wp}, qui ne consulte plus le registre) pour \
     synchroniser {.code wp}/{.code annee}/{.code draft} et recalculer \
     {.field site-path}/{.field citation.*}.")

  invisible(list(entry = new_entry, pr_url = pr_url))
}

# Résout le token GitHub : DEPLOY_PAT env var, puis gitcreds.
# Reproduit la même logique que set_gh_var() pour la cohérence.
.registry_gh_token <- function() {
  token <- Sys.getenv("DEPLOY_PAT", "")
  if (!nchar(token))
    token <- tryCatch(
      gitcreds::gitcreds_get("https://github.com")$password,
      error = function(e) ""
    )
  if (!nchar(token))
    cli::cli_abort(c(
      "Pas de token GitHub disponible.",
      "i" = "D\u00e9finir {.envvar DEPLOY_PAT} ou se connecter avec \\
             {.run usethis::create_github_token()}."
    ))
  token
}
