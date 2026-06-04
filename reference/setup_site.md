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

  Chaîne ou \`NULL\`. Titre du site. Si \`NULL\`, on prend le titre de
  \`index.qmd\` s'il existe, sinon le nom du dépôt.

- hypothesis:

  Logique. Active ou non les commentaires hypothesis dans le
  \`\_quarto.yml\`. Défaut \`TRUE\`.

- versionning:

  Logique. Si \`TRUE\` (défaut) et \`ofce_host = TRUE\`, ajoute un
  segment \`/v0\` au \`site-path\`. Voir \[site_version_up()\] pour
  incrémenter.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.
