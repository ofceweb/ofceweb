# Incrémente la version dans le \`site-path\` du \`\_quarto.yml\`

Lit le \`\_quarto.yml\` à la racine du dépôt, repère le dernier segment
du \`site-path\` (la version) et l'incrémente. Si \`custom_version\` est
fourni, remplace simplement le segment de version par cette valeur.
Sinon, détecte la dernière séquence de chiffres dans le segment et
l'augmente de 1 (ex. \`v0\` -\> \`v1\`, \`v3_4\` -\> \`v3_5\`,
\`v5_AS42\` -\> \`v5_AS43\`, \`v10_42A\` -\> \`v10_43A\`, \`6v\` -\>
\`7v\`). Met également à jour la variable GitHub Actions
\`FTP_SERVER_DIR\` avec le nouveau \`site-path\`.

## Usage

``` r
site_version_up(path = ".", custom_version = NULL)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- custom_version:

  Chaîne ou \`NULL\` (défaut). Si non \`NULL\`, remplace la version
  actuelle par cette valeur (validée : alphanumériques et underscores
  uniquement).

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Ne fonctionne que si \`ofce_host: true\` est présent dans le
\`\_quarto.yml\`. Les versions doivent être alphanumériques avec des
underscores uniquement.

## Site Users

## See also

\[setup_site()\]
