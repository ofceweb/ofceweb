# Génère ou met à jour le manifeste JSON d'un policy brief

Lit les métadonnées depuis \`\_quarto.yml\` (et \`index.qmd\` pour
l'abstract, le titre et les listes éditoriales en repli), construit un
\`manifest.json\` normalisé et l'écrit à la racine du dépôt (pour être
commité) et dans \`\_site/\` (pour être déployé).

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

Aucun outil ne collecte encore ce manifeste (\`webhome\` maintient ses
listes de publications à la main) ; un futur collecteur devra identifier
un PB par le couple (\`pb_series\`, \`pb\`), pas par \`pb\` seul.

\# Modèle de données v1

Même schéma que \[wp_manifest()\] (\`schema_version: "1.0"\`), avec :

\* \`id\` : \`institution-pb-pb-lang\` (\*\*sans année\*\* :
numérotation séquentielle ; minuscules, sans zero-padding, ex.
\`"ofce-pb-153-fr"\`), stable d'une version à l'autre ; \`NULL\` tant
que \`pb\` n'est pas enregistré (brouillon). \* \`type =
"policy-brief"\`, \`media = "html"\`, \`auto_update = TRUE\`. \*
\`institution\`, \`translation_id\`, \`title\`, \`authors\`,
\`categories\`, \`keywords\`, \`jel\`, \`date_published\` et \`pdf\` :
voir \[wp_manifest()\].

Les champs historiques \`pb\`, \`version\`, \`stage\`, \`pdf-path\`,
\`source-repo\` et \`ofceweb-version\` sont conservés (lus par
\`deploy_pb()\` et \`ftp_deploy.yml\`).

Inclut un champ \`source-repo\` (\`"owner/repo"\`, résolu depuis le
remote \`origin\` local) utilisé par le workflow \`ftp_deploy.yml\` pour
détecter qu'un autre dépôt tente de publier à la même adresse (même
série et même numéro) et bloquer ce déploiement avant d'écraser le PB
existant.

Un PB publié n'est pas versionné : \`url\` vaut
\`https://www.ofce.fr/pb/site-path/\` (ex. \`.../pb/ife/12/\`), sans
segment de version ; seule l'URL de staging d'un brouillon porte la
version.

Inclut aussi un champ \`pdf-path\` : le chemin du fichier
\`output-file\` du format \`pb-pdf\`/\`pb-typst\` actif, relatif à la
racine \`www.ofce.fr\` (ex. \`"pb/ife/12/IFEPB12.pdf"\`). Calculé dès
que \`pb\` est connu, indépendamment de \`stage\`/\`url\` : c'est
l'emplacement de publication final, pas nécessairement celui où le
fichier est déployé au moment de l'appel. \`NULL\` si \`pb\` ou le
fichier PDF/Typst ne sont pas encore connus.

Inclut aussi un champ \`ofceweb-version\` : la version du package
\*\*ofceweb\*\* (\[utils::packageVersion()\]) ayant généré le manifeste
— utile pour diagnostiquer un manifeste produit par une version
antérieure du package.

## See also

\[render_pb()\], \[pb_version_up()\]
