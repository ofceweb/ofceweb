# Déploie la page de redirection vers la version courante d'un site OFCE

Génère un \`index.html\` de redirection pointant vers la version
courante du site (segment de version dans \`site-path\` du
\`\_quarto.yml\`), le pousse sur la branche \`site-redirect\`, puis
déclenche le workflow \`ftp_redirect.yml\` pour le déployer à l'URL
stable \`www.ofce.fr/site-path-sans-version/\`.

## Usage

``` r
push_site_redirect(path = ".", progress = TRUE, trigger = TRUE)
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

Ne fait rien si le \`site-path\` ne contient pas de segment de version
(\`/v+\`), ce qui correspond aux sites créés avec \`versionning =
FALSE\`.

Met également à jour la variable GitHub Actions \`FTP_REDIRECT_DIR\`
avec le répertoire cible (chemin FTP sans préfixe de localisation ni
version).

## Home Users

## See also

\[setup_site()\], \[site_version_up()\]
