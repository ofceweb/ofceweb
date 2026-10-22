# Reporte les vignettes générées pendant le rendu vers les posts source

Pendant l'exécution d'un post, le hook \`thumbnail_hook()\` du blog
(\`\_utils/thumbnail.R\`) écrit l'image déclarée dans le YAML
(\`image:\`) à partir du premier ggplot passé à \`girafy()\`. Cette
image n'existe que dans la copie de rendu (\`\_fr/fr/...\`) : elle est
ici recopiée dans \`posts/\`.

## Usage

``` r
sync_back_thumbnail(
  cached,
  lang,
  savegraph_dir = getOption("ofce.savegraph.dir", "_sav_graph")
)
```

## Arguments

- cached:

  Data frame renvoyé par \[get_from_cache()\] (colonnes \`from_cache\`,
  \`origin\`, \`source\`, \`name\`, \`yaml\`).

- lang:

  Chaîne. \`"fr"\` ou \`"en"\`.

- savegraph_dir:

  Dossier des graphes enregistrés par \`ofce::save_graph()\`, relatif à
  \`\_lang/\`.

## Value

Invisiblement, le nombre de vignettes reportées.

## Details

Pour chaque post re-rendu, l'image est reportée si elle a été générée,
c'est-à-dire si des graphes ont été enregistrés dans \`\_sav_graph/\`
pour ce document, et si elle est absente de \`posts/\` (ou nommée
\`thumbnail\*\` ou \`fig-\*.png\`, donc régénérée à chaque exécution).
Une image fournie par l'auteur n'est jamais écrasée.

Avec \`image: fig-label\` dans le YAML du post (transformé en
\`fig-label.png\` par \[copy_post()\]), la vignette vient du chunk
\`label\`.
