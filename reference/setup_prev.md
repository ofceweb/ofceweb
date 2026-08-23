# Initialise un dépôt de prévision OFCE

Copie les gabarits embarqués dans le package (\`inst/setup_prev/\`) à la
racine du dépôt, crée la structure de dossiers attendue, et adapte les
fichiers de configuration Quarto (\`\_quarto.yml\`,
\`\_quarto-staging.yml\`, \`\_quarto-publish.yml\`) avec l'identifiant
de la prévision.

## Usage

``` r
setup_prev(path = ".", encrypt = TRUE, versionning = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- encrypt:

  Logique. Si \`TRUE\` (défaut), positionne \`encrypt_site: true\` dans
  \`\_quarto-staging.yml\` (le chiffrement a lieu en CI).

- versionning:

  Logique. Si \`TRUE\` (défaut), initialise la version staging à
  \`"v0"\`.

- prev:

  Chaîne à 4 chiffres identifiant la prévision (ex. \`"2609"\` pour
  septembre 2026). Si \`NULL\` (défaut), déduit automatiquement du nom
  du dossier si celui-ci respecte le format \`prevYY03\|9\`.

- annee:

  Entier. Année de la prévision. Défaut = année courante. Déduit du nom
  du dossier si \`prev\` est aussi déduit.

- mois:

  Entier. Mois de la prévision : \`3\` (mars) ou \`9\` (septembre).
  Déduit du nom du dossier si \`prev\` est aussi déduit.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

La fonction est \*\*non-destructive\*\* pour les fichiers utilisateur
(\`.qmd\`, scripts \`data_pays/\`) : ils ne sont copiés que s'ils sont
absents. En revanche, \`\_extensions/\`, \`www/\` et les \*\*workflows
GitHub Actions\*\* sont \*\*toujours mis à jour\*\* depuis la version de
référence du package.

Les extensions Quarto OFCE (\`\_extensions/\`) sont installées/mises à
jour via \[ofce::setup_quarto()\], qui les récupère depuis le dépôt
GitHub \`OFCE/ofce-quarto-extensions\` — un accès réseau est donc
nécessaire. D'éventuelles extensions périmées (installées par une
version antérieure du package) sont signalées par un avertissement,
jamais supprimées automatiquement.

## Structure créée

“\` \<root\>/ ├── \_quarto.yml \# base commune (ofce_prev, prev, annee,
mois) ├── \_quarto-staging.yml \# profil staging (site-path, version,
encrypt_site) ├── \_quarto-publish.yml \# profil publish (site-path, pas
de chiffrement) ├── \_extensions/ \# extensions Quarto OFCE (via
ofce::setup_quarto()) ├── www/ \# assets statiques (logos, CSS —
toujours mis à jour) ├── france/data/ \# données France (.gitkeep) ├──
inter/data/ \# données International (.gitkeep) ├── fiches/data/ \#
données Analyses Pays (.gitkeep) ├── tableaux_comptes/ \# tableaux de
comptes nationaux ├── data_pays/ \# scripts de données agrégées
(non-destructif) └── .github/workflows/ ├── ftp_deploy_staging.yml ├──
ftp_deploy_publish.yml └── ftp_deploy_profile.yml “\`

## See also

\[check_prev()\], \[render_prev()\], \[prev_version_up()\],
\[update_navbar()\]
