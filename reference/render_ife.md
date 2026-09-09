# Rendu du site IFE (ife_webhome)

Orchestre le rendu du site one-page de l'IFE : vérification du dépôt
git, vérification que \`\_quarto.yml\` déclare bien \`project: type:
ife-website\`, nettoyage de \`\_site/\`, rendu via
\[quarto::quarto_render()\] (le script \`scripts/sitemap.R\` tourne
automatiquement en post-render, déjà déclaré dans \`\_quarto.yml\`),
puis optionnellement déploiement du répertoire \`\_site\` vers une
branche git et/ou prévisualisation locale via un serveur HTTP.

## Usage

``` r
render_ife(
  path = ".",
  check_repo = TRUE,
  progress = TRUE,
  render_site = TRUE,
  site2branch = FALSE,
  trigger = site2branch
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

- site2branch:

  Logique. Si \`TRUE\`, appelle \[site2branch()\] pour pousser
  \`\_site\` vers la branche git \`site-deploy\`. Par défaut \`FALSE\`.

- trigger:

  Valeur passée à l'argument \`trigger\` de \[site2branch()\]. Par
  défaut égale à \`site2branch\`.

## Value

Appelée pour ses effets de bord. Retourne invisiblement \`NULL\`.

## Details

Contrairement à \[render_site()\], cette fonction ne reconstruit pas le
sitemap elle-même : le projet \`ife-website\` s'appuie sur son propre
\`scripts/sitemap.R\`, déjà déclaré en \`post-render\` dans
\`\_quarto.yml\`.

## See also

\[publish_ife()\], \[site2branch()\], \[render_site()\]
