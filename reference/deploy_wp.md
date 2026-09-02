# Déploie un document de travail (WP) OFCE

Route le déploiement selon l' du registre (\`stage\` dans
\`manifest.json\`) et, avant publication, selon \`stage-target\` dans
\`\_quarto.yml\` (positionn9 par \[setup_wp()\]) :

- \*\*Publi9\*\* (\`stage: FALSE\`) : toujours vers FTP production
  (\`ftp_deploy.yml\`), quelle que soit la valeur de \`stage-target\`.

- \*\*Non encore publi9\*\* (\`stage: TRUE\` ou \`stage\` absent) :
  destination lue depuis \`stage-target\` :

  - \`"auto"\` : r99 0 \*\*chaque appel\*\* de \`deploy_wp()\`, selon le
    propri GitHub \*actuel\* du d – \`"ftp"\` (staging OFCE,
    \`ftp_stage.yml\`, branche \`site-staging\`) pour l'organisation
    \`ofce\`, \`"gh-pages"\` (\`quarto publish gh-pages\`) sinon.
    \`"auto"\` est conserv9 litt dans \`\_quarto.yml\` par
    \[setup_wp()\] – un transfert de propri9 du d vers (ou hors de)
    \`ofce\` change donc la destination d le prochain \`deploy_wp()\`,
    sans repasser par \[setup_wp()\].

  - \`"ftp"\` : FTP staging (\`ftp_stage.yml\`, branche
    \`site-staging\`) ind du propri actuel du d.

  - \`"gh-pages"\` : GitHub Pages (\`quarto publish gh-pages\`) ind du
    propri actuel du d.

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

  Chemin vers la racine du d. D \`"."\`.

- progress:

  Logique. Affichage de la progression. D \`TRUE\`.

- trigger:

  Pass9 0 \[site2branch()\] (WP staged ou publi9 uniquement). D le
  workflow GitHub Actions FTP. D \`TRUE\`.

- full_deploy:

  Pass9 0 \[site2branch()\]. D \`FALSE\`.

- ...:

  Arguments suppl pass 0 \[site2branch()\].

## Value

Invisible \`NULL\`.

## Working Paper (WP) Users

## See also

\[render_wp()\], \[site2branch()\], \[wp_version_up()\],
\[wp_registry_request()\]
