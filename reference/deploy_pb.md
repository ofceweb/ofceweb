# Déploie un policy brief (PB) OFCE

Équivalent PB de \[deploy_wp()\]. Route le déploiement selon l'état du
registre (\`stage\` dans \`manifest.json\`) et, avant publication, selon
\`stage-target\` dans \`\_quarto.yml\` (positionné par \[setup_pb()\]) :

- \*\*Publié\*\* (\`stage: FALSE\`) : toujours vers FTP production
  (\`ftp_deploy.yml\`), quelle que soit la valeur de \`stage-target\`.

- \*\*Non encore publié\*\* (\`stage: TRUE\` ou \`stage\` absent) :
  destination lue depuis \`stage-target\` (\`"auto"\` réévalué à chaque
  appel selon le propriétaire GitHub actuel — \`"ftp"\` pour
  l'organisation \`ofce\`, \`"gh-pages"\` sinon ; \`"ftp"\` ou
  \`"gh-pages"\` forcent la destination).

## Usage

``` r
deploy_pb(
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

  Passé à \[site2branch()\]. Déclenche le workflow GitHub Actions FTP.
  Défaut \`TRUE\`.

- full_deploy:

  Passé à \[site2branch()\]. Défaut \`FALSE\`.

- ...:

  Arguments supplémentaires passés à \[site2branch()\].

## Value

Invisible \`NULL\`.

## See also

\[render_pb()\], \[site2branch()\], \[pb_version_up()\],
\[pb_registry_request()\]
