# Déploie la homepage du site OFCE

Pousse le répertoire \`\_site\` déjà rendu (via \[render_home()\]) vers
la branche git \`site-deploy\`, en déclenchant en option le workflow
GitHub Actions de déploiement FTP.

## Usage

``` r
deploy_home(path = ".", progress = TRUE, trigger = TRUE, ...)
```

## Arguments

- path:

  Chemin vers la racine du projet (dossier \`webhome\`). Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Passé à \[site2branch()\]. Défaut \`TRUE\`.

- ...:

  Arguments supplémentaires passés à \[site2branch()\].

## Value

Invisible : valeur de retour de \[site2branch()\].

## See also

\[render_home()\], \[site2branch()\]
