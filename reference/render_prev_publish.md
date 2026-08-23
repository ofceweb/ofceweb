# Génère le site de la prévision (déprécié)

\`r lifecycle::badge("deprecated")\`

Cette fonction est remplacée par \[publish_prev()\].

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

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- check_repo:

  Logique. Si \`TRUE\` (défaut), vérifie l'état du dépôt git via
  \[check_repo_status()\].

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- render_site:

  Logique. Passé à \`preview\` de \[publish_prev()\].

- site2branch:

  Logique. Passé à \`site2branch\` de \[publish_prev()\].

- trigger:

  Passé à \[publish_prev()\].

## Value

Invisible \`NULL\`.

## See also

\[publish_prev()\]
