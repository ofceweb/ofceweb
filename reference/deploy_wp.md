# Déploie un document de travail (WP) OFCE

Route le déploiement selon l'état du WP :

- \*\*Brouillon\*\* (\`wp: null\` dans \`\_quarto.yml\`) : publie sur
  GitHub Pages via \`quarto publish gh-pages\`.

- \*\*Publié\*\* (\`wp: N\`) : pousse \`\_site/\` vers la branche
  \`site-deploy\` via \[site2branch()\], d'où le workflow FTP le
  transfère vers \`www.ofce.fr/wp/annee/N/version/\`.

## Usage

``` r
deploy_wp(
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

  Passé à \[site2branch()\] (WP publié uniquement). Déclenche le
  workflow GitHub Actions FTP. Défaut \`TRUE\`.

- full_deploy:

  Passé à \[site2branch()\]. Défaut \`FALSE\`.

- ...:

  Arguments supplémentaires passés à \[site2branch()\].

## Value

Invisible \`NULL\`.

## See also

\[render_wp()\], \[site2branch()\], \[wp_version_up()\]
