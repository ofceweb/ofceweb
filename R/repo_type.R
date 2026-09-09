# Dispatch infrastructure shared by render()/publish()/deploy()/check()/
# registry_request(). See R/render.R for detect_repo_type().
#
# .ofce_repo_types() is a function (not a plain list) so it can safely
# reference render_wp()/publish_pb()/... regardless of file source order at
# package load time -- it's only evaluated when a dispatcher actually runs,
# well after the whole namespace is populated.
.ofce_repo_types <- function() {
  list(
    prev = list(render = render_prev, publish = publish_prev, deploy = deploy_prev, check = check_prev, registry = NULL),
    wp   = list(render = render_wp,   publish = publish_wp,   deploy = deploy_wp,   check = check_wp,   registry = wp_registry_request),
    pb   = list(render = render_pb,   publish = publish_pb,   deploy = deploy_pb,   check = check_pb,   registry = pb_registry_request),
    ife  = list(render = render_ife,  publish = publish_ife,  deploy = deploy_ife,  check = NULL,       registry = NULL),
    blog = list(render = render_blog, publish = publish_blog, deploy = NULL,        check = NULL,       registry = NULL),
    home = list(render = render_home, publish = publish_home, deploy = deploy_home, check = NULL,       registry = NULL),
    site = list(render = render_site, publish = publish_site, deploy = deploy_site, check = NULL,       registry = NULL)
  )
}

# Dépôts dont le nom de dossier local attendu est fixe. `wp`/`pb`/`prev`/
# `site` sont volontairement absents : leurs noms de dépôt varient
# légitimement (wp a sa propre diagnostic avertissante dans check_wp(),
# pb/prev/site n'ont aucune convention).
.ofce_expected_repo_name <- list(blog = "webblog", ife = "ife_webhome", home = "webhome")

# Vérifie que le nom du dossier local correspond au dépôt canonique attendu
# pour les types qui en ont un (`blog`/`ife`/`home`). No-op pour les autres
# types. Appelée une fois depuis .ofce_dispatch(), avant l'appel effectif à
# render/publish/deploy/check -- couvre à la fois la détection automatique et
# un `type =` explicite.
validate_repo_name <- function(detected, root) {
  expected <- .ofce_expected_repo_name[[detected]]
  if (is.null(expected)) return(invisible(NULL))
  actual <- fs::path_file(root)
  if (!identical(actual, expected))
    cli::cli_abort(c(
      "D\u00e9tect\u00e9 comme {.val {detected}}, mais le dossier s'appelle {.val {actual}} au lieu de {.val {expected}}.",
      "i" = "V\u00e9rifier qu'il s'agit bien du bon d\u00e9p\u00f4t avant de continuer."
    ))
  invisible(NULL)
}

# Coeur du dispatch partagé par render()/publish()/deploy()/check().
# `action` est l'un de "render"/"publish"/"deploy"/"check" -- la colonne
# correspondante de .ofce_repo_types(). registry_request() a une forme
# légèrement différente (message d'erreur dédié) et n'utilise pas ce helper.
.ofce_dispatch <- function(action, path, type, ...) {
  root <- fs::path_abs(path)
  detected <- type %||% detect_repo_type(root)
  validate_repo_name(detected, root)

  entry <- .ofce_repo_types()[[detected]]
  if (is.null(entry))
    cli::cli_abort("Type de d\u00e9p\u00f4t inconnu : {.val {detected}}")

  fn <- entry[[action]]
  if (is.null(fn))
    cli::cli_abort(c(
      "Pas de {.field {action}} disponible pour le type {.val {detected}}.",
      "i" = .ofce_no_action_hint(action, detected)
    ))

  cli::cli_alert_info(
    "D\u00e9p\u00f4t d\u00e9tect\u00e9 comme {.strong {detected}} \u2014 {action}")

  fn(path = path, ...)
}

# Message d'astuce contextuel pour le cas "pas de <action> pour ce type".
.ofce_no_action_hint <- function(action, detected) {
  if (identical(action, "check") && identical(detected, "blog"))
    return("Pour v\u00e9rifier un post de blog, utiliser {.fn submit_blog} (v\u00e9rification par post, \\
            pas par d\u00e9p\u00f4t).")
  "Ce type de d\u00e9p\u00f4t n'a pas encore cette fonctionnalit\u00e9."
}
