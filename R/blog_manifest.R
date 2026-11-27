# Manifeste collectif du blog (modèle de données v1).
#
# render_blog() écrit `_site/manifest.json` : un tableau JSON dont la première
# entrée décrit le blog (`ofce-blog`) et les suivantes chaque post publié, avec
# `parent: "ofce-blog"`. Une seule déclaration dans `contentdb` couvre tout le
# blog : la présence d'un post dans le manifeste vaut déclaration.
#
# Règles :
# - billet : `type: post`, `institution: ofce` ; GoW (`gow: true`) :
#   `type: gow`, `institution: ofce` ; Écographe (`ecograph: true`, prioritaire
#   sur `gow`) : `type: gow`, `institution: ife` ;
# - `id` = `{institution}-{post|gow}-{annee}-{dossier}-{lang}`, dossier en
#   minuscules, `_` remplacé par `-`. Changer cette règle change les `id` de
#   toute la base : ne pas y toucher ;
# - une entrée invalide est écartée du manifeste (avertissement), pour qu'un
#   post fautif ne fige pas tout le blog dans la base ;
# - sans `jsonvalidate`, le manifeste est écrit sans contrôle.

blog_title <- "Le blog de l'OFCE"

# Libellés de série retirés des catégories d'une entrée `gow` (comparés en
# minuscules).
blog_series_labels <- c("écographe", "ecographe", "écograph", "ecograph")

# `image: fig-{label}` désigne la vignette générée à partir du chunk {label}
# (_utils/thumbnail.R du blog) : le fichier publié est `fig-{label}.png`.
# Partagée avec copy_post().
post_image_name <- function(image) {
  if (is.null(image)) return(NULL)
  if (is.character(image) && length(image) == 1L && grepl("^fig-[^./]+$", image))
    return(paste0(image, ".png"))
  image
}

# Nom du PDF publié pour un fichier de post : nom du fichier sans `.qmd` ni
# `.en`, puis `.{lang}.pdf`. Un fichier `x.fr.qmd` donne `x.fr.fr.pdf` : c'est
# le nom que le rendu publie, à garder pour ne pas casser les liens existants.
# Partagée avec copy_post().
post_pdf_name <- function(file, lang) {
  post_name <- sub("\\.en$", "", fs::path_ext_remove(fs::path_file(file)))
  paste0(post_name, ".", lang, ".pdf")
}

# Point de remplacement pour les tests : le contrôle demande jsonvalidate.
blog_manifest_can_validate <- function() {
  rlang::is_installed("jsonvalidate")
}

# Adresse de base du blog, depuis `site-url` et `site-path` de `_quarto.yml`
# (même normalisation que build_sitemap()).
blog_base_url <- function(root) {
  quarto_yml <- yaml::read_yaml(fs::path(root, "_quarto.yml"))
  site_url <- quarto_yml$website[["site-url"]] %||% "https://www.ofce.fr/"
  if (!endsWith(site_url, "/")) site_url <- paste0(site_url, "/")
  site_path <- quarto_yml$website[["site-path"]]
  if (!is.null(site_path) && nzchar(site_path))
    site_url <- paste0(site_url, sub("^/", "", sub("/?$", "/", site_path)))
  site_url
}

# Date de l'en-tête au format AAAA-MM-JJ, NULL si illisible (l'entrée sera
# alors écartée par le contrôle).
blog_date <- function(x) {
  x <- manifest_chr1(x)
  if (is.null(x)) return(NULL)
  d <- tryCatch(as.Date(x), error = function(e) NA)
  if (is.na(d)) NULL else format(d, "%Y-%m-%d")
}

# Entrée d'un fichier de post (`file`, relatif à `posts/`).
blog_post_entry <- function(file, translated, gow, ecograph, root, base) {
  # posts_db() a déjà averti une fois pour chaque fichier sans fin de ligne
  # finale : pas de second avertissement ici.
  yml <- withCallingHandlers(
    get_yaml(fs::path(root, "posts", file)),
    warning = function(w) {
      if (grepl("incomplete final line|ligne finale incompl", conditionMessage(w)))
        invokeRestart("muffleWarning")
    }
  )
  folder <- as.character(fs::path_dir(file))
  segments <- strsplit(folder, "/", fixed = TRUE)[[1]]
  annee <- segments[[1]]
  dossier <- segments[[length(segments)]]
  lang <- if (grepl("\\.en\\.qmd$", file)) "en" else "fr"

  ecograph <- isTRUE(ecograph)
  serie <- ecograph || isTRUE(gow)
  institution <- if (ecograph) "ife" else "ofce"
  type <- if (serie) "gow" else "post"
  base_id <- tolower(paste(institution, type, annee, gsub("_", "-", dossier), sep = "-"))

  categories <- manifest_str_list(yml[["categories"]])
  if (serie)
    categories <- Filter(function(x) !tolower(x) %in% blog_series_labels, categories)

  url <- paste0(base, lang, "/", folder, "/")
  image <- post_image_name(manifest_chr1(yml[["image"]]))
  if (!is.null(image) && !grepl("^https://", image)) image <- paste0(url, image)

  e <- list(
    schema_version = "1.0",
    id = paste0(base_id, "-", lang),
    translation_id = if (isTRUE(translated)) base_id else NULL,
    institution = institution,
    type = type,
    media = "html",
    lang = lang,
    parent = "ofce-blog",
    title = manifest_chr1(yml[["title"]]),
    subtitle = manifest_chr1(yml[["subtitle"]]),
    authors = manifest_authors(yml),
    abstract = manifest_chr1(yml[["description"]]),
    categories = unname(categories),
    keywords = list(),
    jel = list(),
    date_published = blog_date(yml[["date"]]),
    url = url,
    pdf = paste0(url, post_pdf_name(file, lang)),
    image = image,
    auto_update = TRUE
  )
  if (serie && !is.null(yml[["nb"]])) e$nb <- yml[["nb"]]
  e
}

