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

Inclut aussi un champ \`pdf-path\` : le chemin du fichier
\`output-file\` du format \`wp-pdf\`/\`wp-typst\` actif, relatif à la
racine \`www.ofce.fr\` (ex. \`"wp/2026/5/OFCEWP2026-5.pdf"\`). Calculé
dès que \`wp\`/\`annee\` sont connus, indépendamment de
\`stage\`/\`url\` : c'est l'emplacement de publication final, pas
nécessairement celui où le fichier est déployé au moment de l'appel.
\`NULL\` si \`wp\`/\`annee\` ou le fichier PDF/Typst ne sont pas encore
connus.

Inclut aussi un champ \`ofceweb-version\` : la version du package
\*\*ofceweb\*\* (\[utils::packageVersion()\]) ayant généré le manifeste
— utile pour diagnostiquer un manifeste produit par une version
antérieure du package.

## See also

\[render_wp()\], \[wp_version_up()\]
