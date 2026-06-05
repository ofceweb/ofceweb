# Rescanne les pages et met à jour la section \`other-links\`

Scanne les fichiers \`.qmd\` à la racine du dépôt (récursivement, en
ignorant ceux qui commencent par \`\_\`) et réécrit la section \`website
\> other-links\` du \`\_quarto.yml\` avec une entrée par page trouvée, y
compris \`index.qmd\`. Le titre est lu dans le YAML front-matter du qmd
; à défaut, on utilise le nom du fichier sans extension.

## Usage

``` r
rescan_site(path = ".", icon = "newspaper")
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- icon:

  Icône bootstrap utilisée pour chaque entrée. Défaut \`"newspaper"\`.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Home Users
