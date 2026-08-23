# Scanne un .qmd pour identifier tous les fichiers nécessaires à sa compilation

Analyse le YAML frontmatter et le corps du document pour extraire les
références à des fichiers locaux (données, bibliographie, images,
includes). Seuls les chemins relatifs pointant dans le dossier du
\`.qmd\` ou ses sous-dossiers sont retenus — les URLs, chemins absolus
et remontées \`../\` sont exclus.

## Usage

``` r
scan_qmd_deps(qmd_path)
```

## Arguments

- qmd_path:

  Chemin vers le fichier \`.qmd\`.

## Value

Vecteur de caractères : chemins relatifs depuis le dossier du \`.qmd\`.
