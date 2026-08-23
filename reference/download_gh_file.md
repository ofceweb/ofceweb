# Télécharge un seul fichier depuis un dépôt GitHub

Recherche un fichier par son chemin via l'API Contents de GitHub et le
télécharge vers une destination locale via \`curl\`. Un Bearer token est
attaché automatiquement quand un PAT GitHub est configuré (nécessaire
pour les dépôts privés).

## Usage

``` r
download_gh_file(
  path,
  dest = path,
  owner = "ofceweb",
  repo = "webblog",
  ref = "site-deploy"
)
```

## Arguments

- path:

  Chemin du fichier dans le dépôt (ex.
  \`"posts/2024-01-01/index.qmd"\`).

- dest:

  Chemin local où écrire le fichier. Défaut \`path\`.

- owner:

  Nom de l'utilisateur ou de l'organisation GitHub. Défaut
  \`"ofceweb"\`.

- repo:

  Nom du dépôt. Défaut \`"webblog"\`.

- ref:

  Référence Git (branche, tag ou SHA). Défaut \`"site-deploy"\`.

## Value

Le chemin local \`dest\` en cas de succès, ou \`NULL\` si le fichier n'a
pas été trouvé dans le dépôt.

## Examples

``` r
if (FALSE) { # \dontrun{
download_gh_file("posts/my-post/index.qmd", dest = "local/index.qmd")
} # }
```
