# Complète les champs manquants dans \`\_quarto.yml\` pour un WP

Remplit les champs obligatoires dans le \`\_quarto.yml\` d'un WP (comme
vérifiés par \`check_wp()\`) en utilisant des valeurs par défaut
raisonnables. Cette fonction n'est \*\*jamais destructive\*\* : elle ne
modifie aucun champ existant et ne crée que les champs qui manquent.

## Usage

``` r
complete_wp(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- verbose:

  Logique. Si \`TRUE\` (défaut), affiche les champs ajoutés avec
  \[cli::cli_alert_info()\].

## Value

Invisible. Modifie le fichier \`\_quarto.yml\` sur disque.

## Details

Champs complétés si absents :

- \`date\` : utilise la date du jour (format \`YYYY-MM-DD\`)

- \`annee\` : extrait depuis \`date\` ou utilise l'année courante

- \`author\` : structure minimale si \`author\` et \`authors\` sont tous
  deux absents

- \`citation\` : structure minimale (\`type: article-journal\`,
  \`container-title\` standard)

- \`ofce_wp\` : positionné à \`TRUE\` pour signaler un WP OFCE

## See also

\[check_wp()\], \[setup_wp()\]
