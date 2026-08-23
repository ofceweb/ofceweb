# Resynchronise les répertoires \`.sourcoise/\` des copies rendues vers les posts source

Après le rendu d'une passe de langue, tout répertoire \`.sourcoise/\`
apparu (ou peuplé) dans le dossier de copie éphémère est reporté vers
l'arborescence \`posts/\` d'origine. Seuls les fichiers \*\*pas déjà
présents\*\* dans le \`.sourcoise/\` cible sont copiés, ce qui
déduplique naturellement entre les passes FR et EN sans comptabilité
supplémentaire.

## Usage

``` r
sync_back_sourcoise(cached, lang, max_size_mb = 50)
```

## Arguments

- cached:

  Data frame renvoyé par \[get_from_cache()\]. Doit contenir au moins
  les colonnes \`from_cache\`, \`origin\` (chemin de la copie rendue) et
  \`source\` (chemin du dossier de post d'origine sous \`posts/\`).

- lang:

  Chaîne. Étiquette de langue utilisée pour les messages cli (\`"fr"\`
  ou \`"en"\`).

## Value

Invisiblement, le nombre total de fichiers resynchronisés pour
l'ensemble des posts.
