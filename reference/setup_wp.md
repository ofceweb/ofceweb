# Initialise un dépôt de document de travail (WP) OFCE

Copie les gabarits embarqués dans le package (\`inst/setup_wp/\`) à la
racine du dépôt, initialise la branche \`gh-pages\` pour la
pré-publication, et adapte le \`\_quarto.yml\` avec les métadonnées du
WP (titre, numéro, année, langue, URLs).

## Usage

``` r
setup_wp(
  path = ".",
  website_title = NULL,
  wp = NULL,
  annee = as.integer(format(Sys.Date(), "%Y")),
  lang = "fr",
  hypothesis = NULL,
  versionning = NULL
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- website_title:

  Chaîne ou \`NULL\`. Titre du WP. Si \`NULL\`, utilise le nom du dépôt
  GitHub.

- wp:

  Entier ou \`NULL\`. Numéro du WP. \`NULL\` = brouillon
  (pré-publication GitHub Pages) ; entier = WP publié (hébergement OFCE
  FTP).

- annee:

  Entier. Année de publication. Défaut = année courante.

- lang:

  Chaîne. Langue principale : \`"fr"\` (défaut) ou \`"en"\`.

- hypothesis:

  Logique. Active les commentaires Hypothesis. Défaut \`FALSE\`.

- versionning:

  Logique. Si \`TRUE\` et WP publié (\`wp\` non \`NULL\`), ajoute
  \`/v0\` au \`site-path\`.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

La fonction est \*\*non-destructive\*\* : sur un dépôt existant, les
fichiers gabarits (dont \`\_quarto.yml\`) ne sont pas écrasés, et les
champs YAML ne sont mis à jour que si l'argument correspondant a été
fourni explicitement. Les champs déjà absents ne sont pas injectés.
\`repo-url\`, \`favicon\` et \`ofce_wp: true\` sont toujours positionnés
(valeurs dérivées sans ambiguïté).
\`website.site-url\`/\`website.site-path\` sont eux aussi toujours
(re)calculés dès que \`wp\` est non nul — que ce soit via l'argument
\`wp\` ou une valeur déjà présente dans \`\_quarto.yml\` — pour qu'un
\`site-path\` manquant (fichier édité à la main, ou créé avant cette
fonctionnalité) soit toujours réparé.

Pour les WPs publiés (\`wp\` non nul), la fonction met à jour la
variable GitHub Actions \`FTP_SERVER_DIR\` (publique, visible dans
Settings → Variables) à partir du \`site-path\` du \`\_quarto.yml\`. Le
workflow \`ftp_deploy.yml\` est aussi migré automatiquement si
\`server-dir\` y est encore codé en dur, et si l'étape de vérification
anti-collision (voir \[wp_manifest()\]) y est absente.

Toujours pour les WPs publiés, \`citation.issue\` (\`"année-wp"\`, sans
zéro de remplissage) et \`citation.url\`
(\`https://www.ofce.fr/wp/année/wp/\`, l'URL publique stable, sans
segment de version) sont recalculés à chaque appel à partir de
\`annee\`/\`wp\` — ce sont des valeurs dérivées, jamais éditées
manuellement.

Les extensions Quarto OFCE (\`\_extensions/\`) sont installées/mises à
jour via \[ofce::setup_quarto()\], qui les récupère depuis le dépôt
GitHub \`OFCE/ofce-quarto-extensions\` — la fonction nécessite donc un
accès réseau. D'éventuelles extensions périmées (installées par une
version antérieure du package) sont signalées par un avertissement,
jamais supprimées automatiquement.

## See also

\[render_wp()\], \[deploy_wp()\], \[wp_version_up()\],
\[update_navbar()\]
