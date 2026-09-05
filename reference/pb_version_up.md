# Incrémente la version d'un policy brief OFCE publié

Équivalent PB de \[wp_version_up()\]. Lit le champ \`version\` dans
\`\_quarto.yml\`, l'incrémente (\`"v0"\` → \`"v1"\`, \`"v3_4"\` →
\`"v3_5"\`, etc.), met à jour \`\_quarto.yml\` (champ \`version\` et
dernier segment de \`site-path\`), met à jour les variables GitHub
Actions \`FTP_SERVER_DIR\`/\`FTP_REDIRECT_DIR\` et régénère
\`manifest.json\`.

## Usage

``` r
pb_version_up(path = ".", custom_version = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- custom_version:

  Chaîne ou \`NULL\` (défaut). Si non \`NULL\`, force la version à cette
  valeur (alphanumériques + underscores uniquement). Sinon,
  auto-incrémente le dernier chiffre de la version.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Ne fonctionne que pour un PB publié (\`pb\` non nul dans
\`\_quarto.yml\`).

## See also

\[setup_pb()\], \[wp_version_up()\], \[site_version_up()\]
