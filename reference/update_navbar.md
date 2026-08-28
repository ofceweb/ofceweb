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

Supprime également la clé \`website.title\` si elle est encore présente
: \`setup_wp()\`, \`setup_prev()\` et \`setup_site()\` ne l'écrivent
plus (le titre affiché à côté du logo reste porté par la navbar
centralisée, pas par un titre calculé par site) ; cet appel nettoie les
dépôts initialisés avant ce changement.

Les fichiers de profils (\`\_quarto-fr.yml\`, \`\_quarto-en.yml\`, ...)
ne sont pas modifiés : s'ils redéfinissent une clé navbar (ex. le
sélecteur de langue FR/EN du blog dans \`right\`), c'est une surcharge
locale volontaire qui prime au render. Un message signale les profils
concernés.

La navbar doit être réécrite dans chaque site à chaque évolution de
\`navbar.yml\` : exécuter \`update_navbar()\` à la racine du site,
relire le diff, committer.

## Édition du YAML

La mise à jour patche uniquement les clés \`website.navbar.left\`,
\`.tools\`, \`.logo\`, \`.logo-href\` et \`.logo-alt\` dans le texte du
fichier : commentaires, indentation et mise en page du reste du
\`\_quarto.yml\` sont préservés.

## See also

\[site_version_up()\], \[setup_site()\]
