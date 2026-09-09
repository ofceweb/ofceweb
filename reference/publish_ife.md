# Publie le site IFE (ife_webhome)

Wrapper de convenance autour de \[render_ife()\] qui positionne
\`site2branch = TRUE\` pour déployer automatiquement \`\_site\` vers la
branche git \`site-deploy\` après le rendu (le workflow
\`ftp_deploy.yml\` prend le relais côté FTP OVH).

## Usage

``` r
publish_ife(
  path = ".",
  check_repo = TRUE,
  progress = TRUE,
  render_site = FALSE,
  trigger = TRUE
)
```

## Arguments

- path:

  Chemin vers la racine du projet (dossier \`ife_webhome\`). Par défaut
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

\[render_ife()\], \[site2branch()\]

## Examples

``` r
if (FALSE) { # \dontrun{
publish_ife()
} # }
```
