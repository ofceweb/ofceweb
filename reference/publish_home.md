# Publie la homepage du site OFCE

Wrapper de convenance autour de \[render_home()\] qui positionne
\`site2branch = TRUE\` pour déployer automatiquement \`\_site\` vers la
branche git après le rendu.

## Usage

``` r
publish_home(
  path = ".",
  check_repo = TRUE,
  progress = TRUE,
  render_site = FALSE,
  trigger = TRUE
)
```

## Arguments

- path:

  Chemin vers la racine du projet (dossier \`webhome\`). Par défaut
  \`"."\` (répertoire de travail courant).

- check_repo:

  Logique. Si \`TRUE\` (défaut), vérifie l'état du dépôt git avant le
  rendu via \[check_repo_status()\].

- progress:

  Logique. Si \`TRUE\` (défaut), affiche la progression lors du rendu
  Quarto et du déploiement.

- render_site:

  Logique. Si \`TRUE\` (défaut), lance un serveur HTTP local
  (\[servr::httw()\]) sur \`\_site\` après le rendu pour prévisualiser
  le résultat.

- trigger:

  Valeur passée à l'argument \`trigger\` de \[site2branch()\]. Par
  défaut égale à \`site2branch\`.

## Value

Appelée pour ses effets de bord. Retourne invisiblement \`NULL\`.

## See also

\[render_home()\], \[site2branch()\]

## Examples

``` r
if (FALSE) { # \dontrun{
publish_home()
} # }
```
