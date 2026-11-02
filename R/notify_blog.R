#' Notifie par mail la publication de nouveaux billets du blog
#'
#' Compare la base des posts (sortie de [posts_db()]) au registre des billets
#' déjà notifiés (`posts_notified.txt`, un `postID` par ligne, commité dans le
#' dépôt) et envoie un mail par nouveau billet, avec \pkg{blastula}, à la
#' liste de destinataires déclarée dans `_notify.yml`. Chaque mail porte en
#' pièce jointe un fichier texte avec les métadonnées du billet (titre,
#' auteurs, date, catégories, description, URL). Appelée par [render_blog()]
#' après le déploiement quand `notify = TRUE` (par défaut avec
#' [publish_blog()]).
#'
#' Fichier `_notify.yml` (à la racine du blog) :
#' ```yaml
#' from: blog.ofce@gmail.com
#' sender_name: Blog de l'OFCE          # optionnel
#' to:
#'   - prenom.nom@sciencespo.fr
#' cc: []                               # optionnel
#' bcc: []                              # optionnel
#' subject: "Nouveau billet : {title}"  # optionnel
#' smtp:
#'   provider: gmail                    # ou host/port/use_ssl
#'   user: blog.ofce@gmail.com
#'   creds_file: gmail_creds            # optionnel, usage local
#' body: |                              # optionnel (ou body_file: ...)
#'   Bonjour,
#'
#'   **{title}** par {authors} vient de paraître : {url}
#' ```
#' Sans `_notify.yml`, rien n'est fait.
#'
#' Le corps du mail est un gabarit Markdown interprété par [glue::glue()],
#' donné dans `body` ou dans un fichier (`body_file`), à défaut le gabarit
#' par défaut de [mail_new_post()]. Champs disponibles : `{title}`,
#' `{title_en}`, `{authors}`, `{date}`, `{categories}`, `{description}`,
#' `{description_en}`, `{url}`, `{url_en}`, `{postID}`.
#'
#' Identifiants SMTP, dans l'ordre :
#' - la variable d'environnement `OFCE_SMTP_PASSWORD` (secret du dépôt en
#'   CI, `~/.Renviron` en local), avec `smtp$user` et `smtp$provider` ou
#'   `smtp$host`/`smtp$port`/`smtp$use_ssl` ;
#' - le fichier `smtp$creds_file`, créé une fois avec
#'   [blastula::create_smtp_creds_file()] (à ne pas commiter).
#'
#' Si le registre n'existe pas, il est initialisé avec tous les billets
#' existants sans envoyer de mail (pour éviter de notifier tout l'historique).
#' Un billet dont l'envoi a échoué (ou si le SMTP n'est pas configuré) n'est
#' pas inscrit au registre et sera notifié à la publication suivante. Les
#' billets `draft: true` sont ignorés.
#'
#' @param posts Tibble des posts, sortie de [posts_db()].
#' @param root Racine du blog. Défaut `"."`.
#' @param commit Logique. Si `TRUE` (défaut), commite le registre mis à jour.
#'
#' @return Les `postID` notifiés, invisiblement.
#' @keywords internal
notify_new_posts <- function(posts, root = ".", commit = TRUE) {
  cfg_file <- fs::path(root, "_notify.yml")
  if (!fs::file_exists(cfg_file)) {
    cli::cli_alert_info("Pas de {.file _notify.yml}, pas de notification mail.")
    return(invisible(character()))
  }
  cfg <- yaml::read_yaml(cfg_file)
  if (length(cfg$to) == 0) {
    cli::cli_alert_warning("{.file _notify.yml} : aucun destinataire ({.field to}), pas de notification.")
    return(invisible(character()))
  }

  registry <- fs::path(root, "posts_notified.txt")
  published <- posts
  if ("draft" %in% names(published))
    published <- dplyr::filter(published, !draft)

  if (!fs::file_exists(registry)) {
    writeLines(sort(published$postID), registry)
    cli::cli_alert_info(
      "Registre {.file posts_notified.txt} initialisé avec {nrow(published)} billet{?s}, aucune notification envoyée.")
    if (commit) .commit_registry(root, "Initialisation du registre des notifications")
    return(invisible(character()))
  }

  done <- readLines(registry)
  new <- dplyr::filter(published, !postID %in% done)
  if (nrow(new) == 0) {
    cli::cli_alert_info("Aucun nouveau billet à notifier.")
    return(invisible(character()))
  }

  creds <- .smtp_creds(cfg, root)
  if (is.null(creds)) {
    cli::cli_alert_warning(paste0(
      "{nrow(new)} nouveau{?x} billet{?s} non notifié{?s} : SMTP non configuré ",
      "({.envvar OFCE_SMTP_PASSWORD} ou {.field smtp$creds_file} dans {.file _notify.yml})."))
    return(invisible(character()))
  }

  template <- .notify_template(cfg, root)
  base_url <- .blog_base_url(root)
  sent <- purrr::map_lgl(seq_len(nrow(new)), \(i) {
    post <- .post_fields(new[i, ], base_url)
    tryCatch({
      .send_post_mail(post, cfg, creds, template)
      cli::cli_alert_success("Notification envoyée : {.emph {post$title}}")
      TRUE
    }, error = \(e) {
      cli::cli_alert_danger("Échec de l'envoi pour {.val {post$postID}} : {conditionMessage(e)}")
      FALSE
    })
  })

  notified <- new$postID[sent]
  if (length(notified) > 0) {
    writeLines(sort(c(done, notified)), registry)
    if (commit)
      .commit_registry(root, "Notification de {length(notified)} billet(s)" |> glue::glue())
  }
  invisible(notified)
}

