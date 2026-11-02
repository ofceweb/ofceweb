# Helpers partagés par wp_manifest() et pb_manifest() pour produire les champs
# du modèle de données v1 (webdocs/modele-donnees-v1.qmd).
#
# Les accès aux clés YAML se font avec `[[` (correspondance exacte) : `$` fait
# de l'appariement partiel sur les listes (ex. `yml$date` -> `date-modified`,
# `yml$author` -> `author-title`).

# Valeurs admises pour `institution` (propriété du contenu, pas le co-branding
# Typst porté par le champ distinct `institut`).
manifest_institutions <- c("ofce", "cepii", "ife")

# Chaîne scalaire non vide, ou NULL.
manifest_chr1 <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NULL)
  x <- as.character(x[[1]])
  if (is.na(x) || !nzchar(trimws(x))) NULL else trimws(x)
}

# Vecteur / scalaire / liste YAML -> liste (non nommée) de chaînes non vides.
# Une liste (et non un vecteur) est nécessaire pour que `auto_unbox = TRUE` de
# jsonlite écrive un tableau JSON même avec un seul élément.
manifest_str_list <- function(x) {
  if (is.null(x)) return(list())
  x <- trimws(as.character(unlist(x, use.names = FALSE)))
  as.list(x[!is.na(x) & nzchar(x)])
}

# Auteurs : liste de noms (chaînes) dans l'ordre de saisie. `affiliation` et
# `orcid` restent dans `_quarto.yml` pour le rendu.
manifest_authors <- function(yml) {
  raw <- yml[["author"]] %||% yml[["authors"]]
  if (is.null(raw)) return(list())
  if (is.character(raw)) return(manifest_str_list(raw))
  if (is.list(raw) && !is.null(raw[["name"]])) raw <- list(raw)

  one_name <- function(a) {
    if (!is.list(a)) return(manifest_chr1(a))
    nm <- a[["name"]]
    if (is.list(nm)) nm <- paste(c(nm[["given"]], nm[["family"]]), collapse = " ")
    manifest_chr1(nm)
  }
  nm <- lapply(raw, one_name)
  unname(Filter(Negate(is.null), nm))
}

# Institution : `institution` de `_quarto.yml` uniquement (jamais `institut`).
# Absent -> "ofce" ; valeur inconnue -> avertissement + "ofce" (une erreur de
# métadonnée ne doit jamais bloquer un déploiement).
manifest_institution <- function(yml) {
  inst <- manifest_chr1(yml[["institution"]])
  if (is.null(inst)) return("ofce")

  inst_l <- tolower(inst)
  if (!inst_l %in% manifest_institutions) {
    cli::cli_warn(c(
      "Valeur {.val {inst}} inconnue pour {.field institution} dans {.file _quarto.yml} : {.val ofce} utilisé.",
      i = "Valeurs admises : {.val {manifest_institutions}}."
    ))
    return("ofce")
  }
  inst_l
}

# Liste éditoriale (categories / keywords / jel) : `_quarto.yml` d'abord, puis
# frontmatter de `index.qmd` si la clé est absente ou vide (le gabarit livre
# `[]`), sinon `[]`.
manifest_list_field <- function(name, yml, idx_yml = NULL) {
  v <- manifest_str_list(yml[[name]])
  if (length(v) == 0L) v <- manifest_str_list(idx_yml[[name]])
  v
}

# Identifiant stable `{institution}-{type}-{segments...}-{lang}`, en minuscules,
# sans zero-padding. `segments` : liste des composantes numériques (annee, wp)
# pour un WP ; (pb) pour un PB (numérotation séquentielle, pas d'année).
# NULL tant qu'une composante manque (brouillon sans numéro enregistré). Ne
# dépend pas de `version` : l'id ne change pas à un changement de version.
manifest_id <- function(institution, token, lang, segments) {
  missing_seg <- vapply(segments, function(s) is.null(s) || is.na(s), logical(1))
  if (length(segments) == 0L || any(missing_seg)) return(NULL)
  parts <- c(institution, token, vapply(segments, as.character, character(1)), lang)
  tolower(paste(parts, collapse = "-"))
}
