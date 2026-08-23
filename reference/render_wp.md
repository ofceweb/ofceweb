# Rendu complet d'un document de travail (WP) OFCE

Orchestre le build complet d'un WP Quarto : vérification du dépôt git,
vérification de la structure WP, nettoyage de \`\_site/\`, rendu Quarto
(HTML + PDF), construction du sitemap, patch des hashes Bootstrap,
écriture du manifeste, synchronisation de la variable GitHub Actions
\`FTP_SERVER_DIR\` (WPs publiés uniquement), et optionnellement
déploiement sur la branche de déploiement et prévisualisation locale.

## Usage

``` r
render_wp(
  path = ".",
  check_repo = TRUE,
  check = TRUE,
  progress = TRUE,
  render_site = TRUE,
  site2branch = FALSE,
  trigger = site2branch,
  workers = 8L
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- check_repo:

  Logique. Si \`TRUE\` (défaut), vérifie l'état du dépôt git avant le
  rendu via \[check_repo_status()\].

- check:

  Logique. Si \`TRUE\` (défaut), appelle \[check_wp()\] avant le rendu
  et abandonne si des erreurs bloquantes sont détectées.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- render_site:

  Logique. Si \`TRUE\` (défaut), lance un serveur HTTP local via
  \[servr::httw()\] sur \`\_site/\` après le rendu.

- site2branch:

  Logique. Si \`TRUE\`, pousse \`\_site/\` vers la branche de
  déploiement via \[site2branch()\]. Défaut \`FALSE\`.

- trigger:

  Passé à \[site2branch()\]. Défaut = valeur de \`site2branch\`.

- workers:

  Entier. Nombre de workers parallèles pour le rendu. Défaut \`8L\`.

## Value

Invisible : sortie de \[gert::git_status()\].

## See also

\[setup_wp()\], \[check_wp()\], \[deploy_wp()\]
