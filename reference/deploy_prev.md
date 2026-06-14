# Déploie la prévision OFCE (staging ou publish)

Pousse le répertoire de sortie déjà rendu vers la branche git appropriée
sans relancer le rendu Quarto. Pour staging, pousse \`\_site_staging/\`
vers \`site-staging\` ; pour publish, pousse \`\_site_publish/\` vers
\`site-publish\`.

## Usage

``` r
deploy_prev(
  path = ".",
  target = "staging",
  progress = TRUE,
  trigger = TRUE,
  full_deploy = FALSE
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- target:

  \`"staging"\` (défaut) ou \`"publish"\`.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- trigger:

  Logique. Déclenche le workflow GitHub Actions FTP après le push.
  Défaut \`TRUE\`.

- full_deploy:

  Logique. Si \`TRUE\`, force la ré-émission de tous les fichiers vers
  le FTP (ignore l'état incrémental). Défaut \`FALSE\`.

## Value

Invisible \`NULL\`.

## Prévision Users

## See also

\[stage_prev()\], \[publish_prev()\], \[site2staging()\]
