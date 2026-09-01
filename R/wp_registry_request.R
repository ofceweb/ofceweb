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
#' @details
#' # Flux via fork
#'
#' L'ouverture de la PR passe par un **fork personnel** de
#' `ofceweb/wp-registry`, créé (ou réutilisé s'il existe déjà) sous le
#' compte GitHub associé au token utilisé — jamais par un push direct sur
#' `ofceweb/wp-registry` lui-même :
#'
#' 1.  Résolution du login GitHub (`GET /user`) associé au token
#'     (`DEPLOY_PAT` ou identifiants `gitcreds`).
#' 2.  Vérification de l'existence d'un fork sous ce login
#'     (`GET /repos/{login}/wp-registry`) ; sinon, création
#'     (`POST /repos/ofceweb/wp-registry/forks`) et attente (jusqu'à
#'     20 s) que GitHub le rende clonable.
#' 3.  Clonage du fork, resynchronisation avec `upstream/main` (le fork
#'     peut avoir pris du retard depuis sa création), puis création de la
#'     branche `request/{annee}/{wp}` avec l'entrée proposée.
#' 4.  Push de cette branche vers le fork (pas vers `ofceweb/wp-registry`).
#' 5.  Ouverture d'une pull request **cross-repo** (`head =
#'     "{login}:{branche}"`) contre `ofceweb/wp-registry`.
#'
#' Ce choix est déterminé par le modèle de gouvernance du registre (voir
#' la note d'équipe `note-equipe-publication-wp.md`) : seule la
#' **fusion** d'une PR dans `wp-registry` doit être protégée
#' (branch protection + `CODEOWNERS` côté GitHub), pas l'ouverture d'une
#' PR — n'importe quel·le auteur·e de l'organisation `ofce` doit pouvoir
#' demander un numéro sans être collaborateur·rice avec droit d'écriture
#' sur `wp-registry`. Un push direct exigerait ce droit d'écriture pour
#' chaque auteur·e, ce qui n'est ni souhaitable (élargit inutilement les
#' droits d'accès à l'infrastructure du registre) ni cohérent avec ce
#' modèle. Le fork suit le flux standard de contribution externe sur
#' GitHub : n'importe quel compte authentifié peut forker un dépôt
#' public, sans droit d'écriture préalable sur celui-ci.
#'
#' Conséquence pratique : le token utilisé (`DEPLOY_PAT` ou identifiants
#' `gitcreds`) doit au minimum permettre de résoudre `GET /user` et de
#' forker un dépôt public — ce que n'importe quel PAT `repo`/`public_repo`
#' d'un compte authentifié satisfait, sans configuration particulière côté
#' `ofceweb/wp-registry`.
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
#' @importFrom gert git_clone git_branch_create git_add git_commit git_signature git_remote_add git_fetch git_reset_hard
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
  # Reste tol\u00e9rant ici (avertissement + NA) : ce login n'est qu'informatif
  # pour l'entr\u00e9e propos\u00e9e et le mode `dry_run`, qui ne doivent pas exiger
  # de r\u00e9seau fonctionnel. Il devient obligatoire plus loin (\u00e9tape 8), une
  # fois qu'on sait qu'on va r\u00e9ellement pousser sur un fork sous ce login.
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

  # ---- 8. Fork sous le compte de l'appelant --------------------------------
  # Pousser directement sur `registry_repo` exigerait que chaque auteur·e
  # soit collaborateur·rice avec droit d'\u00e9criture sur `wp-registry` — ce
  # qui contredit le mod\u00e8le documente (seule la fusion doit \u00eatre prot\u00e9g\u00e9e,
  # pas l'ouverture de PR). On passe donc par un fork personnel, standard
  # pour les contributions externes sur GitHub : n'importe quel compte
  # authentifi\u00e9 peut forker un d\u00e9p\u00f4t public, sans droit d'\u00e9criture pr\u00e9alable.
  #
  # Le login est maintenant obligatoire : le fork vit sous ce compte.
  if (is.na(registered_by))
    cli::cli_abort(c(
      "Impossible de r\u00e9soudre le login GitHub associ\u00e9 au token.",
      "i" = "Le fork n\u00e9cessaire \u00e0 l'ouverture de la PR vit sous ce compte \\
             \u2014 v\u00e9rifier {.envvar DEPLOY_PAT} ou les identifiants \\
             {.pkg gitcreds}."
    ))

  registry_name <- strsplit(registry_repo, "/", fixed = TRUE)[[1L]][[2L]]
  fork_slug     <- sprintf("%s/%s", registered_by, registry_name)

  fork_exists <- tryCatch({
    httr2::request("https://api.github.com") |>
      httr2::req_url_path(sprintf("/repos/%s", fork_slug)) |>
      httr2::req_auth_bearer_token(token) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform() |>
      httr2::resp_status() |>
      identical(200L)
  }, error = function(e) FALSE)

  if (!fork_exists) {
    cli::cli_alert_info(
      "Cr\u00e9ation d'un fork de {.val {registry_repo}} sous @{registered_by}...")
    httr2::request("https://api.github.com") |>
      httr2::req_url_path(sprintf("/repos/%s/forks", registry_repo)) |>
      httr2::req_auth_bearer_token(token) |>
      httr2::req_headers(
        Accept                 = "application/vnd.github+json",
        `X-GitHub-Api-Version` = "2022-11-28"
      ) |>
      httr2::req_perform()   # 202 Accepted — cr\u00e9ation asynchrone

    # GitHub provisionne le fork de mani\u00e8re asynchrone : un 202 ne garantit
    # pas qu'il soit d\u00e9j\u00e0 clonable. On patiente jusqu'\u00e0 10 x 2s.
    fork_ready <- FALSE
    for (i in 1:10) {
      Sys.sleep(2)
      status <- tryCatch({
        httr2::request("https://api.github.com") |>
          httr2::req_url_path(sprintf("/repos/%s", fork_slug)) |>
          httr2::req_auth_bearer_token(token) |>
          httr2::req_error(is_error = \(r) FALSE) |>
          httr2::req_perform() |>
          httr2::resp_status()
      }, error = function(e) 0L)
      if (identical(status, 200L)) { fork_ready <- TRUE; break }
    }
    if (!fork_ready)
      cli::cli_abort(
        "Le fork {.val {fork_slug}} n'est pas devenu disponible \\
         \u00e0 temps \u2014 r\u00e9essayer dans quelques instants.")
  }

  # ---- 9. Clonage du fork dans un dossier temporaire -----------------------
  tmp <- fs::path(tempdir(),
                  paste0("wp-registry-", format(Sys.time(), "%Y%m%d%H%M%S")))
  on.exit(try(fs::dir_delete(tmp), silent = TRUE), add = TRUE)

  registry_https <- sprintf("https://github.com/%s.git", registry_repo)
  fork_https      <- sprintf("https://github.com/%s.git", fork_slug)
  cli::cli_alert_info("Clonage du fork {.val {fork_slug}}...")
  gert::git_clone(url = fork_https, path = tmp, verbose = FALSE)

  # Le fork peut avoir pris du retard sur l'upstream entre sa cr\u00e9ation et
  # cette demande : on le resynchronise avant de brancher, pour que la PR
  # ne contienne qu'un diff propre par rapport \u00e0 `main`.
  gert::git_remote_add(url = registry_https, name = "upstream", repo = tmp)
  gert::git_fetch(remote = "upstream", repo = tmp, verbose = FALSE)
  gert::git_reset_hard(ref = "upstream/main", repo = tmp)

  # ---- 10. Modification de wp/{annee}.json et wp/index.json ----------------
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

  # ---- 11. Branche, commit, push vers le FORK -------------------------------
  branch_name <- sprintf("request/%d/%d", annee, wp)
  gert::git_branch_create(branch = branch_name, repo = tmp, checkout = TRUE)
  gert::git_add(c(sprintf("wp/%d.json", annee), "wp/index.json"), repo = tmp)
  gert::git_commit(
    message = sprintf("request: %d/%d \u2014 %s", annee, wp, source_repo),
    repo    = tmp,
    author  = gert::git_signature(
      name  = registered_by,
      email = contact
    )
  )

  # Le push cible le fork (sous le compte de l'appelant), pas `registry_repo`
  # directement : n'importe quel token authentifi\u00e9 y a les droits d'\u00e9criture,
  # sans devoir \u00eatre collaborateur·rice sur `wp-registry` lui-m\u00eame.
  push_url <- sub("https://",
                  sprintf("https://x-access-token:%s@", token),
                  fork_https)
  push_out <- suppressWarnings(system2(
    "git",
    c("-C", shQuote(tmp),
      "-c", "credential.helper=",
      "push", push_url,
      sprintf("HEAD:refs/heads/%s", branch_name)),
    stdout = TRUE, stderr = TRUE
  ))
  push_status <- attr(push_out, "status") %||% 0L
  if (!identical(push_status, 0L))
    cli::cli_abort(c(
      "git push vers le fork {.val {fork_slug}} a \u00e9chou\u00e9 (code {push_status}).",
      "x" = paste(push_out, collapse = "\n")
    ))

  # ---- 12. Ouverture de la PR (cross-repo, depuis le fork) ------------------
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
    sprintf("| `registered-by` | %s |\n", registered_by),
    if (new_year) sprintf(
      "\n_Premi\u00e8re demande pour %d : cr\u00e9e `wp/%d.json` et met \u00e0 jour `wp/index.json`._\n",
      annee, annee) else "",
    sprintf(
      "\n_Ouvert automatiquement par `ofceweb::wp_registry_request()` depuis le fork `%s`._",
      fork_slug)
  )

  # `head` au format "owner:branch" : c'est ce qui fait de la PR une PR
  # cross-repo depuis le fork, plut\u00f4t qu'une branche du d\u00e9p\u00f4t cible.
  pr_resp <- httr2::request("https://api.github.com") |>
    httr2::req_url_path(sprintf("/repos/%s/pulls", registry_repo)) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_headers(
      Accept                 = "application/vnd.github+json",
      `X-GitHub-Api-Version` = "2022-11-28"
    ) |>
    httr2::req_body_json(list(
      title = pr_title,
      head  = sprintf("%s:%s", registered_by, branch_name),
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
