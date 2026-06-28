# Rend et déploie un site OFCE générique

Enchaîne \[render_site()\] (sans prévisualisation locale) puis
\[deploy_site()\] pour construire et pousser le site en une seule
commande.

## Usage

``` r
stage_site(
  path = ".",
  check_repo = TRUE,
  progress = TRUE,
  trigger = TRUE,
  full_deploy = FALSE,
  workers = 8L
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- check_repo:

  Logique. Passé à \[render_site()\]. Défaut \`TRUE\`.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Passé à \[deploy_site()\]. Défaut \`TRUE\`.

- full_deploy:

  Passé à \[deploy_site()\]. Défaut \`FALSE\`.

- workers:

  Entier. Nombre de workers parallèles pour le rendu. Défaut \`8L\`.

## Value

Invisible \`NULL\`.

## Site Users

## See also

\[render_site()\], \[deploy_site()\], \[setup_site()\]
