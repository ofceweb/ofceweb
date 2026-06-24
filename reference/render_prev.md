# Rend le site de prévision OFCE (staging ou publish)

Lance un build Quarto du dépôt de prévision courant avec le profil
indiqué. Nettoie le répertoire de sortie avant le rendu. Le chiffrement
n'a \*\*pas\*\* lieu en local — il est appliqué en CI par le workflow
\`ftp_deploy_staging.yml\` avant le transfert FTP.

## Usage

``` r
render_prev(
  path = ".",
  profile = "staging",
  check_repo = TRUE,
  progress = TRUE,
  preview = TRUE,
  workers = 8L
)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- profile:

  \`"staging"\` (défaut), \`"publish"\`, ou tout autre profil Quarto
  déclaré dans \`\_quarto.yml\`. Détermine le répertoire de sortie
  (\`\_site_staging\`, \`\_site_publish\`, ou \`\_site_profile\` pour
  tout autre profil).

- check_repo:

  Logique. Si \`TRUE\` (défaut), vérifie l'état du dépôt git via
  \[check_repo_status()\].

- progress:

  Logique. Affichage de la progression. Défaut \`TRUE\`.

- preview:

  Logique. Si \`TRUE\`, lance un serveur HTTP local via
  \[servr::httw()\] sur le répertoire de sortie après le rendu. Défaut
  \`TRUE\`

- workers:

  Entier. Nombre de workers parallèles. Défaut \`8L\`.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Prévision Users

## See also

\[stage_prev()\], \[publish_prev()\], \[setup_prev()\], \[check_prev()\]
