# Génère le site de la prévision

Orchestre le rendu complet de la prévision appel à
\[quarto::quarto_render()\] avec le profil \`publish\`, puis
optionnellement déploiement du répertoire \`\_site_publish\` vers une
branche git et/ou prévisualisation locale via un serveur HTTP.

## Usage

``` r
render_prev_publish(
  path = ".",
  check_repo = TRUE,
  progress = TRUE,
  render_site = TRUE,
  site2branch = TRUE,
  trigger = site2branch
)
```

## Arguments

- path:

  Chemin vers la racine du projet (dossier \`prevxx\[3\|9\]\`). Par
  défaut \`"."\` (répertoire de travail courant).

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

## Working Paper (WP) Users
