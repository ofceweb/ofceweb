# Prévisualise le document \`.qmd\` actif dans RStudio

Récupère le chemin du document actif dans l'éditeur RStudio, vérifie
qu'il s'agit d'un fichier \`.qmd\`, le rend via
\[quarto::quarto_render()\] puis lance un serveur HTTP local avec
\[servr::httd()\] positionné directement sur le fichier HTML produit.

## Usage

``` r
preview_qmd(
  profile = NULL,
  daemon = TRUE,
  use_freezer = FALSE,
  as_job = FALSE,
  ...
)

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

Le répertoire servi et le chemin initial sont déduits automatiquement
via \[quarto::quarto_inspect()\] :

1.  \`quarto inspect\` est appelé sur le fichier avec le \`profile\`
    actif ; il retourne la racine du projet (\`\$project\$dir\`) et le
    \`output-dir\` résolu
    (\`\$project\$config\$project\[\["output-dir"\]\]\`).

2.  Si \`quarto inspect\` échoue (ex. type de projet non reconnu par
    l'installation locale), on bascule sur la lecture manuelle de
    \`\_quarto.yml\` et \`\_quarto-profile.yml\`.

3.  Sans projet détecté ou sans \`output-dir\` configuré, le serveur
    pointe sur le dossier du \`.qmd\` lui-même.

## Functions

- `preview_qmd_staging()`: Raccourci pour \`preview_qmd(profile =
  "staging")\`. Lance la prévisualisation du document \`.qmd\` actif
  avec le profil Quarto \`"staging"\`, sans autre paramètre à préciser.
