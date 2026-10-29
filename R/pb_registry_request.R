#' Demande d'enregistrement d'un PB dans le registre central
#'
#' Calcule l'entrée `{pb, pb_series, source-repo}` pour le dépôt PB local et
#' ouvre une pull request contre `ofce/wp-registry` proposant de l'ajouter à
#' `pb/{série}.json`. Les PB partagent le même dépôt registre que les WP
#' (`ofce/wp-registry`) — sous le sous-dossier `pb/`, distinct de `wp/` — il
#' n'existe pas de dépôt `pb-registry` séparé. Le registre PB est organisé en
#' **séries** (liste, statut ouvert/clos et paramètres dans `pb/index.json`),
#' chacune numérotée à partir de 1 dans son propre fichier `pb/{série}.json`,
#' indépendamment de l'année de publication. La série est lue dans la clé
#' `pb_series` de `_quarto.yml` (`"ofce"` si la clé est absente) ; la demande
#' est refusée si la série est inconnue ou close, ou si le dépôt est déjà
#' enregistré. N'attend pas la fusion (fire-and-forget) — un·e admin doit
#' approuver manuellement. Relancer [setup_pb()] une fois la PR fusionnée :
#' c'est `setup_pb()` (pas `render_pb()`, qui ne consulte plus le registre)
#' qui synchronise `pb`/`pb_series`/`draft` et recalcule
#' `site-path`/`citation.*` depuis l'entrée confirmée, pour basculer du mode
#' staging au mode publication.
#'
#' @details
#' # Flux : push d'une branche puis PR intra-dépôt
#'
#' Le dépôt `ofce/wp-registry` est configuré pour autoriser les
#' membres de l'organisation `ofce` à pousser des branches et ouvrir des
#' pull requests sans être collaborateur·rice avec droit d'écriture
#' (seule la **fusion** reste protégée : branch protection +
#' `CODEOWNERS`). La fonction exploite cette configuration — pas de fork
#' personnel :
#'
#' 1.  Résolution du login GitHub (`GET /user`) associé au token
#'     (`DEPLOY_PAT` ou identifiants `gitcreds`).
#' 2.  Clonage de `ofce/wp-registry`, création de la branche
#'     `request/pb/{série}/{pb}` avec l'entrée proposée ajoutée à
#'     `pb/{série}.json`. Le préfixe `pb/` évite toute collision avec les
#'     branches `request/{annee}/{wp}` ouvertes par [wp_registry_request()]
#'     dans le même dépôt partagé.
#' 3.  Push de cette branche vers `ofce/wp-registry`.
#' 4.  Ouverture d'une pull request intra-dépôt (`head = "{branche}"`,
#'     `base = "main"`).
#'
#' Si le push échoue (droits insuffisants ou token non membre de
#' l'organisation `ofce`), la fonction s'arrête avec une erreur
#' explicite.
#'
#' Le token utilisé (`DEPLOY_PAT` ou identifiants `gitcreds`) doit
#' permettre de résoudre `GET /user` et de pousser une branche sur
#' `ofce/wp-registry` — un PAT classique avec la portée `repo` (ou
#' `public_repo`) d'un compte membre de l'organisation `ofce` convient.
#'
#' @param path Chemin vers la racine du dépôt PB local. Défaut `"."`.
#' @param pb Entier ou `NULL`. Numéro de PB souhaité. Si `NULL` (défaut),
#'   calculé automatiquement comme `max(pb existants de la série) + 1`
#'   d'après `pb/{série}.json` au moment de l'appel (`1` si la série est
#'   encore vide). Si fourni explicitement, la fonction vérifie l'absence de
#'   collision au sein de la série avant d'ouvrir la PR et échoue localement
#'   en cas de conflit.
#' @param contact Adresse de contact de l'auteur·e. Défaut : valeur de
#'   `git config user.email` pour ce dépôt (config locale avec repli sur la
#'   globale). La fonction échoue si aucune valeur ne peut être résolue.
#' @param registry_repo Slug `"owner/repo"` du dépôt registre.
#'   Défaut `"ofce/wp-registry"`.
#' @param dry_run Si `TRUE`, calcule et affiche l'entrée proposée sans ouvrir
#'   de pull request. Défaut `FALSE`.
#'
#' @returns Invisiblement, une liste avec `entry` (l'entrée proposée) et
#'   `pr_url` (URL de la PR ouverte, `NULL` en mode `dry_run`).
#' @seealso [setup_pb()], [render_pb()], [deploy_pb()]
#' @importFrom fs path_expand path_abs path_norm path dir_delete path_file
#' @importFrom cli cli_h1 cli_h2 cli_abort cli_alert_success cli_alert_warning cli_alert_info cli_text cli_verbatim
#' @importFrom yaml read_yaml
#' @importFrom jsonlite fromJSON toJSON read_json
#' @importFrom gert git_clone git_branch_create git_add git_commit git_signature
#' @importFrom httr2 request req_url_path req_url_query req_auth_bearer_token req_headers req_body_json req_perform resp_status resp_body_json
#' @keywords internal
pb_registry_request <- function(
    path          = ".",
    pb            = NULL,
    contact       = NULL,
    registry_repo = "ofce/wp-registry",
    dry_run       = FALSE) {

  root <- path |>
    fs::path_expand() |>
    fs::path_abs() |>
    fs::path_norm()

  cli::cli_h1("pb_registry_request : {fs::path_file(root)}")

  # ---- 1. Organisation ofce requise ----------------------------------------
  source_repo <- tryCatch(gh_slug_from_remote(root), error = function(e) NA_character_)
  if (is.na(source_repo))
    cli::cli_abort(c(
      "Impossible de résoudre le remote origin.",
      "i" = "Vérifier que le dépôt a un remote {.val origin} configuré."
    ))

  repo_owner <- strsplit(source_repo, "/", fixed = TRUE)[[1L]][[1L]]
  if (!identical(tolower(repo_owner), "ofce"))
    cli::cli_abort(c(
      "Ce dépôt est sous {.strong {repo_owner}}, pas sous {.strong ofce}.",
      "i" = "Transférer via GitHub → Settings → Danger Zone → Transfer repository → ofce.",
      "x" = "{.fn pb_registry_request} ne peut pas ouvrir une PR depuis un dépôt hors de l'organisation {.strong ofce}."
    ))

  # ---- 2. Série PB (clé pb_series de _quarto.yml) --------------------------
  qyml_path <- fs::path(root, "_quarto.yml")
  if (!fs::file_exists(qyml_path))
    cli::cli_abort("Pas de {.file _quarto.yml} dans {.path {root}}.")
  yml <- yaml::read_yaml(qyml_path)
  series <- pb_series(yml)
  if (is.null(yml[["pb_series"]]))
    cli::cli_alert_info(
      "Clé {.code pb_series} absente de {.file _quarto.yml} — série \\
       {.val {series}} supposée.")
  else
    cli::cli_alert_info("Série PB : {.val {series}}")

  # ---- 3. Lecture du registre (non authentifié) ----------------------------
  index_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/pb/index.json", registry_repo)
  cli::cli_alert_info("Lecture du registre : {.url {index_url}}")
  index <- fetch_pb_series_index(registry_repo)
  if (is.null(index))
    cli::cli_abort(c(
      "Index des séries PB inaccessible ({.url {index_url}}).",
      "i" = "Vérifier la connexion réseau, puis relancer."
    ))
  if (!series %in% names(index))
    cli::cli_abort(c(
      "Série PB {.val {series}} inconnue du registre.",
      "i" = "Séries existantes : {.val {names(index)}}.",
      "i" = "Corriger {.code pb_series} dans {.file _quarto.yml}."
    ))
  if (!isTRUE(index[[series]][["open"]])) {
    open_series <- names(Filter(function(x) isTRUE(x[["open"]]), index))
    cli::cli_abort(c(
      "La série {.val {series}} est close : aucune nouvelle demande n'est acceptée.",
      "i" = "Définir {.code pb_series} dans {.file _quarto.yml} sur une série ouverte : \\
             {.val {open_series}}."
    ))
  }
  series_label <- index[[series]][["label"]] %||% series

  entries <- fetch_pb_registry(registry_repo, index = index)
  if (is.null(entries))
    cli::cli_abort(c(
      "Registre PB inaccessible (au moins un fichier de série n'a pas pu être lu).",
      "i" = "Vérifier la connexion réseau, puis relancer."
    ))

  # Dépôt déjà enregistré (toutes séries) : inutile de redemander.
  already <- Filter(
    function(e) identical(e$type, "repo") && repo_slug_equal(e[["source-repo"]], source_repo),
    entries
  )
  if (length(already) > 0L)
    cli::cli_abort(c(
      "Le dépôt {.val {source_repo}} est déjà enregistré : série \\
       {.val {already[[1L]][['pb_series']]}}, PB {.val {already[[1L]]$pb}}.",
      "i" = "Lancer {.run ofceweb::setup_pb()} pour synchroniser {.file _quarto.yml}."
    ))

  # ---- 4. Résolution du numéro PB ------------------------------------------
  # Chaque série est numérotée à partir de 1 dans son propre fichier ; ni les
  # autres séries ni l'année n'interviennent.
  series_entries <- Filter(function(e) identical(e[["pb_series"]], series), entries)
  new_series_file <- length(series_entries) == 0L
  if (is.null(pb)) {
    existing_pbs <- vapply(
      series_entries,
      function(e) suppressWarnings(as.integer(e$pb %||% 0L)),
      integer(1L)
    )
    pb <- if (length(existing_pbs) == 0L) 1L else max(existing_pbs, na.rm = TRUE) + 1L
    cli::cli_alert_info("Numéro PB attribué automatiquement : {.val {pb}}")
  } else {
    pb <- suppressWarnings(as.integer(pb))
    if (is.na(pb))
      cli::cli_abort("{.arg pb} doit être un entier ou NULL.")
    # Vérification collision (au sein de la série uniquement)
    collision <- Filter(
      function(e) identical(suppressWarnings(as.integer(e$pb)), pb),
      series_entries
    )
    if (length(collision) > 0L)
      cli::cli_abort(c(
        "Le numéro PB {.val {pb}} est déjà enregistré dans la série {.val {series}}.",
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
        "Impossible de résoudre le contact depuis {.code git config user.email}.",
        "i" = "Fournir explicitement : {.code pb_registry_request(contact = \"prenom.nom@ofce.sciences-po.fr\")}"
      ))
  }

  # ---- 6. Token GitHub + login ---------------------------------------------
  # Reste tolérant ici (avertissement + NA) : ce login n'est qu'informatif
  # pour l'entrée proposée et le mode `dry_run`, qui ne doivent pas exiger
  # de réseau fonctionnel. Il devient obligatoire plus loin (étape 8), une
  # fois qu'on sait qu'on va réellement cloner et pousser sur le registre.
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
    cli::cli_alert_warning("Login GitHub non résolu : {conditionMessage(e)}")
    NA_character_
  })

  # ---- 7. Construction de l'entrée -----------------------------------------
  new_entry <- list(
    pb              = pb,
    pb_series       = series,
    type            = "repo",
    `source-repo`   = source_repo,
    contact         = contact,
    `registered-by` = if (!is.na(registered_by)) registered_by else NULL,
    `registered-at` = format(Sys.Date(), "%Y-%m-%d")
  )

  cli::cli_h2("Entrée proposée")
  # cli_verbatim() (pas cli_text()) : le JSON pretty-printed contient des
  # accolades littérales que cli_text() tenterait d'interpréter comme des
  # expressions glue.
  cli::cli_verbatim(
    jsonlite::toJSON(new_entry, auto_unbox = TRUE, pretty = TRUE, null = "null"))

  if (dry_run) {
    cli::cli_alert_info("Mode {.code dry_run} : aucune PR ouverte.")
    return(invisible(list(entry = new_entry, pr_url = NULL)))
  }

  # ---- 8. Clonage de registry_repo -----------------------------------------
  # Le dépôt registre est configuré pour autoriser les membres de l'org
  # `ofce` à pousser des branches et ouvrir des PR sans droit d'écriture
  # (seule la fusion est protégée). On clone donc directement
  # `registry_repo`, sans passer par un fork.
  if (is.na(registered_by))
    cli::cli_abort(c(
      "Impossible de résoudre le login GitHub associé au token.",
      "i" = "Nécessaire pour signer le commit et ouvrir la PR — \
             vérifier {.envvar DEPLOY_PAT} ou les identifiants {.pkg gitcreds}."
    ))

  registry_https <- sprintf("https://github.com/%s.git", registry_repo)

  tmp <- fs::path(tempdir(),
                  paste0("wp-registry-pb-", format(Sys.time(), "%Y%m%d%H%M%S")))
  on.exit(try(fs::dir_delete(tmp), silent = TRUE), add = TRUE)

  cli::cli_alert_info("Clonage de {.val {registry_repo}}...")
  gert::git_clone(url = registry_https, path = tmp, verbose = FALSE)

  # ---- 9. Modification de pb/{série}.json ---------------------------------
  pb_dir <- fs::path(tmp, "pb")
  fs::dir_create(pb_dir, recurse = TRUE)

  series_file   <- sprintf("pb/%s.json", series)
  registry_path <- fs::path(tmp, series_file)
  current_registry <- if (fs::file_exists(registry_path))
    jsonlite::read_json(registry_path)
  else
    list(pb = list())
  current_registry$pb <- c(current_registry$pb %||% list(), list(new_entry))
  writeLines(
    jsonlite::toJSON(current_registry, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    registry_path
  )

  # ---- 10. Branche, commit, push vers registry_repo ------------------------
  # Préfixe pb/ : registry_repo est désormais partagé avec les WP
  # (ofce/wp-registry) -- wp_registry_request() nomme ses branches
  # request/{annee}/{wp} ; sans préfixe, un WP et un PB portant le même
  # numéro produiraient le même nom de branche.
  branch_name <- sprintf("request/pb/%s/%d", series, pb)
  gert::git_branch_create(branch = branch_name, repo = tmp, checkout = TRUE)
  gert::git_add(series_file, repo = tmp)
  gert::git_commit(
    message = sprintf("request(pb/%s): %d — %s", series, pb, source_repo),
    repo    = tmp,
    author  = gert::git_signature(
      name  = registered_by,
      email = contact
    )
  )

  # --force : la branche request/pb/{série}/{pb} est régénérée from scratch depuis
  # main à chaque appel ; un push précédent (ex. appel interrompu, PR fermée
  # et rouverte) laisse une branche distante qu'il faut écraser.
  push_url <- sub("https://",
                  sprintf("https://x-access-token:%s@", token),
                  registry_https)
  push_out <- suppressWarnings(system2(
    "git",
    c("-C", shQuote(tmp),
      "-c", "credential.helper=",
      "push", "--force", push_url,
      sprintf("HEAD:refs/heads/%s", branch_name)),
    stdout = TRUE, stderr = TRUE
  ))
  push_status <- attr(push_out, "status") %||% 0L
  if (!identical(push_status, 0L))
    cli::cli_abort(c(
      "git push vers {.val {registry_repo}} a échoué (code {push_status}).",
      "x" = paste(push_out, collapse = "\n"),
      "i" = "Vérifier que le token appartient à un compte membre \
             de l'organisation {.strong ofce} et que {.val {registry_repo}} \
             autorise la création de branches."
    ))

  # ---- 11. Recherche d'une PR existante puis ouverture ---------------------
  # La branche request/pb/{série}/{pb} est déterministe : si la fonction est
  # relancée (ex. après correction de l'entrée), la force-push met à jour
  # la branche distante mais une PR peut déjà être ouverte. On la
  # réutilise plutôt que d'en créer une nouvelle (GitHub renverrait 422).
  existing_prs <- httr2::request("https://api.github.com") |>
    httr2::req_url_path(sprintf("/repos/%s/pulls", registry_repo)) |>
    httr2::req_url_query(
      state = "open",
      head  = branch_name
    ) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_headers(
      Accept                 = "application/vnd.github+json",
      `X-GitHub-Api-Version` = "2022-11-28"
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  if (length(existing_prs) > 0L) {
    pr_url <- existing_prs[[1L]]$html_url
    cli::cli_alert_info(
      "Une PR existe déjà pour {.val {pb}} : {.url {pr_url}}")
    cli::cli_text(
      "Attendre la fusion par un·e admin, puis relancer \\
       {.run ofceweb::setup_pb()}.")
    return(invisible(list(entry = new_entry, pr_url = pr_url)))
  }

  # ---- 12. Ouverture de la PR (intra-dépôt) --------------------------------
  pr_title <- sprintf("Enregistrement PB %s — %s", series_label, source_repo)
  pr_body <- paste0(
    "## Demande d’enregistrement PB\n\n",
    "| Champ | Valeur |\n|---|---|\n",
    sprintf("| `pb` | %d |\n", pb),
    sprintf("| `pb_series` | %s |\n", series),
    sprintf("| `type` | repo |\n"),
    sprintf("| `source-repo` | `%s` |\n", source_repo),
    sprintf("| `contact` | %s |\n", contact),
    sprintf("| `registered-by` | %s |\n", registered_by),
    if (new_series_file) sprintf(
      "\n_Premier numéro de la série `%s`._\n", series) else "",
    sprintf(
      "\n_Ouvert automatiquement par `ofceweb::pb_registry_request()` depuis une branche de `%s`._",
      registry_repo)
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
      "Impossible d’ouvrir la PR (HTTP {httr2::resp_status(pr_resp)}) : {body_msg}")
  }

  pr_url <- httr2::resp_body_json(pr_resp)$html_url
  cli::cli_alert_success("PR ouverte : {.url {pr_url}}")
  cli::cli_text(
    "Un·e admin doit approuver et fusionner la PR avant que le dépôt \\
     puisse publier sur le chemin numéroté.")
  cli::cli_text(
    "Relancer {.run ofceweb::setup_pb()} une fois la PR fusionnée \
     (pas {.fn render_pb}, qui ne consulte plus le registre) pour \
     synchroniser {.code pb}/{.code draft} et recalculer \
     {.field site-path}/{.field citation.*}.")

  invisible(list(entry = new_entry, pr_url = pr_url))
}
