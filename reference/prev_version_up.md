# Incrémente la version staging d'une prévision OFCE

Lit le champ \`version\` dans \`\_quarto-staging.yml\`, l'incrémente
(\`"v0"\` → \`"v1"\`, \`"v3"\` → \`"v4"\`, etc.), met à jour
\`\_quarto-staging.yml\` (champ \`version\` et dernier segment de
\`site-path\`), puis synchronise la variable GitHub Actions
\`FTP_STAGING_DIR\`.

## Usage

``` r
prev_version_up(path = ".", custom_version = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- custom_version:

  Chaîne ou \`NULL\` (défaut). Si non \`NULL\`, force la version à cette
  valeur exacte (alphanumériques + underscores, ex. \`"v2_rc"\`). Sinon,
  auto-incrémente le dernier chiffre.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## See also

\[setup_prev()\], \[check_prev()\]
