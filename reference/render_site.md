# Rendu d'un site OFCE générique

Lance un build complet du site Quarto pour le dépôt courant (initialisé
via \[setup_site()\]). Calque le fonctionnement de \[render_blog()\]
mais pour un site simple non bilingue : nettoyage de \`\_site\`, rendu
Quarto, reconstruction du sitemap, déploiement optionnel et
prévisualisation locale.

## Usage

``` r
render_site(
  path = ".",
  check_repo = TRUE,
  progress = TRUE,
  render_site = TRUE,
  site2branch = FALSE,
  trigger = site2branch,
  workers = 8L
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- check_repo:

  Logique. Si \`TRUE\` (défaut), vérifie l'état du dépôt git avant le
  rendu via \[check_repo_status()\].

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- render_site:

  Logique. Si \`TRUE\` (défaut), lance un serveur HTTP local via
  \[servr::httw()\] sur \`\_site\` après le rendu.

- site2branch:

  Logique. Si \`TRUE\`, appelle \[site2branch()\] pour pousser
  \`\_site\` vers la branche de déploiement. Défaut \`FALSE\`.

- trigger:

  Passé à \[site2branch()\] pour déclencher le workflow GitHub Actions.
  Défaut égal à \`site2branch\`.

- workers:

  Entier. Nombre de workers parallèles. Défaut \`8L\`.

## Value

Invisible : sortie de \[gert::git_status()\].

## See also

\[setup_site()\], \[stage_site()\], \[site2branch()\], \[render_blog()\]
