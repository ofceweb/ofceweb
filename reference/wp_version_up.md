# Incrémente la version d'un document de travail OFCE publié

Lit le champ \`version\` dans \`\_quarto.yml\`, l'incrémente (\`"v0"\` →
\`"v1"\`, \`"v3_4"\` → \`"v3_5"\`, etc.), met à jour \`\_quarto.yml\`
(champ \`version\` et dernier segment de \`site-path\`), met à jour la
variable GitHub Actions \`FTP_SERVER_DIR\` et régénère
\`manifest.json\`.

## Usage

``` r
wp_version_up(path = ".", custom_version = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- custom_version:

  Chaîne ou \`NULL\` (défaut). Si non \`NULL\`, force la version à cette
  valeur (alphanumériques + underscores uniquement, ex. \`"v2_corr"\`).
  Sinon, auto-incrémente le dernier chiffre de la version.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Ne fonctionne que pour un WP publié (\`wp\` non nul dans
\`\_quarto.yml\`).

## See also

\[setup_wp()\], \[site_version_up()\]
