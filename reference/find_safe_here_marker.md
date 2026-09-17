# Recherche le marqueur \`.safe_here-root\` en remontant l'arborescence

Utilisée par \[safe_here()\]. La recherche part de \`start\` et remonte
répertoire par répertoire (comme le ferait \`rprojroot\`/\`here\` pour
leurs propres marqueurs), car Quarto/knitr exécutent chaque chunk avec
le répertoire de travail réglé sur celui du document — potentiellement
plusieurs niveaux sous la racine de la copie temporaire, notamment pour
les chunks de fichiers inclus via \`\< include sous-dossier/x.qmd \>\`.

## Usage

``` r
find_safe_here_marker(start)
```

## Arguments

- start:

  \`\[character(1)\]\`  
  Répertoire de départ (typiquement \`getwd()\`).

## Value

\`\[character(1)\]\` Chemin vers le marqueur trouvé, ou \`NULL\` si
aucun marqueur n'existe jusqu'à la racine du système de fichiers.
