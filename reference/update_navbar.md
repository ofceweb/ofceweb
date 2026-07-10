# Met à jour la navbar du \`\_quarto.yml\` depuis la source centralisée

Lit la définition unique de la navbar (\`inst/share/navbar.yml\` du
package) et remplace les clés \`left\`, \`right\` et \`tools\` de la
section \`website.navbar\` du \`\_quarto.yml\` du site. Les autres clés
navbar propres au site (\`title\`, \`logo\`, \`background\`, ...) sont
préservées : seuls les menus sont centralisés.

## Usage

``` r
update_navbar(root = ".")
```

## Arguments

- root:

  Chemin vers la racine du dépôt du site. Défaut \`"."\`.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Les fichiers de profils (\`\_quarto-fr.yml\`, \`\_quarto-en.yml\`, ...)
ne sont pas modifiés : s'ils redéfinissent une clé navbar (ex. le
sélecteur de langue FR/EN du blog dans \`right\`), c'est une surcharge
locale volontaire qui prime au render. Un message signale les profils
concernés.

La navbar doit être réécrite dans chaque site à chaque évolution de
\`navbar.yml\` : exécuter \`update_navbar()\` à la racine du site,
relire le diff, committer.

## Site Users

## See also

\[site_version_up()\], \[setup_site()\]
