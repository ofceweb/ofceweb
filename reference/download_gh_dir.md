# Télécharge un répertoire depuis un dépôt GitHub

Parcourt récursivement un répertoire de dépôt GitHub, collecte tous les
fichiers correspondants en parallèle avec \[fast_collect_gh_files()\],
puis les télécharge localement via \`curl\`, en ajoutant un en-tête
Bearer token quand un PAT GitHub est disponible (nécessaire pour les
dépôts privés).

## Usage

``` r
download_gh_dir(
  owner,
  repo,
  path,
  destdir = path,
  ref = "HEAD",
  ext = NULL,
  max_depth = 3
)
```

## Arguments

- owner:

  Nom de l'utilisateur ou de l'organisation GitHub.

- repo:

  Nom du dépôt.

- path:

  Chemin du répertoire à télécharger dans le dépôt (ex. \`"posts"\`).

- destdir:

  Répertoire local où écrire les fichiers. Défaut \`path\`.

- ref:

  Référence Git (branche, tag ou SHA). Défaut \`"HEAD"\`.

- ext:

  Si non \`NULL\`, seuls les fichiers se terminant par cette chaîne sont
  téléchargés (ex. \`".qmd"\`).

- max_depth:

  Profondeur maximale de récursion. Défaut \`3\`.

## Value

\`invisible(NULL)\`, appelée pour son effet de bord d'écriture des
fichiers dans \`destdir\`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Ne télécharger que les fichiers .qmd du répertoire posts/
download_gh_dir("OFCE", "Blog_OFCE", "posts", ext = ".qmd", max_depth = 3)
} # }
```
