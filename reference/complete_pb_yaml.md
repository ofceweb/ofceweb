# Complète les champs manquants dans \`\_quarto.yml\` pour un PB

Équivalent PB de \`complete_wp()\`. Remplit les champs obligatoires dans
le \`\_quarto.yml\` d'un PB (comme vérifiés par \[check_pb()\]) en
utilisant des valeurs par défaut raisonnables. Cette fonction n'est
\*\*jamais destructive\*\* : elle ne modifie aucun champ existant et ne
crée que les champs qui manquent.

## Usage

``` r
complete_pb_yaml(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- verbose:

  Logique. Si \`TRUE\` (défaut), affiche les champs ajoutés.

## Value

Invisible. Modifie le fichier \`\_quarto.yml\` sur disque.

## Details

Champs complétés si absents :

- \`date\` : date du jour (format \`YYYY-MM-DD\`)

- \`author\` : structure minimale si \`author\` et \`authors\` sont
  absents

- \`citation\` : structure minimale (\`type: article-journal\`,
  \`container-title: "Policy Brief de l'OFCE"\`)

- \`ofce_pb\` : positionné à \`TRUE\` pour signaler un PB OFCE

## See also

\[check_pb()\], \[setup_pb()\]
