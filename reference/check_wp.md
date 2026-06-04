# Vérifie la structure d'un dépôt de document de travail (WP)

Inspecte le \`\_quarto.yml\` et les fichiers \`.qmd\` à la racine du
dépôt pour détecter les problèmes bloquants (erreurs) et les situations
à corriger (warnings) avant un rendu ou un déploiement.

## Usage

``` r
check_wp(path = ".", verbose = TRUE)
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
\[render_wp()\] appelle cette fonction et abandonne si des erreurs
bloquantes sont présentes.

## Details

Contrôles effectués :

- Présence et validité de \`\_quarto.yml\` (champs \`annee\`,
  \`author\`, \`date\`, \`citation\` — erreur bloquante si absents)

- \`index.qmd\` présent, déclare \`wp-html\` et \`wp-pdf\` /
  \`wp-typst\`

- \`references.bib\` présent (warning)

- \`news.qmd\` présent (warning)

- Si WP publié (\`wp\` non nul) : \`annee\` entier valide, cohérence
  \`version\` / dernier segment de \`site-path\`

- Tous les \`.qmd\` non-index référencés dans \`website.other-links\`
  (warning)

- Unicité des \`output-file\` PDF à travers tous les \`.qmd\` (erreur)

## See also

\[render_wp()\], \[setup_wp()\]
