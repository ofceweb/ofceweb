# Prévisualise le document \`.qmd\` actif dans RStudio

Récupère le chemin du document actif dans l'éditeur RStudio, vérifie
qu'il s'agit d'un fichier \`.qmd\`, le rend via
\[quarto::quarto_render()\] puis lance un serveur HTTP local avec
\[servr::httd()\] positionné directement sur le fichier HTML produit.

## Usage

``` r
preview_qmd(profile = NULL, daemon = TRUE, ...)

preview_qmd_staging(daemon = TRUE, ...)
```

## Arguments

- profile:

  \`\[character(1)\]\` ou \`NULL\`.  
  Profil Quarto à utiliser pour le rendu (ex. \`"staging"\`,
  \`"publish"\`). Passé à \[quarto::quarto_render()\] et utilisé pour
  lire le bon \`\_quarto-profile.yml\`. \`NULL\` (défaut) = rendu sans
  profil.

- daemon:

  Logique. Si \`TRUE\` (défaut), le serveur HTTP tourne en arrière-plan
  sans bloquer la console.

- ...:

  Arguments supplémentaires passés à \[quarto::quarto_render()\].

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Le répertoire servi et le chemin initial sont déduits automatiquement :

1.  Si un \`\_quarto.yml\` est trouvé dans un dossier parent, la racine
    du projet est identifiée.

2.  Si \`profile\` est non-\`NULL\`, \`\_quarto-profile.yml\` est lu
    pour en extraire \`project.output-dir\`.

3.  Sans projet ou sans \`output-dir\` configuré, le serveur pointe sur
    le dossier du \`.qmd\` lui-même.

## Prévision Users
