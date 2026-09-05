# Déploie la page de redirection vers la dernière version d'un PB OFCE

Équivalent PB de \[push_wp_redirect()\]. Génère un \`index.html\` de
redirection pointant vers la version courante du PB (champ \`version\`
de \`\_quarto.yml\`), le pousse sur la branche \`site-redirect\`, puis
déclenche le workflow \`ftp_redirect.yml\` pour le déployer à l'URL
stable \`www.ofce.fr/pb/annee/pb/\`.

## Usage

``` r
push_pb_redirect(path = ".", progress = TRUE, trigger = TRUE)
```

## Arguments

- path:

  Chemin vers la racine du dépôt. Défaut \`"."\`.

- progress:

  Logique. Affichage de la progression git. Défaut \`TRUE\`.

- trigger:

  Logique. Si \`TRUE\` (défaut), déclenche \`ftp_redirect.yml\` après le
  push.

## Value

Invisible \`NULL\`. Appelée pour ses effets de bord.

## Details

Met également à jour la variable GitHub Actions \`FTP_REDIRECT_DIR\`
avec le répertoire parent du \`site-path\`.

Ne fait rien pour les PBs brouillons (\`pb: null\`).

## See also

\[deploy_pb()\], \[publish_pb()\], \[pb_version_up()\]
