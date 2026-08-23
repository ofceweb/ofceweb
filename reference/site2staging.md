# Pousse \`\_site_staging/\` vers la branche \`site-staging\`

Wrapper de \[site2branch()\] configuré pour le déploiement staging de la
prévision. Le contenu est poussé \*\*en clair\*\* ; le chiffrement est
appliqué en CI par \`ftp_deploy_staging.yml\` avant le transfert FTP.

## Usage

``` r
site2staging(path = ".", progress = TRUE, trigger = TRUE, full_deploy = FALSE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Logique. Déclenche \`ftp_deploy_staging.yml\` après le push. Défaut
  \`TRUE\`.

- full_deploy:

  Logique. Si \`TRUE\`, force la ré-émission complète vers le FTP.
  Défaut \`FALSE\`.

## Value

Invisible \`NULL\`.

## See also

\[deploy_prev()\], \[stage_prev()\], \[site2branch()\]