#' Compose le mail annonçant un billet
#'
#' Équivalent pour le blog d'une fonction de type `mail_xxx(id)` construisant
#' un mail \pkg{blastula} : le gabarit Markdown est rempli avec les champs du
#' billet par [glue::glue_data()] puis passé à [blastula::compose_email()].
#'
#' @param post Liste nommée des champs du billet (`title`, `authors`, `date`,
#'   `categories`, `description`, `url`, ... ; voir [notify_new_posts()]).
#' @param template Gabarit Markdown du corps du mail. Défaut : gabarit
#'   standard du blog.
#'
#' @return Un objet `blastula_message`.
#' @keywords internal
mail_new_post <- function(post, template = .default_notify_template) {
  blastula::compose_email(
    body = blastula::md(glue::glue_data(post, template)),
    footer = "")
}

.default_notify_template <- "
Bonjour,

Un nouveau billet vient d'être publié sur le blog de l'OFCE :

**{title}**

*{authors}* — {date}

{description}

\U0001F449 [Lire le billet]({url})

Les métadonnées du billet sont jointes à ce message.
"

# Helpers -----------------------------------

.smtp_creds <- function(cfg, root) {
  smtp <- cfg$smtp %||% list()
  if (nzchar(Sys.getenv("OFCE_SMTP_PASSWORD")) && !is.null(smtp$user))
    return(blastula::creds_envvar(
      user = smtp$user,
      pass_envvar = "OFCE_SMTP_PASSWORD",
      provider = smtp$provider,
      host = smtp$host,
      port = smtp$port,
      use_ssl = smtp$use_ssl %||% TRUE))
  if (!is.null(smtp$creds_file)) {
    file <- fs::path(root, smtp$creds_file)
    if (fs::file_exists(file)) return(blastula::creds_file(file))
  }
  NULL
}

.notify_template <- function(cfg, root) {
  if (!is.null(cfg$body_file))
    return(paste(readLines(fs::path(root, cfg$body_file), encoding = "UTF-8"), collapse = "\n"))
  cfg$body %||% .default_notify_template
}

.blog_base_url <- function(root) {
  web <- yaml::read_yaml(fs::path(root, "_quarto.yml"))$website
  url <- sub("/?$", "/", web[["site-url"]] %||% "https://www.ofce.fr/")
  if (nzchar(web[["site-path"]] %||% ""))
    url <- paste0(url, sub("^/", "", sub("/?$", "/", web[["site-path"]])))
  url
}

# Une ligne de posts_db() -> liste de champs utilisables dans les gabarits
.post_fields <- function(row, base_url) {
  post <- purrr::map_if(as.list(row), is.list, ~ .x[[1]])
  na_empty <- function(x) if (length(x) == 0 || all(is.na(x))) "" else x
  url <- function(lang) paste0(base_url, lang, "/", fs::path_dir(post$file_fr), "/")
  list(
    postID = post$postID,
    file_fr = post$file_fr,
    title = post$title_fr,
    title_en = na_empty(post$title_en),
    authors = paste(unlist(post$author), collapse = ", "),
    date = post$date,
    categories = paste(unlist(post$categories_fr), collapse = ", "),
    description = na_empty(post$description_fr),
    description_en = na_empty(post$description_en),
    url = url("fr"),
    url_en = if (isTRUE(post$translated)) url("en") else "")
}

.post_metadata_txt <- function(post) {
  lines <- c(
    "Titre : "       = post$title,
    "Title (en) : "  = post$title_en,
    "Auteurs : "     = post$authors,
    "Date : "        = post$date,
    "Catégories : " = post$categories,
    "URL : "         = post$url,
    "URL (en) : "    = post$url_en,
    "Description : " = post$description,
    "Description (en) : " = post$description_en)
  lines <- lines[nzchar(lines)]
  paste0(names(lines), lines, collapse = "\n")
}

.send_post_mail <- function(post, cfg, creds, template) {
  txt <- fs::path(tempdir(), paste0(fs::path_file(fs::path_dir(post$file_fr)), ".txt"))
  # BOM UTF-8 : les accents s'affichent correctement dans le Bloc-notes Windows
  writeLines(enc2utf8(paste0("﻿", .post_metadata_txt(post))), txt, useBytes = TRUE)
  on.exit(fs::file_delete(txt), add = TRUE)

  from <- cfg$from %||% cfg$smtp$user
  if (!is.null(cfg$sender_name)) from <- stats::setNames(from, cfg$sender_name)
  subject <- glue::glue_data(
    post, cfg$subject %||% "Nouveau billet sur le blog de l'OFCE : {title}")

  mail_new_post(post, template) |>
    blastula::add_attachment(file = txt) |>
    blastula::smtp_send(
      to = unlist(cfg$to),
      from = from,
      subject = subject,
      cc = unlist(cfg$cc),
      bcc = unlist(cfg$bcc),
      credentials = creds,
      verbose = FALSE)
  invisible(TRUE)
}

.commit_registry <- function(root, message) {
  gert::git_add("posts_notified.txt", repo = root)
  if (nrow(gert::git_status(staged = TRUE, repo = root)) > 0)
    gert::git_commit(message, repo = root)
}
