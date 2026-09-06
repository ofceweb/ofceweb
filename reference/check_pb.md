# Vérifie la structure d'un dépôt de policy brief (PB)

Inspecte le \`\_quarto.yml\` et les fichiers \`.qmd\` à la racine du
dépôt pour détecter les problèmes bloquants (erreurs) et les situations
à corriger (warnings) avant un rendu ou un déploiement.

## Usage

``` r
check_pb(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- verbose:

  Logique. Si \`TRUE\` (défaut), affiche les diagnostics avec
  \[cli::cli_alert_success()\], \[cli::cli_alert_warning()\] et
  \[cli::cli_alert_danger()\].

## Value

Un data frame (invisible) à trois colonnes : \`field\` (chr), \`status\`
(\`"ok"\`, \`"warning"\`, \`"error"\`) et \`message\` (chr).
\[render_pb()\] appelle cette fonction et abandonne si des erreurs
bloquantes sont présentes.

## Details

Contrôles effectués :

- Présence et validité de \`\_quarto.yml\` (champs \`author\`, \`date\`,
  \`citation\` — erreur bloquante si absents)

- \`project.type: ofce-website\` présent dans \`\_quarto.yml\` (warning)

- \`index.qmd\` présent, déclare \`pb-html\` et \`pb-pdf\` /
  \`pb-typst\`

- \`references.bib\` présent (warning)

- \`news.qmd\` présent (warning)

- Si PB publié (\`pb\` non nul) : cohérence \`version\` / dernier
  segment de \`site-path\` (\`N\` ou \`N/vX\` ; \`annee\` n'est pas
  utilisé pour les PB, numérotés séquentiellement depuis l'origine)

- Nom du dépôt conforme à \`pb-initiale-nom court\` (minuscules) lorsque
  l'org GitHub est \`OFCE\` (warning non bloquant)

- Tous les \`.qmd\` non-index référencés dans \`website.other-links\`
  (warning)

- Unicité des \`output-file\` PDF à travers tous les \`.qmd\` (erreur)

## See also

\[render_pb()\], \[setup_pb()\]
