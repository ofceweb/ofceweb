# Rendu et déploiement complet d'un document de travail (WP) OFCE

Enchaîne \[render_wp()\] puis \[deploy_wp()\] : rend le WP, pousse
\`\_site/\` vers la branche de déploiement FTP, et met à jour la page de
redirection vers l'URL stable (via \[push_wp_redirect()\]).

## Usage

``` r
publish_wp(
  path = ".",
  check = TRUE,
  progress = TRUE,
  render_site = TRUE,
  trigger = TRUE,
  workers = 8L
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- check:

  Logique. Si \`TRUE\` (défaut), appelle \[check_wp()\] avant le rendu
  et abandonne si des erreurs bloquantes sont détectées.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- render_site:

  Logique. Si \`TRUE\` (défaut), lance un serveur HTTP local via
  \[servr::httw()\] sur \`\_site/\` après le rendu.

- trigger:

  Logique. Déclenche les workflows GitHub Actions FTP après le push.
  Défaut \`TRUE\`.

- workers:

  Entier. Nombre de workers parallèles pour le rendu. Défaut \`8L\`.

## Value

Invisible \`NULL\`.

## See also

\[render_wp()\], \[deploy_wp()\], \[push_wp_redirect()\], \[setup_wp()\]
