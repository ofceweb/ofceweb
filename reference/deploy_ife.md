# Déploie le site IFE (ife_webhome)

Pousse le répertoire \`\_site\` déjà rendu (via \[render_ife()\]) vers
la branche git \`site-deploy\`, en déclenchant en option le workflow
GitHub Actions de déploiement FTP (\`ftp_deploy.yml\`).

## Usage

``` r
deploy_ife(path = ".", progress = TRUE, trigger = TRUE, ...)
```

## Arguments

- path:

  Chemin vers la racine du dépôt (dossier \`ife_webhome\`). Défaut
  \`"."\`.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Passé à \[site2branch()\]. Défaut \`TRUE\`.

- ...:

  Arguments supplémentaires passés à \[site2branch()\].

## Value

Invisible : valeur de retour de \[site2branch()\].

## See also

\[render_ife()\], \[site2branch()\]
