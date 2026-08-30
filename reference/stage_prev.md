# Rend et déploie la prévision en staging

Enchaîne \[render_prev()\] avec le profil \`"staging"\` puis pousse
\`\_site_staging/\` (en clair) vers la branche \`site-staging\` via
\[site2staging()\]. Le chiffrement est appliqué \*\*en CI\*\* par le
workflow \`ftp_deploy_staging.yml\` avant le transfert FTP.

## Usage

``` r
stage_prev(
  path = ".",
  progress = TRUE,
  site2branch = TRUE,
  trigger = site2branch,
  full_deploy = FALSE,
  preview = FALSE,
  workers = 8L,
  trigger_staging_redirect = TRUE
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- site2branch:

  Logique. Si \`TRUE\` (défaut), appelle \[site2staging()\] après le
  rendu.

- trigger:

  Passé à \[site2staging()\]. Défaut = valeur de \`site2branch\`.

- full_deploy:

  Passé à \[site2staging()\]. Défaut \`FALSE\`.

- preview:

  Logique. Si \`TRUE\`, lance un serveur HTTP local via
  \[servr::httw()\] sur le répertoire de sortie après le rendu. Défaut
  \`TRUE\`

- workers:

  Entier. Nombre de workers parallèles. Défaut \`8L\`.

- trigger_staging_redirect:

  Logique. Si \`TRUE\` (défaut), appelle
  \[push_prev_staging_redirect()\] après \[site2staging()\]. Défaut
  \`TRUE\`.

## Value

Invisible \`NULL\`.

## Details

Après déploiement, met automatiquement à jour la redirection stable vers
la dernière version en staging (via \[push_prev_staging_redirect()\]),
sauf si \`trigger_staging_redirect = FALSE\`.

## See also

\[render_prev()\], \[deploy_prev()\], \[publish_prev()\],
\[push_prev_staging_redirect()\]
