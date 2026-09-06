# Initialise un dépôt de policy brief (PB) OFCE

Équivalent PB de \[setup_wp()\]. Copie les gabarits embarqués dans le
package (\`inst/setup_pb/\`) à la racine du dépôt, initialise la branche
\`gh-pages\` pour la pré-publication, et adapte le \`\_quarto.yml\` avec
les métadonnées du PB (titre, numéro, année, langue, URLs).

## Usage

``` r
setup_pb(
  path = ".",
  lang = "fr",
  hypothesis = NULL,
  versionning = NULL,
  stage_target = NULL
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- lang:

  Chaîne. Langue principale : \`"fr"\` (défaut) ou \`"en"\`.

- hypothesis:

  Logique. Active les commentaires Hypothesis. Défaut \`FALSE\`.

- versionning:

  Logique. Si \`TRUE\` et PB publié (\`pb\` non \`NULL\`), ajoute
  \`/v0\` au \`site-path\`.

- stage_target:

  Chaîne. Destination de pré-publication (brouillon, \`pb\` non encore
  attribué) : \`"auto"\` (défaut), \`"ftp"\` (staging OFCE),
  \`"gh-pages"\`. Cf. \[setup_wp()\] pour la sémantique détaillée.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

La fonction est \*\*non-destructive\*\* pour les fichiers utilisateur :
sur un dépôt existant, les fichiers gabarits \`.qmd\` et scripts (dont
\`\_quarto.yml\`) ne sont pas écrasés, et les champs YAML ne sont mis à
jour que si l'argument correspondant a été fourni explicitement.
\`repo-url\`, \`favicon\` et \`ofce_pb: true\` sont toujours
positionnés. \`website.site-url\`/\`site-path\` sont toujours
(re)calculés dès que \`pb\` est non nul.

En revanche, les \*\*workflows GitHub Actions\*\*
(\`.github/workflows/\`) sont \*\*toujours mis à jour\*\* depuis la
version de référence du package.

\`pb\` n'est \*\*pas\*\* un argument : il est soit lu depuis un
\`\_quarto.yml\` déjà existant, soit écrasé par une entrée confirmée du
registre central (\`ofce/wp-registry\`, sous-dossier \`pb/\`), jamais
choisi librement par l'appelant. Un dépôt sans \`\_quarto.yml\` et sans
entrée de registre reste un brouillon (\`pb\` absent) ; pour obtenir un
numéro, utiliser \[pb_registry_request()\] puis relancer \`setup_pb()\`
une fois la PR fusionnée. Le champ \`annee\` n'est pas utilisé pour les
PB : les numéros sont attribués séquentiellement depuis l'origine,
indépendamment de l'année de publication.

Les extensions Quarto OFCE (\`\_extensions/\`) sont installées/mises à
jour via \[ofce::setup_quarto()\], qui les récupère depuis le dépôt
GitHub \`OFCE/ofce-quarto-extensions\` — la fonction nécessite donc un
accès réseau.

## See also

\[render_pb()\], \[deploy_pb()\], \[pb_version_up()\],
\[update_navbar()\]
