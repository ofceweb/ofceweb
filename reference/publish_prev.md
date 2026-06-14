# Rend et publie la prévision (publish)

Enchaîne \[render_prev()\] avec le profil \`"publish"\` puis pousse
\`\_site_publish/\` vers la branche \`site-publish\` via
\[site2publish()\].

## Usage

``` r
publish_prev(
  path = ".",
  check_repo = TRUE,
  progress = TRUE,
  site2branch = TRUE,
  trigger = site2branch,
  full_deploy = FALSE,
  preview = FALSE,
  workers = 8L
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- check_repo:

  Logique. Si \`TRUE\` (défaut), vérifie l'état du dépôt git via
  \[check_repo_status()\].

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- site2branch:

  Logique. Si \`TRUE\` (défaut), appelle \[site2staging()\] après le
  rendu.

- trigger:

  Passé à \[site2staging()\]. Défaut = valeur de \`site2branch\`.

- full_deploy:

  Passé à \[site2staging()\]. Défaut \`FALSE\`.

- preview:

  Logique. Si \`TRUE\`, lance un serveur HTTP local via
  \[servr::httw()\] sur le répertoire de sortie après le rendu. Défaut
  \`TRUE\` pour le profil \`"staging"\`, \`FALSE\` pour \`"publish"\`.

- workers:

  Entier. Nombre de workers parallèles. Défaut \`8L\`.

## Value

Invisible \`NULL\`.

## Prévision Users

## See also

\[render_prev()\], \[deploy_prev()\], \[stage_prev()\]
