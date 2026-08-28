# Initialise un site OFCE dans le dépôt courant

Scanne les fichiers \`.qmd\` du dépôt, copie les gabarits embarqués dans
le package (\`inst/setup_site/\`) à la racine du dépôt, puis adapte le
\`\_quarto.yml\` en fonction des arguments (hébergement OFCE ou GitHub
Pages, titre, code de site, commentaires hypothesis, etc.).

## Usage

``` r
setup_site(
  path = ".",
  ofce_host = TRUE,
  ofce_server_location = "staging",
  website_code = NULL,
  website_title = NULL,
  hypothesis = TRUE,
  versionning = TRUE
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- ofce_host:

  Logique. Si \`TRUE\` (défaut), le site est hébergé sur les serveurs
  OFCE (\`site-url = https://www.ofce.fr/\`). Si \`FALSE\`, le site est
  publié via GitHub Pages et le \`site-url\` est dérivé du remote
  \`origin\`.

- ofce_server_location:

  Chaîne. Emplacement sur le serveur OFCE, utilisé comme préfixe du
  \`site-path\`. Valeurs reconnues : \`"staging"\` (défaut), \`"wp"\`,
  \`"threeme"\`. Détermine aussi le préfixe des secrets FTP utilisés
  (\`STAGING\_\*\`, \`WP\_\*\`, \`THREEME\_\*\`).

- website_code:

  Chaîne ou \`NULL\`. Code court du site (lettres, chiffres, underscores
  uniquement). Si invalide, retombe sur \`NULL\`. Si \`NULL\`, on
  utilise le nom du dépôt GitHub.

- website_title:

  Chaîne ou \`NULL\`. Titre du site, utilisé pour le résumé affiché en
  fin d'appel uniquement — n'est plus jamais écrit comme
  \`website.title\` dans \`\_quarto.yml\` (voir \[update_navbar()\], qui
  supprime cette clé si un appel antérieur l'y avait laissée). Si
  \`NULL\`, on prend le titre de \`index.qmd\` s'il existe, sinon le nom
  du dépôt.

- hypothesis:

  Logique. Active ou non les commentaires hypothesis dans le
  \`\_quarto.yml\`. Défaut \`TRUE\`.

- versionning:

  Logique. Si \`TRUE\` (défaut) et \`ofce_host = TRUE\`, ajoute un
  segment \`/v0\` au \`site-path\`. Voir \[site_version_up()\] pour
  incrémenter.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Clés du \`\_quarto.yml\` modifiées vs. préservées

Si un \`\_quarto.yml\` existe déjà, la fonction le lit et ne modifie que
certaines clés. Les autres sont conservées.

\*\*Toujours écrasées\*\* (sans garde) :

\| Clé \| Valeur imposée \| \|—–\|—————-\| \| \`ofce_host\` \| Valeur de
l'argument \`ofce_host\` \| \| \`website.other-links\` \| Liste
reconstruite par scan des \`.qmd\` \| \| \`website.comments\` \|
\`hypothesis: true\` ou supprimé selon \`hypothesis\` \|

\*\*Préservées si déjà renseignées\*\* (non écrasées) :

\| Clé \| Condition \| \|—–\|———–\| \| \`website.site-url\` \| Non
\`NULL\` et non vide \| \| \`website.site-path\` \| Non \`NULL\` et non
vide \| \| \`website.repo-url\` \| Non \`NULL\` et non vide \|

Toutes les autres clés (\`format\`, \`execute\`, \`website.navbar\`,
etc.) sont lues et réécrites telles quelles.

## Édition du YAML

La mise à jour patche uniquement les clés listées ci-dessus dans le
texte du fichier : commentaires, indentation et mise en page du reste du
\`\_quarto.yml\` sont préservés. Les blocs \`website.other-links\` et
\`website.comments\` sont entièrement régénérés (ce sont des sections
gérées par le package), donc d'éventuels commentaires à l'intérieur de
ces deux blocs précis ne survivent pas.

## Navbar

La navbar du \`\_quarto.yml\` est synchronisée depuis la source
centralisée du package via \[update_navbar()\], appelé automatiquement
en fin de configuration.

## Extensions Quarto

Les extensions OFCE (\`\_extensions/\`) sont installées/mises à jour via
\[ofce::setup_quarto()\], qui les récupère depuis le dépôt GitHub
\`OFCE/ofce-quarto-extensions\` — un accès réseau est donc nécessaire.
D'éventuelles extensions périmées (installées par une version antérieure
du package) sont signalées par un avertissement, jamais supprimées
automatiquement.

## See also

\[update_navbar()\]
