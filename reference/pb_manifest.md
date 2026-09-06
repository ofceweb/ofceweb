# Génère ou met à jour le manifeste JSON d'un policy brief

Lit les métadonnées depuis \`\_quarto.yml\` (et \`index.qmd\` pour
l'abstract), construit un \`manifest.json\` normalisé et l'écrit à la
racine du dépôt (pour être commité) et dans \`\_site/\` (pour être
déployé).

## Usage

``` r
pb_manifest(path = ".", stage = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

## Value

La liste du manifeste (invisible).

## Details

Le manifeste est collecté par \`webhome\` via la GitHub API pour
construire l'index des policy briefs OFCE.

Inclut un champ \`source-repo\` (\`"owner/repo"\`, résolu depuis le
remote \`origin\` local) utilisé par le workflow \`ftp_deploy.yml\` pour
détecter qu'un autre dépôt tente de publier sous le même numéro de PB
(même \`pb\` — numérotation séquentielle depuis l'origine, indépendante
de l'année) et bloquer ce déploiement avant d'écraser le PB existant.

## See also

\[render_pb()\], \[pb_version_up()\]
