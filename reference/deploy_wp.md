# Déploie un document de travail (WP) OFCE

Route le déploiement selon l' du registre (\`stage\` dans
\`manifest.json\`) et le param \`target\` :

- \*\*Publi9\*\* (\`stage: false\`) : toujours vers FTP production
  (\`ftp_deploy.yml\`), quel que soit \`target\`.

- \*\*Non encore publi9\*\* (\`stage: true\` ou \`stage\` absent) :
  destination choisie par \`target\` :

  - \`"auto"\` (d) : FTP staging si \`stage = TRUE\` (demande de num
    soumise), GitHub Pages sinon.

  - \`"ftp"\` : FTP staging (\`ftp_stage.yml\`, branche
    \`site-staging\`) ind de l' du registre.

  - \`"gh-pages"\` : GitHub Pages (\`quarto publish gh-pages\`) ind de
    l' du registre.

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