# Erreurs du schéma pour une entrée (tibble de manifest_error_rows()).
blog_check_entry <- function(e, validator) {
  json <- manifest_to_json(e)
  manifest_check_one(json, jsonlite::parse_json(json, simplifyVector = FALSE), validator)
}

blog_excluded_rows <- function(file = character(0), id = character(0),
                               field = character(0), message = character(0)) {
  tibble::tibble(
    file = as.character(file), id = as.character(id),
    field = as.character(field), message = as.character(message)
  )
}

# Construit le manifeste collectif du blog.
#
# `posts` : tibble de posts_db() (colonnes `file_fr`, `file_en`, `translated`,
# `draft`, `gow`, `ecograph`), chemins relatifs à `{root}/posts`. Rend
# `list(manifest, excluded, validated)` : `manifest` est la liste des entrées
# (blog en tête), `excluded` le tibble des entrées écartées (`file`, `id`,
# `field`, `message`), `validated` vaut FALSE si le contrôle n'a pas pu se
# faire (jsonvalidate absent).
blog_manifest <- function(posts, root = ".") {
  base <- blog_base_url(root)
  posts <- posts[!vapply(posts$draft, isTRUE, logical(1)), , drop = FALSE]

  entries <- list()
  files <- character(0)
  for (i in seq_len(nrow(posts))) {
    p <- posts[i, ]
    translated <- isTRUE(p$translated) && !is.na(p$file_en)
    for (file in c(p$file_fr, if (translated) p$file_en)) {
      entries[[length(entries) + 1L]] <- blog_post_entry(
        file, translated, p$gow, p$ecograph, root, base
      )
      files <- c(files, file)
    }
  }

  excluded <- blog_excluded_rows()
  validated <- blog_manifest_can_validate()
  validator <- if (validated) manifest_validator()
  keep <- rep(TRUE, length(entries))

  if (validated) {
    for (i in seq_along(entries)) {
      err <- blog_check_entry(entries[[i]], validator)
      if (nrow(err) > 0L) {
        keep[[i]] <- FALSE
        excluded <- rbind(excluded, blog_excluded_rows(
          rep(files[[i]], nrow(err)), err$id,
          ifelse(is.na(err$field), "", err$field), err$message
        ))
      }
    }
  }

  # Identifiants en double : le premier est gardé.
  seen <- character(0)
  for (i in which(keep)) {
    id <- entries[[i]]$id
    if (id %in% seen) {
      keep[[i]] <- FALSE
      excluded <- rbind(excluded, blog_excluded_rows(
        files[[i]], id, "id", paste0("identifiant en double : ", id, " est déjà pris par un autre post.")
      ))
    } else {
      seen <- c(seen, id)
    }
  }
  entries <- entries[keep]

  dates_fr <- unlist(lapply(entries, function(e) if (identical(e$lang, "fr")) e$date_published))
  blog <- list(
    schema_version = "1.0",
    id = "ofce-blog",
    translation_id = NULL,
    institution = "ofce",
    type = "blog",
    media = "site",
    lang = "fr",
    parent = NULL,
    title = blog_title,
    authors = list(),
    categories = list(),
    keywords = list(),
    jel = list(),
    date_published = if (length(dates_fr)) min(dates_fr) else NULL,
    url = base,
    auto_update = TRUE
  )
  if (validated) {
    err <- blog_check_entry(blog, validator)
    if (nrow(err) > 0L)
      cli::cli_warn(c(
        "L'entrée {.val ofce-blog} du manifeste du blog est invalide : elle est écrite quand même.",
        x = "{paste(err$field, err$message, sep = ' : ')}"
      ))
  }

  list(manifest = c(list(blog), entries), excluded = excluded, validated = validated)
}

# Écrit `{root}/_site/manifest.json`. Ne lève jamais d'erreur R : la
# publication du blog passe avant le manifeste. Rend (invisible) le résultat
# de blog_manifest(), ou NULL si le manifeste n'a pas pu être écrit.
write_blog_manifest <- function(posts, root = ".") {
  path <- fs::path(root, "_site", "manifest.json")
  res <- tryCatch({
    res <- blog_manifest(posts, root)
    fs::dir_create(fs::path_dir(path))
    jsonlite::write_json(
      res$manifest, path,
      auto_unbox = TRUE, null = "null", digits = NA, pretty = TRUE
    )
    res
  }, error = function(e) {
    msg <- conditionMessage(e)
    cli::cli_warn("Manifeste du blog non écrit : {msg}")
    NULL
  })
  if (is.null(res)) return(invisible(NULL))

  if (!res$validated)
    cli::cli_warn("Manifeste du blog écrit sans contrôle : installer le package {.pkg jsonvalidate}.")

  if (nrow(res$excluded) > 0L) {
    # Accolades doublées : cli ne réinterprète pas le texte des en-têtes.
    esc <- function(x) gsub("\\}", "}}", gsub("\\{", "{{", x))
    lines <- esc(paste0(res$excluded$file, " : ",
                        ifelse(nzchar(res$excluded$field), paste0(res$excluded$field, " : "), ""),
                        res$excluded$message))
    n <- length(unique(res$excluded$file))
    cli::cli_warn(c(
      "{n} post{?s} écarté{?s} du manifeste du blog :",
      stats::setNames(lines, rep("x", length(lines)))
    ))
  }

  n_entries <- length(res$manifest)
  cli::cli_alert_success("Manifeste du blog : {n_entries} entrée{?s} dans {.file {path}}.")
  invisible(res)
}
