# Écrit le marqueur \`.safe_here-root\` dans une copie temporaire

Appelée par \`render_flash_worker()\` juste après avoir copié le dossier
ciblé dans son répertoire temporaire de rendu. N'écrit rien si
\`origin_root\` est \`NA\` (racine introuvable même dans l'arborescence
réelle) : \[safe_here()\] se comportera alors, dans la copie, exactement
comme \[here::here()\] — même échec, pas de régression.

## Usage

``` r
write_safe_here_marker(temp_dir, origin_root)
```

## Arguments

- temp_dir:

  \`\[character(1)\]\`  
  Racine de la copie temporaire.

- origin_root:

  \`\[character(1)\]\`  
  Racine réelle du projet (résultat de \[here::here()\] appelé depuis le
  dossier source, avant copie), ou \`NA_character\_\`.

## Value

Invisiblement \`NULL\`.
