# Déploie le site selon l'hébergement déclaré dans \`\_quarto.yml\`

Lit la clé \`ofce_host\` du \`\_quarto.yml\` à la racine du dépôt. Si
\`TRUE\`, délègue à \[site2branch()\] (push de \`\_site\` vers la
branche de déploiement FTP). Si \`FALSE\`, lance \`quarto publish
gh-pages\`.

## Usage

``` r
deploy_site(
  path = ".",
  progress = TRUE,
  trigger = TRUE,
  full_deploy = FALSE,
  ...
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Passé à \[site2branch()\] (hébergement OFCE uniquement). Défaut
  \`TRUE\`.

- full_deploy:

  Passé à \[site2branch()\]. Défaut \`FALSE\`.

- ...:

  Arguments supplémentaires passés à \[site2branch()\] le cas échéant.

## Value

Invisible \`NULL\`.

## Site Users

## See also

\[site2branch()\], \[setup_site()\]
