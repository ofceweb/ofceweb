# Installe ou met à jour l'extension Quarto quarto-ife

L'extension \`quarto-ife\` (format \`ife-html\`, type de projet
\`ife-website\`) vit dans le dépôt public \`ofceweb/quarto-ife\`. Une
version publiée y est une étiquette \`vX.Y.Z\`. \`update_quarto_ife()\`
installe dans \`\_extensions/ofceweb/\` la plus haute de ces versions,
avec \`quarto add ofceweb/quarto-ife@vX.Y.Z\`, si elle n'y est pas déjà.

## Usage

``` r
update_quarto_ife(path = ".", only_if_absent = FALSE, quiet = FALSE)
```

## Arguments

- path:

  Racine du projet Quarto. Défaut \`"."\`.

- only_if_absent:

  Si \`TRUE\`, n'installe l'extension que si elle est absente, sans
  chercher de version plus récente. Défaut \`FALSE\`.

- quiet:

  Si \`TRUE\`, n'affiche que les avertissements. Défaut \`FALSE\`.

## Value

Invisible, la version installée après l'appel (\`"0.2.0"\`), ou \`NULL\`
si l'extension est absente.

## Details

Un dépôt de site l'appelle en \`pre-render\` de son \`\_quarto.yml\`, et
suit ainsi la dernière version à chaque rendu :

“\`yaml project: pre-render: Rscript -e "ofceweb::update_quarto_ife()"
“\`

Un dépôt de document (WP, PB, prévision) garde la version installée à sa
création : \[setup_wp()\], \[setup_pb()\] et \[setup_prev()\]
l'appellent avec \`only_if_absent = TRUE\`. Un appel sans argument le
fait passer à la dernière version.

La fonction ne lève jamais d'erreur. Si la liste des versions est
inaccessible (réseau, \`git\` absent) ou si l'installation échoue, elle
affiche un avertissement et garde la version en place, de sorte qu'un
rendu aboutit sans GitHub.
