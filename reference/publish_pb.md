# Rendu et déploiement complet d'un policy brief (PB) OFCE

Équivalent PB de \[publish_wp()\]. Rafraîchit l'état du registre central
(\`ofce/wp-registry\`, sous-dossier \`pb/\`, via
\`sync_pb_registry_state()\`) — pour rattraper un enregistrement survenu
depuis le dernier \[setup_pb()\] — puis enchaîne \[render_pb()\] et
\[deploy_pb()\]. Ce rafraîchissement ne recalcule que
\`draft\`/\`pb\`/\`annee\` ; si le numéro PB change à cette étape, un
avertissement invite à relancer \[setup_pb()\] pour recalculer les
champs dérivés (\`site-path\`, \`citation.\*\`, \`FTP_SERVER_DIR\`).

## Usage

``` r
publish_pb(
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

  Logique. Si \`TRUE\` (défaut), appelle \[check_pb()\] avant le rendu
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

\[render_pb()\], \[deploy_pb()\], \[push_pb_redirect()\], \[setup_pb()\]
