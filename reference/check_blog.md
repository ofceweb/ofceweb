# Vérifie la structure d'un post de blog avant soumission

Inspecte le YAML frontmatter du \`.qmd\` et les fichiers qu'il référence
pour détecter les problèmes bloquants (champs obligatoires manquants,
fichiers introuvables) et les avertissements (dépendances manquantes).

## Usage

``` r
check_blog(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Chemin vers le \`.qmd\` ou son dossier parent. Défaut \`"."\`.

- verbose:

  Logique. Affiche les diagnostics. Défaut \`TRUE\`.

## Value

Data frame (invisible) : colonnes \`field\`, \`status\`, \`message\`.
