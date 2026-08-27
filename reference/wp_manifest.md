# Génère ou met à jour le manifeste JSON d'un document de travail

Lit les métadonnées depuis \`\_quarto.yml\` (et \`index.qmd\` pour
l'abstract), construit un \`manifest.json\` normalisé et l'écrit à la
racine du dépôt (pour être commité) et dans \`\_site/\` (pour être
déployé).

## Usage

``` r
wp_manifest(path = ".", stage = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

## Value

La liste du manifeste (invisible).

## Details

Le manifeste est collecté par \`webhome\` via la GitHub API pour
construire l'index des documents de travail OFCE.

Inclut un champ \`source-repo\` (\`"owner/repo"\`, résolu depuis le
remote \`origin\` local) utilisé par le workflow \`ftp_deploy.yml\` pour
détecter qu'un autre dépôt tente de publier sous le même numéro de WP
(même \`annee\`/\`wp\`) et bloquer ce déploiement avant d'écraser le WP
existant.

## See also

\[render_wp()\], \[wp_version_up()\]
