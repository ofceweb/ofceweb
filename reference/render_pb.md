# Rendu complet d'un policy brief (PB) OFCE

Équivalent PB de \[render_wp()\]. Orchestre le build complet d'un PB
Quarto : vérification du dépôt git, vérification de la structure PB,
lecture de l'état \`stage\` (staging ou publié) depuis la clé \`draft\`
de \`\_quarto.yml\`. \*\*La consultation du registre central
(\`ofce/wp-registry\`, sous-dossier \`pb/\`) ne se fait plus ici\*\* :
elle a lieu en amont, dans \[setup_pb()\] (et à nouveau dans
\[publish_pb()\]) — \`render_pb()\` suppose que \`draft\`/\`pb\` sont
déjà synchronisés dans \`\_quarto.yml\` et se contente de les lire, sans
accès réseau. Suivent le nettoyage de \`\_site/\`, le rendu Quarto
(HTML + PDF), la construction du sitemap, l'écriture du manifeste, la
synchronisation de \`FTP_SERVER_DIR\` (PBs publiés confirmés
uniquement), et optionnellement le déploiement et la prévisualisation
locale.

## Usage

``` r
render_pb(
  path = ".",
  check = TRUE,
  progress = TRUE,
  render_site = TRUE,
  site2branch = FALSE,
  trigger = site2branch,
  workers = 8L,
  ...
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- check:

  Logique. Si \`TRUE\` (défaut), appelle \[check_pb()\] avant le rendu
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

- ...:

  Arguments supplémentaires ignorés (compatibilité avec les appels CI
  historiques, ex. \`check_repo\`).

## Value

Invisible NULL.

## See also

\[setup_pb()\], \[check_pb()\], \[deploy_pb()\]
